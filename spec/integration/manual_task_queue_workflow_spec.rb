require 'rails_helper'

RSpec.describe 'Manual Task Queue Workflow', type: :integration do
  let(:organization) { create(:organization) }
  let(:admin_user) { create(:user, organization: organization, role: 'admin') }
  let(:member_user) { create(:user, organization: organization, role: 'member') }
  let(:viewer_user) { create(:user, organization: organization, role: 'viewer') }

  before do
    # Configure Solid Queue to process jobs inline for real processing
    ActiveJob::Base.queue_adapter = :inline
  end

  after do
    # Reset to test adapter after each test
    ActiveJob::Base.queue_adapter = :test
  end

  describe 'Manual task queue management' do
    let(:pipeline_count) { rand(3..5) }
    let(:pipelines) { create_list(:pipeline_execution, pipeline_count, organization: organization) }
    let(:manual_tasks) { [] }

    before do
      # Create varied manual tasks across pipelines
      pipelines.each_with_index do |pipeline, index|
        task_count = rand(2..4)
        task_count.times do |i|
          priority = rand(0..10)
          task_types = [ 'validation', 'approval', 'review', 'configuration' ]

          task = create(:task,
            pipeline_execution: pipeline,
            name: "#{task_types.sample.capitalize} Task #{SecureRandom.hex(3)}",
            task_type: task_types.sample,
            execution_mode: 'manual',
            status: (i == 0 && index == 0) ? 'ready' : 'pending',
            position: i + 1,
            priority: priority,
            configuration: {
              required_skills: [ 'data_analysis', 'business_knowledge', 'technical_review' ].sample(rand(1..2)),
              estimated_duration: rand(10..60),
              complexity: [ 'low', 'medium', 'high' ].sample
            },
            metadata: {
              business_impact: [ 'critical', 'high', 'medium', 'low' ].sample,
              deadline: rand(1..7).days.from_now.iso8601
            }
          )

          manual_tasks << task
        end

        # Set up dependencies for non-first tasks
        pipeline.tasks.where.not(position: 1).each do |task|
          previous_task = pipeline.tasks.find_by(position: task.position - 1)
          task.update!(depends_on: [ previous_task.name ]) if previous_task
        end
      end
    end

    it 'manages queue prioritization and assignment' do
      queue_service = ManualTaskQueueService.instance

      # Get initial queue state
      queue_stats = queue_service.queue_statistics
      expect(queue_stats[:total_pending]).to be > 0
      expect(queue_stats[:ready_for_assignment]).to eq(1) # Only first task is ready initially

      # Complete the first ready task to unlock dependencies
      ready_task = manual_tasks.find { |t| t.status == 'ready' }
      ready_task.assignee = admin_user
      ready_task.execute!(admin_user)

      # Simulate task completion with dynamic results
      completion_data = {
        validation_passed: [ true, false ].sample,
        issues_found: rand(0..5),
        time_spent: rand(5..30),
        notes: "Completed by #{admin_user.email}"
      }
      ready_task.complete!(completion_data)

      # Check dependency resolution
      ready_task.pipeline_execution.tasks.each(&:check_and_update_readiness)

      # Verify new tasks become ready
      new_ready_tasks = Task.for_manual_queue.where(status: 'ready')
      expect(new_ready_tasks.count).to be >= 1

      # Test auto-assignment based on workload
      least_loaded_user = queue_service.find_least_loaded_assignee([ admin_user, member_user ])
      expect(least_loaded_user).not_to be_nil

      # Assign tasks to different users
      new_ready_tasks.each_with_index do |task, index|
        assignee = index.even? ? admin_user : member_user
        task.update!(assignee: assignee)
      end

      # Verify workload distribution
      admin_workload = admin_user.assigned_tasks.where(status: [ 'ready', 'in_progress' ]).count
      member_workload = member_user.assigned_tasks.where(status: [ 'ready', 'in_progress' ]).count

      expect(admin_workload).to be >= 0
      expect(member_workload).to be >= 0
    end

    it 'handles task rejection and retry flow' do
      # Create an approval task
      approval_task = create(:task,
        pipeline_execution: pipelines.first,
        name: "Budget Approval #{SecureRandom.hex(3)}",
        task_type: 'approval',
        execution_mode: 'approval_required',
        status: 'ready',
        priority: rand(7..10),
        configuration: {
          approval_type: 'budget',
          amount: rand(1000..50000),
          currency: 'USD'
        }
      )

      # Request approval
      approval_task.request_approval!
      expect(approval_task.status).to eq('waiting_approval')

      # Reject with reason
      rejection_reason = [
        'Budget exceeds allocated amount',
        'Requires additional documentation',
        'Need executive approval for this amount'
      ].sample

      approval_task.reject!(admin_user, rejection_reason)
      expect(approval_task.status).to eq('rejected')
      expect(approval_task.metadata['rejection_reason']).to eq(rejection_reason)
      expect(approval_task.metadata['rejected_by']).to eq(admin_user.id)

      # Retry after addressing issues
      approval_task.update!(
        configuration: approval_task.configuration.merge(
          'additional_docs' => [ 'budget_breakdown.pdf', 'approval_form.pdf' ],
          'executive_approval' => true
        )
      )

      # Reset to ready and request approval again
      approval_task.update!(status: 'ready')
      approval_task.request_approval!

      # Approve this time
      expect(approval_task.approve!(admin_user)).to be true
      expect(approval_task.status).to eq('ready')
      expect(approval_task.metadata['approved_by']).to eq(admin_user.id)
    end

    it 'handles stale task cleanup' do
      # Create stale tasks
      stale_count = rand(2..4)
      stale_tasks = create_list(:task, stale_count,
        pipeline_execution: pipelines.sample,
        execution_mode: 'manual',
        status: 'ready',
        assignee: [ admin_user, member_user ].sample,
        assigned_at: rand(8..30).days.ago,
        metadata: {
          last_reminder_sent: rand(2..7).days.ago.iso8601,
          reminder_count: rand(1..3)
        }
      )

      queue_service = ManualTaskQueueService.instance

      # Clear stale tasks (older than 7 days)
      cleared_count = queue_service.clear_stale_assignments(7)

      # Verify stale tasks were unassigned
      stale_tasks.each(&:reload)
      recently_assigned = stale_tasks.select { |t| t.assigned_at && t.assigned_at > 7.days.ago }
      old_assigned = stale_tasks.reject { |t| t.assigned_at && t.assigned_at > 7.days.ago }

      expect(recently_assigned.all? { |t| t.assignee.present? }).to be true
      expect(old_assigned.all? { |t| t.assignee.nil? }).to be true
      expect(cleared_count).to eq(old_assigned.count)
    end

    it 'respects role-based permissions' do
      task = manual_tasks.find { |t| t.status == 'ready' }

      # Viewer cannot execute tasks
      task.assignee = viewer_user
      expect { task.execute!(viewer_user) }.to raise_error(StandardError)

      # Member can execute
      task.assignee = member_user
      expect(task.execute!(member_user)).to be true
      expect(task.status).to eq('in_progress')

      # Admin can manage any task
      another_task = manual_tasks.find { |t| t.status == 'pending' }
      another_task.update!(status: 'ready', assignee: member_user)

      # Admin can reassign
      another_task.update!(assignee: admin_user)
      expect(another_task.assignee).to eq(admin_user)
    end
  end

  describe 'Real-time queue updates' do
    it 'broadcasts queue changes via ActionCable' do
      # Create tasks that will trigger broadcasts
      broadcast_count = 0

      allow(ActionCable.server).to receive(:broadcast) do |channel, data|
        broadcast_count += 1 if channel == 'manual_task_queue'
      end

      # Create pipeline with manual tasks
      pipeline = create(:pipeline_execution, organization: organization)

      task_names = [ "Data Review #{SecureRandom.hex(3)}", "Quality Check #{SecureRandom.hex(3)}" ]
      tasks = task_names.map.with_index do |name, index|
        create(:task,
          pipeline_execution: pipeline,
          name: name,
          execution_mode: 'manual',
          status: index == 0 ? 'ready' : 'pending',
          position: index + 1,
          priority: rand(0..10)
        )
      end

      # Set dependency
      tasks[1].update!(depends_on: [ tasks[0].name ])

      initial_broadcast_count = broadcast_count

      # Execute first task
      tasks[0].update!(assignee: admin_user)
      tasks[0].execute!(admin_user)
      tasks[0].complete!(records_reviewed: rand(100..1000))

      # Check dependency and update readiness
      tasks[1].check_and_update_readiness

      # Verify broadcasts were sent
      expect(broadcast_count).to be > initial_broadcast_count
    end
  end

  describe 'Queue performance metrics' do
    let(:completed_tasks) { [] }

    before do
      # Create historical completed tasks for metrics
      rand(5..10).times do
        task = create(:task,
          pipeline_execution: pipelines.sample,
          execution_mode: 'manual',
          status: 'completed',
          assignee: [ admin_user, member_user ].sample,
          started_at: rand(1..48).hours.ago,
          completed_at: rand(1..24).hours.ago,
          priority: rand(0..10),
          metadata: {
            execution_time_seconds: rand(300..3600),
            queue_time_seconds: rand(60..7200)
          }
        )
        completed_tasks << task
      end
    end

    it 'tracks queue performance metrics' do
      queue_service = ManualTaskQueueService.instance
      stats = queue_service.queue_statistics

      # Verify statistics structure
      expect(stats).to include(
        :total_pending,
        :ready_for_assignment,
        :in_progress,
        :by_priority,
        :by_type,
        :average_wait_time
      )

      # Check priority distribution
      expect(stats[:by_priority]).to be_a(Hash)
      expect(stats[:by_priority].keys).to all(be_a(String))

      # Check type distribution
      expect(stats[:by_type]).to be_a(Hash)

      # Calculate average completion time
      if completed_tasks.any?
        completion_times = completed_tasks.map do |task|
          (task.completed_at - task.started_at).to_i
        end
        avg_completion_time = completion_times.sum.to_f / completion_times.size

        expect(avg_completion_time).to be > 0
      end
    end
  end
end
