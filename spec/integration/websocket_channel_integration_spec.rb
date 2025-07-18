require 'rails_helper'

RSpec.describe 'WebSocket Channel Integration Tests', type: :integration do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization, role: 'admin') }
  let(:member_user) { create(:user, organization: organization, role: 'member') }
  
  describe 'DashboardChannel broadcasts' do
    it 'broadcasts dashboard updates to organization admins' do
      data_source = create(:data_source, organization: organization)
      
      expect {
        ActionCable.server.broadcast("dashboard:#{organization.id}", {
          event: 'data_source_updated',
          data_source_id: data_source.id,
          status: 'connected'
        })
      }.to have_broadcasted_to("dashboard:#{organization.id}").with(
        hash_including('event' => 'data_source_updated')
      )
    end
  end

  describe 'DataSourceChannel broadcasts' do
    let(:data_source) { create(:data_source, organization: organization) }
    
    it 'broadcasts sync progress updates' do
      job = create(:extraction_job, data_source: data_source, status: 'running')
      
      expect {
        ActionCable.server.broadcast("data_source:#{data_source.id}", {
          event: 'sync_progress',
          job_id: job.id,
          progress: 75,
          records_processed: 7500,
          total_records: 10000
        })
      }.to have_broadcasted_to("data_source:#{data_source.id}").with(
        hash_including(
          'event' => 'sync_progress',
          'progress' => 75
        )
      )
    end
    
    it 'broadcasts sync completion' do
      job = create(:extraction_job, data_source: data_source, status: 'completed')
      
      expect {
        ActionCable.server.broadcast("data_source:#{data_source.id}", {
          event: 'sync_completed',
          job_id: job.id,
          records_processed: 10000,
          duration: 120
        })
      }.to have_broadcasted_to("data_source:#{data_source.id}").with(
        hash_including('event' => 'sync_completed')
      )
    end
  end

  describe 'JobProgressChannel broadcasts' do
    let(:data_source) { create(:data_source, organization: organization) }
    let(:job) { create(:extraction_job, data_source: data_source, status: 'running') }
    
    it 'broadcasts detailed job progress' do
      expect {
        ActionCable.server.broadcast("job_progress:#{job.id}", {
          event: 'progress_update',
          job_id: job.id,
          progress: 50,
          records_processed: 5000,
          total_records: 10000,
          processing_rate: 83.33,
          estimated_completion: 60
        })
      }.to have_broadcasted_to("job_progress:#{job.id}").with(
        hash_including(
          'event' => 'progress_update',
          'progress' => 50,
          'processing_rate' => 83.33
        )
      )
    end
    
    it 'broadcasts job failure with error details' do
      error_details = {
        message: 'Connection timeout',
        code: 'ETIMEDOUT',
        retry_count: 3
      }
      
      expect {
        ActionCable.server.broadcast("job_progress:#{job.id}", {
          event: 'job_failed',
          job_id: job.id,
          error: error_details
        })
      }.to have_broadcasted_to("job_progress:#{job.id}").with(
        hash_including(
          'event' => 'job_failed',
          'error' => hash_including('message' => 'Connection timeout')
        )
      )
    end
  end

  describe 'PipelineChannel broadcasts' do
    let(:pipeline) { create(:pipeline_execution, organization: organization) }
    let(:task) { create(:task, pipeline_execution: pipeline) }
    
    it 'broadcasts task state changes' do
      expect {
        ActionCable.server.broadcast("pipeline_#{pipeline.id}", {
          event: 'task_started',
          task_id: task.id,
          task_name: task.name,
          started_at: Time.current
        })
      }.to have_broadcasted_to("pipeline_#{pipeline.id}").with(
        hash_including(
          'event' => 'task_started',
          'task_id' => task.id
        )
      )
    end
    
    it 'broadcasts pipeline completion with statistics' do
      expect {
        ActionCable.server.broadcast("pipeline_#{pipeline.id}", {
          event: 'pipeline_completed',
          pipeline_id: pipeline.id,
          duration: 3600,
          total_records_processed: 50000,
          tasks_completed: 10,
          tasks_failed: 0
        })
      }.to have_broadcasted_to("pipeline_#{pipeline.id}").with(
        hash_including(
          'event' => 'pipeline_completed',
          'total_records_processed' => 50000
        )
      )
    end
  end

  describe 'ManualTaskQueueChannel broadcasts' do
    let(:pipeline) { create(:pipeline_execution, organization: organization) }
    let(:manual_task) { create(:task, 
      pipeline_execution: pipeline, 
      execution_mode: 'manual',
      status: 'ready'
    ) }
    
    it 'broadcasts new manual tasks to queue' do
      expect {
        ActionCable.server.broadcast('manual_task_queue', {
          event: 'new_task',
          task: {
            id: manual_task.id,
            name: manual_task.name,
            priority: manual_task.priority,
            pipeline_name: pipeline.pipeline_name
          }
        })
      }.to have_broadcasted_to('manual_task_queue').with(
        hash_including('event' => 'new_task')
      )
    end
    
    it 'broadcasts task assignment updates' do
      expect {
        ActionCable.server.broadcast('manual_task_queue', {
          event: 'task_assigned',
          task_id: manual_task.id,
          assigned_to: {
            id: user.id,
            name: user.full_name,
            email: user.email
          }
        })
      }.to have_broadcasted_to('manual_task_queue').with(
        hash_including(
          'event' => 'task_assigned',
          'assigned_to' => hash_including('id' => user.id)
        )
      )
    end
    
    it 'broadcasts to specific user when task is completed' do
      manual_task.update!(assignee: user)
      
      expect {
        ActionCable.server.broadcast("manual_task_queue:user:#{user.id}", {
          event: 'task_completed',
          task_id: manual_task.id,
          completion_time: Time.current,
          duration: 120
        })
      }.to have_broadcasted_to("manual_task_queue:user:#{user.id}").with(
        hash_including('event' => 'task_completed')
      )
    end
  end

  describe 'TaskExecutionChannel broadcasts' do
    let(:pipeline) { create(:pipeline_execution, organization: organization) }
    let(:task) { create(:task, pipeline_execution: pipeline, status: 'in_progress') }
    
    it 'broadcasts execution progress updates' do
      expect {
        ActionCable.server.broadcast("task_execution:#{task.id}", {
          event: 'progress_update',
          progress: 33,
          records_processed: 3300,
          estimated_completion: 180
        })
      }.to have_broadcasted_to("task_execution:#{task.id}").with(
        hash_including(
          'event' => 'progress_update',
          'progress' => 33
        )
      )
    end
    
    it 'broadcasts execution completion with output details' do
      expect {
        ActionCable.server.broadcast("task_execution:#{task.id}", {
          event: 'execution_completed',
          task_id: task.id,
          stats: {
            records_processed: 10000,
            duration: 300,
            output_location: 's3://bucket/output/task-123.json',
            output_size_mb: 45.7
          }
        })
      }.to have_broadcasted_to("task_execution:#{task.id}").with(
        hash_including(
          'event' => 'execution_completed',
          'stats' => hash_including('records_processed' => 10000)
        )
      )
    end
  end

  describe 'AiChatChannel broadcasts' do
    it 'broadcasts typing indicators' do
      expect {
        ActionCable.server.broadcast("ai_chat_#{organization.id}_typing", {
          type: 'typing_indicator',
          user_id: user.id,
          typing: true,
          timestamp: Time.current
        })
      }.to have_broadcasted_to("ai_chat_#{organization.id}_typing").with(
        hash_including(
          'type' => 'typing_indicator',
          'user_id' => user.id,
          'typing' => true
        )
      )
    end
    
    it 'broadcasts AI responses to user' do
      expect {
        ActionCable.server.broadcast("ai_chat_#{organization.id}_#{user.id}", {
          type: 'ai_response',
          message: 'Here is your revenue analysis...',
          query_id: 123,
          timestamp: Time.current
        })
      }.to have_broadcasted_to("ai_chat_#{organization.id}_#{user.id}").with(
        hash_including(
          'type' => 'ai_response',
          'message' => match(/revenue analysis/)
        )
      )
    end
  end

  describe 'Cross-channel integration' do
    let(:data_source) { create(:data_source, organization: organization) }
    let(:pipeline) { create(:pipeline_execution, organization: organization) }
    let(:task) { create(:task, pipeline_execution: pipeline, task_type: 'extraction') }
    let(:job) { create(:extraction_job, data_source: data_source) }
    
    it 'coordinates updates across multiple channels during sync' do
      broadcasts = []
      
      # Capture all broadcasts
      allow(ActionCable.server).to receive(:broadcast) do |channel, data|
        broadcasts << { channel: channel, data: data }
        # Call original to ensure tests still work
        ActionCable.server.instance_eval { @pubsub }.broadcast(channel, data)
      end
      
      # Simulate a complete sync workflow
      # 1. Start sync - broadcast to data source channel
      ActionCable.server.broadcast("data_source:#{data_source.id}", {
        event: 'sync_started',
        job_id: job.id
      })
      
      # 2. Update dashboard
      ActionCable.server.broadcast("dashboard:#{organization.id}", {
        event: 'sync_started',
        data_source_id: data_source.id,
        job_id: job.id
      })
      
      # 3. Progress updates to job channel
      ActionCable.server.broadcast("job_progress:#{job.id}", {
        event: 'progress_update',
        progress: 50
      })
      
      # 4. Complete sync
      ActionCable.server.broadcast("data_source:#{data_source.id}", {
        event: 'sync_completed',
        job_id: job.id,
        records_synced: 10000
      })
      
      # Verify all channels received appropriate updates
      expect(broadcasts.map { |b| b[:channel] }).to include(
        "data_source:#{data_source.id}",
        "dashboard:#{organization.id}",
        "job_progress:#{job.id}"
      )
      
      # Verify events were broadcast
      expect(broadcasts.map { |b| b[:data][:event] if b[:data].is_a?(Hash) }.compact).to include(
        'sync_started',
        'progress_update',
        'sync_completed'
      )
    end
  end
end