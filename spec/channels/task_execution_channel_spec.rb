require 'rails_helper'

RSpec.describe TaskExecutionChannel, type: :channel do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }
  let(:pipeline) { create(:pipeline_execution, organization: organization, user: user) }
  let(:task) { create(:task, pipeline_execution: pipeline, status: 'ready') }

  before do
    stub_connection current_user: user
  end

  describe '#subscribed' do
    context 'with valid task' do
      it 'subscribes to task execution stream' do
        subscribe(task_id: task.id)
        
        expect(subscription).to be_confirmed
        expect(subscription).to have_stream_from("task_execution:#{task.id}")
      end

      it 'sends initial task state' do
        subscribe(task_id: task.id)
        
        expect(transmissions.last).to include(
          'task' => hash_including(
            'id' => task.id,
            'name' => task.name,
            'status' => 'ready',
            'can_execute' => true,
            'requires_approval' => false
          )
        )
      end
    end

    context 'with unauthorized task' do
      let(:other_org) { create(:organization) }
      let(:other_pipeline) { create(:pipeline_execution, organization: other_org) }
      let(:other_task) { create(:task, pipeline_execution: other_pipeline) }

      it 'rejects subscription' do
        subscribe(task_id: other_task.id)
        expect(subscription).to be_rejected
      end
    end
  end

  describe '#execute_task' do
    context 'with manual task' do
      let(:manual_task) do
        create(:task,
          pipeline_execution: pipeline,
          execution_mode: 'manual',
          status: 'ready',
          assigned_to: user
        )
      end

      before do
        subscribe(task_id: manual_task.id)
      end

      it 'executes the task' do
        expect {
          perform :execute_task
        }.to change { manual_task.reload.status }.from('ready').to('running')
        
        expect(transmissions.last).to include(
          'action' => 'task_started',
          'task_id' => manual_task.id,
          'message' => match(/execution started/i)
        )
      end

      it 'broadcasts execution start' do
        expect {
          perform :execute_task
        }.to have_broadcasted_to("task_execution:#{manual_task.id}").with(
          hash_including(
            'event' => 'execution_started',
            'task_id' => manual_task.id
          )
        )
      end

      context 'when task is not assigned to user' do
        before do
          manual_task.update!(assigned_to: nil)
        end

        it 'sends error message' do
          perform :execute_task
          
          expect(transmissions.last).to include(
            'error' => match(/not assigned/i)
          )
        end
      end
    end

    context 'with automated task' do
      let(:auto_task) do
        create(:task,
          pipeline_execution: pipeline,
          execution_mode: 'automated',
          status: 'ready'
        )
      end

      before do
        subscribe(task_id: auto_task.id)
      end

      it 'prevents manual execution' do
        perform :execute_task
        
        expect(transmissions.last).to include(
          'error' => match(/automated.*cannot.*manually/i)
        )
      end
    end

    context 'with task in wrong state' do
      before do
        task.update!(status: 'completed')
        subscribe(task_id: task.id)
      end

      it 'sends error message' do
        perform :execute_task
        
        expect(transmissions.last).to include(
          'error' => match(/already completed/i)
        )
      end
    end
  end

  describe '#approve_task' do
    let(:approval_task) do
      create(:task,
        pipeline_execution: pipeline,
        execution_mode: 'approval_required',
        status: 'ready'
      )
    end

    before do
      subscribe(task_id: approval_task.id)
    end

    context 'with proper permissions' do
      let(:admin_user) { create(:user, organization: organization, role: 'admin') }

      before do
        stub_connection current_user: admin_user
        subscribe(task_id: approval_task.id)
      end

      it 'approves and executes the task' do
        expect {
          perform :approve_task, comment: 'Approved for processing'
        }.to change { approval_task.reload.status }.from('ready').to('running')
        
        expect(transmissions.last).to include(
          'action' => 'task_approved',
          'task_id' => approval_task.id,
          'approved_by' => admin_user.id
        )
      end

      it 'records approval in task metadata' do
        perform :approve_task, comment: 'Looks good'
        
        approval_task.reload
        expect(approval_task.metadata['approval']).to include(
          'approved_by' => admin_user.id,
          'approved_at' => be_present,
          'comment' => 'Looks good'
        )
      end
    end

    context 'without proper permissions' do
      it 'sends unauthorized error' do
        perform :approve_task
        
        expect(transmissions.last).to include(
          'error' => match(/permission.*approve/i)
        )
      end
    end
  end

  describe '#reject_task' do
    let(:approval_task) do
      create(:task,
        pipeline_execution: pipeline,
        execution_mode: 'approval_required',
        status: 'ready'
      )
    end

    before do
      stub_connection current_user: create(:user, organization: organization, role: 'admin')
      subscribe(task_id: approval_task.id)
    end

    it 'rejects the task with reason' do
      expect {
        perform :reject_task, reason: 'Data quality issues detected'
      }.to change { approval_task.reload.status }.from('ready').to('rejected')
      
      expect(transmissions.last).to include(
        'action' => 'task_rejected',
        'task_id' => approval_task.id
      )
    end

    it 'requires rejection reason' do
      perform :reject_task
      
      expect(transmissions.last).to include(
        'error' => match(/reason.*required/i)
      )
    end

    it 'records rejection details' do
      perform :reject_task, reason: 'Missing required data'
      
      approval_task.reload
      expect(approval_task.metadata['rejection']).to include(
        'rejected_by' => connection.current_user.id,
        'rejected_at' => be_present,
        'reason' => 'Missing required data'
      )
    end
  end

  describe 'real-time execution updates' do
    before do
      subscribe(task_id: task.id)
    end

    it 'broadcasts execution progress' do
      task.update!(status: 'running')
      
      progress_updates = [
        { progress: 25, records_processed: 250 },
        { progress: 50, records_processed: 500 },
        { progress: 75, records_processed: 750 }
      ]
      
      progress_updates.each do |update|
        expect {
          ActionCable.server.broadcast("task_execution:#{task.id}", {
            event: 'progress_update',
            **update
          })
        }.to have_broadcasted_to("task_execution:#{task.id}").with(
          hash_including('event' => 'progress_update')
        )
      end
    end

    it 'broadcasts execution completion' do
      task.update!(status: 'running')
      
      expect {
        task.complete!(
          records_processed: 1000,
          duration_seconds: 120,
          output_location: 's3://bucket/output.json'
        )
        
        ActionCable.server.broadcast("task_execution:#{task.id}", {
          event: 'execution_completed',
          task_id: task.id,
          stats: {
            records_processed: 1000,
            duration: 120,
            output_location: 's3://bucket/output.json'
          }
        })
      }.to have_broadcasted_to("task_execution:#{task.id}").with(
        hash_including(
          'event' => 'execution_completed',
          'stats' => hash_including('records_processed' => 1000)
        )
      )
    end

    it 'broadcasts execution failure' do
      task.update!(status: 'running')
      
      error_details = {
        message: 'Memory limit exceeded',
        code: 'OOM_ERROR',
        stacktrace: ['line1', 'line2']
      }
      
      expect {
        task.update!(
          status: 'failed',
          error_message: error_details[:message],
          metadata: { error: error_details }
        )
        
        ActionCable.server.broadcast("task_execution:#{task.id}", {
          event: 'execution_failed',
          task_id: task.id,
          error: error_details
        })
      }.to have_broadcasted_to("task_execution:#{task.id}").with(
        hash_including(
          'event' => 'execution_failed',
          'error' => hash_including('message' => 'Memory limit exceeded')
        )
      )
    end
  end
end