require 'rails_helper'

RSpec.describe 'Scheduled Task Execution', type: :integration do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization, role: 'admin') }
  let(:data_source) { create(:data_source, organization: organization) }

  before do
    # Configure Solid Queue to process jobs inline for real processing
    ActiveJob::Base.queue_adapter = :inline

    # Freeze time for consistent scheduling tests
    travel_to Time.zone.local(2024, 1, 15, 10, 0, 0)
  end

  after do
    travel_back
    ActiveJob::Base.queue_adapter = :test
  end

  describe 'Schedule creation and execution' do
    let(:task_template) { create(:task_template,
      organization: organization,
      name: "Daily Data Sync #{SecureRandom.hex(4)}",
      task_type: 'extraction',
      execution_mode: 'automated',
      template_config: {
        source_type: 'api',
        endpoint: '/data/sync',
        batch_size: rand(100..1000)
      }
    ) }

    it 'creates and executes scheduled tasks based on schedule type' do
      # Test different schedule types
      schedule_configs = [
        {
          schedule_type: 'once',
          scheduled_at: rand(1..24).hours.from_now,
          expected_runs: 1
        },
        {
          schedule_type: 'daily',
          time_of_day: "#{rand(0..23).to_s.rjust(2, '0')}:#{rand(0..59).to_s.rjust(2, '0')}",
          expected_runs: 7 # Over a week
        },
        {
          schedule_type: 'weekly',
          time_of_day: "14:30",
          days_of_week: [ 'monday', 'wednesday', 'friday' ].sample(rand(1..3)),
          expected_runs: 3 # Approximate for a week
        },
        {
          schedule_type: 'monthly',
          time_of_day: "09:00",
          day_of_month: rand(1..28),
          expected_runs: 1 # Once per month
        },
        {
          schedule_type: 'custom',
          cron_expression: "0 */#{rand(2..6)} * * *", # Every 2-6 hours
          expected_runs: 12 # Approximate for a day
        }
      ]

      scheduled_tasks = []

      schedule_configs.each do |config|
        scheduled_task = create(:scheduled_task,
          organization: organization,
          task_template: task_template,
          data_source: data_source,
          name: "#{config[:schedule_type].capitalize} Task #{SecureRandom.hex(3)}",
          active: true,
          **config.except(:expected_runs),
          configuration: {
            data_source_id: data_source.id,
            sync_mode: [ 'full', 'incremental' ].sample,
            priority: rand(0..10)
          }
        )

        scheduled_tasks << scheduled_task

        # Calculate next run
        next_run = scheduled_task.calculate_next_run
        expect(next_run).to be_present
        expect(next_run).to be > Time.current

        # Verify schedule is valid
        expect(scheduled_task.valid_schedule?).to be true
      end

      # Execute TaskSchedulerJob to process due schedules
      TaskSchedulerJob.perform_now

      # Verify executions were created for due tasks
      scheduled_tasks.each do |scheduled_task|
        if scheduled_task.next_run && scheduled_task.next_run <= Time.current
          expect(scheduled_task.scheduled_task_runs.count).to be > 0
        end
      end
    end

    it 'respects max runs and end date constraints' do
      max_runs = rand(3..5)
      end_date = rand(5..10).days.from_now

      scheduled_task = create(:scheduled_task,
        organization: organization,
        task_template: task_template,
        data_source: data_source,
        name: "Limited Run Task #{SecureRandom.hex(3)}",
        schedule_type: 'daily',
        time_of_day: '08:00',
        max_runs: max_runs,
        end_date: end_date,
        active: true
      )

      # Simulate multiple executions
      execution_count = 0

      (max_runs + 2).times do |i|
        travel_to (i + 1).days.from_now + 8.hours

        # Check if should execute
        if scheduled_task.should_execute?
          TaskSchedulerJob.perform_now
          scheduled_task.reload
          execution_count += 1
        end
      end

      # Should not exceed max runs
      expect(scheduled_task.run_count).to eq([ max_runs, execution_count ].min)
      expect(scheduled_task.active).to eq(scheduled_task.run_count < max_runs)
    end

    it 'handles execution failures and retries' do
      scheduled_task = create(:scheduled_task,
        organization: organization,
        task_template: task_template,
        data_source: data_source,
        name: "Retry Test Task #{SecureRandom.hex(3)}",
        schedule_type: 'once',
        scheduled_at: 1.hour.from_now,
        max_retries: rand(2..5),
        active: true
      )

      # Move to execution time
      travel_to scheduled_task.scheduled_at

      # Simulate failure in task execution
      allow_any_instance_of(Task).to receive(:execute!).and_raise(StandardError, "Simulated failure")

      # Execute scheduler
      expect { TaskSchedulerJob.perform_now }.not_to raise_error

      scheduled_task.reload
      run = scheduled_task.scheduled_task_runs.last

      expect(run).to be_present
      expect(run.status).to eq('failed')
      expect(run.error_message).to include("Simulated failure")

      # Verify task is still active for retry
      expect(scheduled_task.active).to be true

      # Fix the error and retry
      allow_any_instance_of(Task).to receive(:execute!).and_call_original

      # Execute again
      travel_to 30.minutes.from_now
      TaskSchedulerJob.perform_now

      # Should create another run
      expect(scheduled_task.scheduled_task_runs.count).to eq(2)
    end
  end

  describe 'Timezone handling' do
    it 'executes tasks at correct time across timezones' do
      timezones = [ 'America/New_York', 'Europe/London', 'Asia/Tokyo', 'Australia/Sydney' ]

      scheduled_tasks = timezones.map do |tz|
        create(:scheduled_task,
          organization: organization,
          task_template: task_template,
          data_source: data_source,
          name: "#{tz.split('/').last} Task #{SecureRandom.hex(3)}",
          schedule_type: 'daily',
          time_of_day: '09:00',
          timezone: tz,
          active: true
        )
      end

      # Check next run times are different due to timezones
      next_runs = scheduled_tasks.map(&:calculate_next_run)
      expect(next_runs.uniq.count).to be > 1

      # Verify each executes at 9 AM local time
      scheduled_tasks.each do |task|
        next_run_in_tz = task.calculate_next_run.in_time_zone(task.timezone)
        expect(next_run_in_tz.hour).to eq(9)
      end
    end
  end

  describe 'Pipeline creation from scheduled tasks' do
    let(:template_with_multiple_tasks) { create(:task_template,
      organization: organization,
      name: "Complex ETL Template #{SecureRandom.hex(4)}",
      task_type: 'pipeline',
      execution_mode: 'automated',
      template_config: {
        tasks: [
          { name: 'Extract', type: 'extraction', mode: 'automated' },
          { name: 'Validate', type: 'validation', mode: 'manual' },
          { name: 'Transform', type: 'transformation', mode: 'automated' },
          { name: 'Load', type: 'loading', mode: 'automated' }
        ]
      }
    ) }

    it 'creates complete pipeline with all configured tasks' do
      scheduled_task = create(:scheduled_task,
        organization: organization,
        task_template: template_with_multiple_tasks,
        data_source: data_source,
        name: "Complex Pipeline Schedule #{SecureRandom.hex(3)}",
        schedule_type: 'once',
        scheduled_at: 30.minutes.from_now,
        active: true,
        configuration: {
          pipeline_name: "Scheduled ETL #{SecureRandom.hex(3)}",
          priority: rand(5..10),
          execution_mode: 'scheduled'
        }
      )

      # Move to execution time
      travel_to scheduled_task.scheduled_at

      # Execute scheduler
      TaskSchedulerJob.perform_now

      # Verify pipeline was created
      scheduled_task.reload
      run = scheduled_task.scheduled_task_runs.last

      expect(run.status).to eq('completed')
      expect(run.pipeline_execution).to be_present

      pipeline = run.pipeline_execution
      expect(pipeline.pipeline_name).to include("Scheduled ETL")
      expect(pipeline.execution_mode).to eq('scheduled')
      expect(pipeline.metadata['scheduled_task_id']).to eq(scheduled_task.id)

      # Verify tasks were created from template config
      if template_with_multiple_tasks.template_config['tasks']
        expected_task_count = template_with_multiple_tasks.template_config['tasks'].count
        expect(pipeline.tasks.count).to eq(expected_task_count)

        # Verify task dependencies
        pipeline.tasks.order(:position).each_with_index do |task, index|
          if index > 0
            previous_task = pipeline.tasks.find_by(position: index)
            expect(task.depends_on).to include(previous_task.name) if previous_task
          end
        end
      end
    end
  end

  describe 'Monitoring and statistics' do
    before do
      # Create historical scheduled tasks with runs
      rand(5..8).times do |i|
        scheduled_task = create(:scheduled_task,
          organization: organization,
          task_template: task_template,
          data_source: data_source,
          name: "Historical Task #{i + 1}",
          schedule_type: [ 'daily', 'weekly', 'monthly' ].sample,
          created_at: rand(30..90).days.ago,
          active: [ true, false ].sample
        )

        # Create historical runs
        rand(10..20).times do |j|
          run_time = scheduled_task.created_at + (j + 1).days
          duration = rand(60..3600)

          create(:scheduled_task_run,
            scheduled_task: scheduled_task,
            status: [ 'completed', 'failed' ].sample(1, weights: [ 0.8, 0.2 ]).first,
            started_at: run_time,
            completed_at: run_time + duration.seconds,
            duration_seconds: duration,
            pipeline_execution: create(:pipeline_execution,
              organization: organization,
              started_at: run_time,
              completed_at: run_time + duration.seconds
            )
          )
        end
      end
    end

    it 'provides comprehensive execution statistics' do
      stats = ScheduledTask.execution_statistics(organization)

      expect(stats).to include(
        :total_scheduled_tasks,
        :active_scheduled_tasks,
        :total_executions,
        :successful_executions,
        :failed_executions,
        :average_duration,
        :executions_by_type,
        :upcoming_executions
      )

      # Verify statistics accuracy
      expect(stats[:total_scheduled_tasks]).to eq(organization.scheduled_tasks.count)
      expect(stats[:active_scheduled_tasks]).to eq(organization.scheduled_tasks.active.count)
      expect(stats[:total_executions]).to eq(ScheduledTaskRun.joins(:scheduled_task).where(scheduled_tasks: { organization_id: organization.id }).count)

      # Check success rate calculation
      if stats[:total_executions] > 0
        success_rate = (stats[:successful_executions].to_f / stats[:total_executions] * 100).round(2)
        expect(stats[:success_rate]).to eq(success_rate)
      end
    end

    it 'identifies problematic schedules' do
      # Create a failing scheduled task
      failing_task = create(:scheduled_task,
        organization: organization,
        task_template: task_template,
        name: "Problematic Task #{SecureRandom.hex(3)}",
        active: true
      )

      # Create multiple failed runs
      rand(5..8).times do
        create(:scheduled_task_run,
          scheduled_task: failing_task,
          status: 'failed',
          error_message: [ 'Connection failed', 'Timeout', 'Invalid data' ].sample,
          started_at: rand(1..24).hours.ago
        )
      end

      # Get problematic schedules
      problematic = ScheduledTask.with_recent_failures(organization, threshold: 3)

      expect(problematic).to include(failing_task)
      expect(failing_task.recent_failure_count).to be >= 3
    end
  end

  describe 'Concurrent execution handling' do
    it 'prevents duplicate executions for the same schedule' do
      scheduled_task = create(:scheduled_task,
        organization: organization,
        task_template: task_template,
        name: "Concurrent Test #{SecureRandom.hex(3)}",
        schedule_type: 'once',
        scheduled_at: 1.minute.from_now,
        active: true
      )

      travel_to scheduled_task.scheduled_at

      # Simulate concurrent execution attempts
      execution_threads = []
      execution_count = 0
      mutex = Mutex.new

      5.times do
        execution_threads << Thread.new do
          begin
            TaskSchedulerJob.perform_now
            mutex.synchronize { execution_count += 1 }
          rescue ActiveRecord::RecordNotUnique
            # Expected for duplicate attempts
          end
        end
      end

      execution_threads.each(&:join)

      # Should only create one execution
      scheduled_task.reload
      expect(scheduled_task.scheduled_task_runs.count).to eq(1)
      expect(scheduled_task.last_run_at).to be_present
    end
  end
end
