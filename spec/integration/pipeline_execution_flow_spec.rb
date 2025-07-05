require 'rails_helper'

RSpec.describe 'Pipeline Execution Flow', type: :integration do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization, role: 'admin') }
  let(:data_source) { create(:data_source, organization: organization) }

  before do
    # Configure Solid Queue to process jobs inline in test environment
    # This ensures real job processing happens synchronously for testing
    ActiveJob::Base.queue_adapter = :inline
  end

  after do
    # Reset to test adapter after each test
    ActiveJob::Base.queue_adapter = :test
  end

  describe 'Complete pipeline execution with mixed task types' do
    let(:pipeline) { create(:pipeline_execution,
      organization: organization,
      data_source: data_source,
      user: user,
      pipeline_name: "Test ETL Pipeline #{SecureRandom.hex(4)}"
    ) }

    let!(:extraction_task) { create(:task,
      pipeline_execution: pipeline,
      name: "Extract Data #{SecureRandom.hex(4)}",
      task_type: 'extraction',
      execution_mode: 'automated',
      position: 1,
      status: 'ready',
      configuration: {
        batch_size: rand(50..200),
        timeout: rand(30..120)
      }
    ) }

    let!(:validation_task) { create(:task,
      pipeline_execution: pipeline,
      name: "Validate Data #{SecureRandom.hex(4)}",
      task_type: 'validation',
      execution_mode: 'manual',
      position: 2,
      status: 'pending',
      depends_on: [ extraction_task.name ],
      configuration: {
        validation_rules: [ 'required_fields', 'data_types' ].sample(rand(1..2)),
        threshold: rand(80..95)
      }
    ) }

    let!(:transformation_task) { create(:task,
      pipeline_execution: pipeline,
      name: "Transform Data #{SecureRandom.hex(4)}",
      task_type: 'transformation',
      execution_mode: 'approval_required',
      position: 3,
      status: 'pending',
      depends_on: [ validation_task.name ],
      configuration: {
        transformations: [ 'normalize', 'deduplicate', 'enrich' ].sample(rand(1..3)),
        output_format: [ 'json', 'csv', 'parquet' ].sample
      }
    ) }

    let!(:notification_task) { create(:task,
      pipeline_execution: pipeline,
      name: "Send Notification #{SecureRandom.hex(4)}",
      task_type: 'notification',
      execution_mode: 'automated',
      position: 4,
      status: 'pending',
      depends_on: [ transformation_task.name ],
      configuration: {
        notification_type: [ 'email', 'slack', 'webhook' ].sample,
        recipients: rand(1..5)
      }
    ) }

    it 'executes automated tasks, waits for manual tasks, and requires approvals' do
      # Start pipeline
      expect(pipeline.status).to eq('queued')
      pipeline.start!
      expect(pipeline.status).to eq('running')

      # Execute automated extraction task
      expect(extraction_task.can_execute?).to be true
      extraction_task.execute!
      expect(extraction_task.status).to eq('in_progress')

      # Simulate task completion with dynamic values
      records_processed = rand(50..500)
      extraction_task.complete!(records_processed: records_processed)
      expect(extraction_task.status).to eq('completed')

      # Check dependency resolution
      validation_task.check_and_update_readiness
      expect(validation_task.reload.status).to eq('ready')

      # Manual task requires assignment
      expect(validation_task.can_execute?).to be false
      validation_task.assignee = user
      expect(validation_task.can_execute?).to be true

      # Execute manual task
      validation_task.execute!(user)
      expect(validation_task.status).to eq('in_progress')
      validation_passed = [ true, false ].sample
      validation_errors = validation_passed ? 0 : rand(1..10)
      validation_task.complete!(
        validation_passed: validation_passed,
        validation_errors: validation_errors,
        records_validated: rand(50..500)
      )

      # Transformation task requires approval
      transformation_task.check_and_update_readiness
      expect(transformation_task.reload.status).to eq('ready')
      transformation_task.request_approval!
      expect(transformation_task.status).to eq('waiting_approval')

      # Approve and execute
      expect(transformation_task.approve!(user)).to be true
      expect(transformation_task.status).to eq('ready')
      transformation_task.execute!(user)
      records_transformed = rand(40..480)
      transformation_task.complete!(
        records_transformed: records_transformed,
        transformations_applied: rand(1..5)
      )

      # Final notification task
      notification_task.check_and_update_readiness
      expect(notification_task.reload.status).to eq('ready')
      notification_task.execute!
      notifications_sent = rand(1..10)
      notification_task.complete!(
        notifications_sent: notifications_sent,
        notification_type: notification_task.configuration['notification_type']
      )

      # Update pipeline status
      pipeline.update_task_progress!
      expect(pipeline.reload.status).to eq('completed')
      expect(pipeline.progress_percentage).to eq(100)
      expect(pipeline.completed_tasks).to eq(pipeline.tasks.count)
      expect(pipeline.failed_tasks).to eq(0)
    end

    it 'handles task failures and retries' do
      pipeline.start!

      # Simulate extraction failure
      extraction_task.execute!
      error_messages = [
        'Connection timeout',
        'Authentication failed',
        'Rate limit exceeded',
        'Invalid response format'
      ]
      extraction_task.fail!(error_messages.sample)
      expect(extraction_task.status).to eq('ready') # Auto-retry
      expect(extraction_task.retry_count).to eq(1)

      # Retry and succeed
      extraction_task.execute!
      extraction_task.complete!

      # Check pipeline is still running
      pipeline.update_task_progress!
      expect(pipeline.reload.status).to eq('running')
    end

    it 'supports pipeline pause and resume' do
      pipeline.start!
      extraction_task.execute!

      # Pause pipeline
      expect(pipeline.can_pause?).to be true
      pipeline.pause!
      expect(pipeline.status).to eq('paused')

      # Tasks should not execute when paused
      extraction_task.complete!
      validation_task.check_and_update_readiness
      expect(validation_task.reload.status).to eq('ready')

      # Resume pipeline
      expect(pipeline.can_resume?).to be true
      pipeline.resume!
      expect(pipeline.status).to eq('running')
    end

    it 'handles task cancellation' do
      pipeline.start!

      # Cancel a ready task
      expect(extraction_task.can_cancel?).to be true
      extraction_task.cancel!
      expect(extraction_task.status).to eq('cancelled')

      # Dependent tasks should not become ready
      validation_task.check_and_update_readiness
      expect(validation_task.reload.status).to eq('pending')

      # Pipeline should reflect the cancellation
      pipeline.update_task_progress!
      expect(pipeline.reload.status).to eq('failed')
    end
  end

  describe 'Pipeline execution with task templates' do
    let(:template) { create(:task_template,
      organization: organization,
      name: "Standard Validation #{SecureRandom.hex(4)}",
      task_type: 'validation',
      execution_mode: 'automated',
      template_config: {
        rules: [ 'required_fields', 'data_types', 'value_ranges', 'referential_integrity' ].sample(rand(2..3)),
        severity: [ 'warning', 'error', 'critical' ].sample
      }
    ) }

    it 'creates tasks from templates' do
      pipeline = create(:pipeline_execution, organization: organization)

      # Create task from template with dynamic values
      task = template.create_task_from_template(pipeline,
        name: "Validate Customer Data #{SecureRandom.hex(4)}",
        configuration: {
          additional_rule: [ 'email_format', 'phone_format', 'address_validation' ].sample,
          batch_size: rand(100..1000)
        },
        timeout_seconds: rand(60..600),
        priority: rand(0..10)
      )

      expect(task).to be_persisted
      expect(task.task_type).to eq('validation')
      expect(task.execution_mode).to eq('automated')
      expect(task.configuration['rules']).to match_array(template.template_config['rules'])
      expect(task.configuration['additional_rule']).to be_present
      expect(task.configuration['batch_size']).to be_between(100, 1000)
      expect(task.metadata['template_id']).to eq(template.id)
    end
  end

  describe 'Real-time updates via ActionCable' do
    it 'broadcasts task status changes' do
      pipeline = create(:pipeline_execution, organization: organization)
      task = create(:task, pipeline_execution: pipeline, status: 'ready')

      # Expect broadcast when task status changes
      expect(ActionCable.server).to receive(:broadcast).with(
        "pipeline_#{pipeline.id}",
        hash_including(type: 'task_status_update', task_id: task.id)
      )

      task.execute!
    end

    it 'broadcasts to manual task queue' do
      task = create(:task,
        pipeline_execution: create(:pipeline_execution, organization: organization),
        execution_mode: 'manual',
        status: 'pending'
      )

      # Expect broadcast when manual task becomes ready
      expect(ActionCable.server).to receive(:broadcast).with(
        "manual_task_queue",
        hash_including(type: 'new_manual_task')
      )

      task.update!(status: 'ready')
    end
  end

  describe 'Pipeline metrics and monitoring' do
    let(:started_hours_ago) { rand(1..6) }
    let(:pipeline) { create(:pipeline_execution,
      organization: organization,
      started_at: started_hours_ago.hours.ago,
      pipeline_name: "Analytics Pipeline #{SecureRandom.hex(4)}"
    ) }

    before do
      task_count = rand(2..5)
      start_time = rand(30..90).minutes.ago
      completion_time = rand(5..25).minutes.ago

      create_list(:task, task_count,
        pipeline_execution: pipeline,
        status: 'completed',
        started_at: start_time,
        completed_at: completion_time,
        task_type: [ 'extraction', 'transformation', 'validation' ].sample,
        metadata: { records_processed: rand(100..10000) }
      )

      failed_count = rand(1..2)
      error_messages = [
        'Validation error: Missing required fields',
        'Transformation failed: Invalid data format',
        'Extraction error: Source unavailable',
        'Processing timeout exceeded'
      ]

      create_list(:task, failed_count,
        pipeline_execution: pipeline,
        status: 'failed',
        error_message: error_messages.sample,
        retry_count: rand(0..3)
      )
    end

    it 'calculates pipeline metrics correctly' do
      total_tasks = pipeline.tasks.count
      completed_tasks = pipeline.tasks.where(status: 'completed').count
      failed_tasks = pipeline.tasks.where(status: 'failed').count
      expected_progress = ((completed_tasks.to_f / total_tasks) * 100).round

      expect(pipeline.total_tasks).to eq(total_tasks)
      expect(pipeline.completed_tasks).to eq(completed_tasks)
      expect(pipeline.failed_tasks).to eq(failed_tasks)
      expect(pipeline.progress_percentage).to eq(expected_progress)
      expect(pipeline.duration_seconds).to be > 0
    end

    it 'tracks execution history' do
      pipeline.complete!

      # Create another execution
      new_pipeline = pipeline.retry!
      expect(new_pipeline.retry_count).to eq(1)
      expect(new_pipeline.metadata['original_pipeline_id']).to eq(pipeline.id)
      expect(new_pipeline.metadata['retry_reason']).to be_present
    end
  end
end
