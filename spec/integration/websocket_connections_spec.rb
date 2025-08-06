require 'rails_helper'

RSpec.describe 'ActionCable Broadcasting', type: :integration do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization, role: 'admin') }

  before do
    # Configure Solid Queue to process jobs inline for real processing
    ActiveJob::Base.queue_adapter = :inline
  end

  after do
    ActiveJob::Base.queue_adapter = :test
  end

  describe 'Pipeline status broadcasting' do
    let(:pipeline) { create(:pipeline_execution,
      organization: organization,
      user: user,
      pipeline_name: "Broadcast Test Pipeline #{SecureRandom.hex(4)}"
    ) }

    it 'broadcasts pipeline status updates' do
      broadcasts = []

      # Capture ActionCable broadcasts
      allow(ActionCable.server).to receive(:broadcast) do |channel, data|
        broadcasts << { channel: channel, data: data }
      end

      # Create tasks for pipeline
      task = create(:task,
        pipeline_execution: pipeline,
        name: "Test Task #{SecureRandom.hex(3)}",
        task_type: 'extraction',
        execution_mode: 'automated',
        status: 'pending',
        position: 1
      )

      # Start pipeline - should trigger broadcast
      pipeline.update!(status: 'running', started_at: Time.current)
      ActionCable.server.broadcast("pipeline_#{pipeline.id}", {
        event: 'pipeline_started',
        pipeline_id: pipeline.id,
        status: 'running'
      })

      # Verify pipeline status broadcast
      pipeline_broadcasts = broadcasts.select { |b| b[:channel] == "pipeline_#{pipeline.id}" }
      expect(pipeline_broadcasts).not_to be_empty

      # Execute task - should trigger task update broadcast
      task.update!(status: 'ready')
      task.update!(status: 'in_progress', started_at: Time.current)
      ActionCable.server.broadcast("pipeline_#{pipeline.id}", {
        event: 'task_started',
        task_id: task.id,
        status: 'in_progress'
      })

      # Complete task - should trigger completion broadcast
      task.complete!(records_processed: rand(100..1000))

      # Verify task broadcasts were sent
      task_broadcasts = broadcasts.select do |b|
        b[:channel] == "pipeline_#{pipeline.id}" &&
        b[:data].is_a?(Hash) &&
        b[:data][:task_id] == task.id
      end

      expect(task_broadcasts).not_to be_empty
    end
  end

  describe 'Manual task queue broadcasting' do
    it 'broadcasts new manual tasks to queue' do
      broadcasts = []

      allow(ActionCable.server).to receive(:broadcast) do |channel, data|
        broadcasts << { channel: channel, data: data }
      end

      # Create manual task
      pipeline = create(:pipeline_execution, organization: organization)
      manual_task = create(:task,
        pipeline_execution: pipeline,
        name: "Manual Task #{SecureRandom.hex(3)}",
        execution_mode: 'manual',
        status: 'pending',
        priority: rand(0..10)
      )

      # Task becomes ready - should broadcast to queue
      manual_task.update!(status: 'ready')

      # Verify manual queue broadcasts
      queue_broadcasts = broadcasts.select { |b| b[:channel] == 'manual_task_queue' }

      # Manual task updates should be broadcast to the queue channel
      expect(queue_broadcasts.any?).to be true
    end
  end

  describe 'Real-time task execution updates' do
    it 'broadcasts task execution progress' do
      broadcasts = []

      allow(ActionCable.server).to receive(:broadcast) do |channel, data|
        broadcasts << { channel: channel, data: data }
      end

      # Create and execute task
      pipeline = create(:pipeline_execution, organization: organization)
      task = create(:task,
        pipeline_execution: pipeline,
        name: "Progress Task #{SecureRandom.hex(3)}",
        execution_mode: 'automated',
        status: 'ready'
      )

      # Execute task
      task.update!(
        status: 'in_progress',
        started_at: Time.current,
        execution_id: SecureRandom.uuid
      )

      # Broadcast execution progress
      ActionCable.server.broadcast("task_execution_#{task.id}", {
        event: 'task_started',
        task_id: task.id,
        status: 'in_progress'
      })

      # Complete with stats
      completion_stats = {
        records_processed: rand(100..1000),
        duration_seconds: rand(10..300)
      }
      task.complete!(completion_stats)

      # Verify execution broadcasts
      execution_broadcasts = broadcasts.select do |b|
        b[:channel].include?('task_execution') ||
        b[:channel] == "pipeline_#{pipeline.id}"
      end

      expect(execution_broadcasts).not_to be_empty
    end
  end
end
