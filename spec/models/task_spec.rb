require 'rails_helper'

RSpec.describe Task, type: :model do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }
  let(:data_source) { create(:data_source, organization: organization) }
  let(:pipeline_execution) { create(:pipeline_execution, data_source: data_source, user: user) }
  let(:task) { create(:task, pipeline_execution: pipeline_execution) }

  describe 'associations' do
    it { should belong_to(:pipeline_execution) }
    it { should belong_to(:assignee).class_name('User').optional }
    it { should have_many(:task_executions).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:task_type) }
    it { should validate_presence_of(:execution_mode) }
    it { should validate_presence_of(:status) }
    
    it { should validate_inclusion_of(:task_type).in_array(Task::TASK_TYPES) }
    it { should validate_inclusion_of(:execution_mode).in_array(Task::EXECUTION_MODES) }
    it { should validate_inclusion_of(:status).in_array(Task::STATUSES) }
    
    it { should validate_numericality_of(:priority).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:timeout_seconds).is_greater_than(0) }
    it { should validate_numericality_of(:max_retries).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:retry_count).is_greater_than_or_equal_to(0) }
  end

  describe 'scopes' do
    let!(:pending_task) { create(:task, status: 'pending', pipeline_execution: pipeline_execution) }
    let!(:ready_task) { create(:task, status: 'ready', pipeline_execution: pipeline_execution) }
    let!(:manual_task) { create(:task, execution_mode: 'manual', pipeline_execution: pipeline_execution) }
    let!(:automated_task) { create(:task, execution_mode: 'automated', pipeline_execution: pipeline_execution) }

    it 'returns pending tasks' do
      expect(Task.pending).to include(pending_task)
      expect(Task.pending).not_to include(ready_task)
    end

    it 'returns manual tasks' do
      expect(Task.manual).to include(manual_task)
      expect(Task.manual).not_to include(automated_task)
    end

    it 'orders by priority' do
      high_priority = create(:task, priority: 10, position: 1, pipeline_execution: pipeline_execution)
      low_priority = create(:task, priority: 1, position: 2, pipeline_execution: pipeline_execution)
      
      ordered_tasks = Task.where(id: [high_priority.id, low_priority.id]).by_priority
      expect(ordered_tasks.first).to eq(high_priority)
      expect(ordered_tasks.last).to eq(low_priority)
    end
  end

  describe '#can_execute?' do
    context 'automated task' do
      let(:task) { create(:task, execution_mode: 'automated', status: 'ready', pipeline_execution: pipeline_execution) }

      it 'returns true when ready' do
        expect(task.can_execute?).to be true
      end

      it 'returns false when not ready' do
        task.update!(status: 'pending')
        expect(task.can_execute?).to be false
      end
    end

    context 'manual task' do
      let(:task) { create(:task, execution_mode: 'manual', status: 'ready', pipeline_execution: pipeline_execution) }

      it 'returns true when ready with assignee' do
        task.update!(assignee: user)
        expect(task.can_execute?).to be true
      end

      it 'returns false without assignee' do
        expect(task.can_execute?).to be false
      end
    end

    context 'approval required task' do
      let(:task) { create(:task, execution_mode: 'approval_required', status: 'waiting_approval', assignee: user, pipeline_execution: pipeline_execution) }

      it 'returns true when waiting approval with assignee' do
        expect(task.can_execute?).to be true
      end

      it 'returns false without assignee' do
        task.update!(assignee: nil)
        expect(task.can_execute?).to be false
      end
    end
  end

  describe '#execute!' do
    let(:task) { create(:task, execution_mode: 'automated', status: 'ready', pipeline_execution: pipeline_execution) }

    it 'updates task status and queues job' do
      expect(TaskExecutorJob).to receive(:perform_later).with(task)
      
      result = task.execute!
      
      expect(result).to be true
      expect(task.status).to eq('in_progress')
      expect(task.started_at).to be_present
      expect(task.execution_id).to be_present
    end

    it 'sets assignee when provided' do
      task.update!(execution_mode: 'manual', assignee: user)
      
      task.execute!(user)
      
      expect(task.assignee).to eq(user)
    end

    it 'returns false when cannot execute' do
      task.update!(status: 'pending')
      
      result = task.execute!
      
      expect(result).to be false
      expect(task.status).to eq('pending')
    end
  end

  describe '#complete!' do
    let(:task) { create(:task, status: 'in_progress', pipeline_execution: pipeline_execution) }

    it 'marks task as completed' do
      result = { processed: 100, errors: 0 }
      
      task.complete!(result)
      
      expect(task.status).to eq('completed')
      expect(task.completed_at).to be_present
      expect(task.metadata['result']).to eq(result.stringify_keys)
    end
  end

  describe '#fail!' do
    let(:task) { create(:task, status: 'in_progress', retry_count: 0, max_retries: 3, pipeline_execution: pipeline_execution) }

    it 'retries when under retry limit' do
      task.fail!('Temporary error')
      
      expect(task.status).to eq('ready')
      expect(task.retry_count).to eq(1)
      expect(task.error_message).to eq('Temporary error')
    end

    it 'marks as failed when at retry limit' do
      task.update!(retry_count: 2)
      
      task.fail!('Final error')
      
      expect(task.status).to eq('failed')
      expect(task.retry_count).to eq(3)
      expect(task.completed_at).to be_present
    end

    it 'marks as failed when retry disabled' do
      task.fail!('Error', false)
      
      expect(task.status).to eq('failed')
      expect(task.retry_count).to eq(1)
    end
  end

  describe '#dependencies_satisfied?' do
    let(:task1) { create(:task, name: 'task1', status: 'completed', pipeline_execution: pipeline_execution) }
    let(:task2) { create(:task, name: 'task2', status: 'completed', pipeline_execution: pipeline_execution) }
    let(:task3) { create(:task, name: 'task3', depends_on: ['task1', 'task2'], pipeline_execution: pipeline_execution) }

    it 'returns true when all dependencies completed' do
      expect(task3.dependencies_satisfied?).to be true
    end

    it 'returns false when dependency not completed' do
      task1.update!(status: 'in_progress')
      expect(task3.dependencies_satisfied?).to be false
    end

    it 'returns true when no dependencies' do
      task = create(:task, depends_on: [], pipeline_execution: pipeline_execution)
      expect(task.dependencies_satisfied?).to be true
    end
  end

  describe '#approve!' do
    let(:task) { create(:task, execution_mode: 'approval_required', status: 'waiting_approval', pipeline_execution: pipeline_execution) }

    it 'approves task and sets assignee' do
      task.approve!(user)
      
      expect(task.status).to eq('ready')
      expect(task.assignee).to eq(user)
      expect(task.metadata['approved_by']).to eq(user.id)
      expect(task.metadata['approved_at']).to be_present
    end

    it 'returns false when not waiting approval' do
      task.update!(status: 'ready')
      
      result = task.approve!(user)
      
      expect(result).to be false
    end
  end

  describe '#reject!' do
    let(:task) { create(:task, execution_mode: 'approval_required', status: 'waiting_approval', pipeline_execution: pipeline_execution) }

    it 'rejects task with reason' do
      task.reject!(user, 'Not appropriate')
      
      expect(task.status).to eq('cancelled')
      expect(task.completed_at).to be_present
      expect(task.metadata['rejected_by']).to eq(user.id)
      expect(task.metadata['rejection_reason']).to eq('Not appropriate')
    end
  end

  describe 'callbacks' do
    it 'sets defaults on create' do
      task = Task.create!(
        name: 'Test Task',
        task_type: 'custom',
        execution_mode: 'automated',
        pipeline_execution: pipeline_execution
      )
      
      expect(task.execution_id).to be_present
      expect(task.status).to eq('pending')
      expect(task.priority).to eq(0)
      expect(task.retry_count).to eq(0)
      expect(task.configuration).to eq({})
      expect(task.metadata).to eq({})
      expect(task.depends_on).to eq([])
    end

    it 'broadcasts status change' do
      task = create(:task, status: 'pending', pipeline_execution: pipeline_execution)
      
      expect(ActionCable.server).to receive(:broadcast).with(
        "pipeline_#{task.pipeline_execution_id}",
        hash_including(type: 'task_status_update')
      )
      
      task.update!(status: 'ready')
    end

    it 'broadcasts manual task to queue' do
      task = create(:task, execution_mode: 'manual', status: 'pending', pipeline_execution: pipeline_execution)
      
      expect(ActionCable.server).to receive(:broadcast).with(
        "pipeline_#{task.pipeline_execution_id}",
        anything
      )
      expect(ActionCable.server).to receive(:broadcast).with(
        "manual_task_queue",
        hash_including(type: 'new_manual_task')
      )
      
      task.update!(status: 'ready')
    end
  end
end
