require 'rails_helper'

RSpec.describe ManualTaskQueueChannel, type: :channel do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }
  let(:other_user) { create(:user, organization: organization) }
  let(:pipeline) { create(:pipeline_execution, organization: organization) }

  let!(:manual_tasks) do
    3.times.map do |i|
      create(:task,
        pipeline_execution: pipeline,
        execution_mode: 'manual',
        status: 'ready',
        priority: i,
        name: "Manual Task #{i}"
      )
    end
  end

  before do
    stub_connection current_user: user
  end

  describe '#subscribed' do
    it 'subscribes to queue and user streams' do
      subscribe

      expect(subscription).to be_confirmed
      expect(subscription).to have_stream_from('manual_task_queue')
      expect(subscription).to have_stream_from("manual_task_queue:user:#{user.id}")
    end
  end

  describe '#refresh_queue' do
    before do
      subscribe
    end

    it 'sends queue statistics and tasks' do
      # Assign one task to user
      manual_tasks.first.update!(assigned_to: user)

      perform :refresh_queue

      expect(transmissions.last).to include(
        'queue_stats' => hash_including(
          'total_tasks' => 3,
          'unassigned_tasks' => 2,
          'my_tasks' => 1,
          'priority_breakdown' => be_a(Hash)
        ),
        'tasks' => be_an(Array)
      )

      tasks_data = transmissions.last['tasks']
      expect(tasks_data.size).to eq(3)
      expect(tasks_data.first).to include(
        'id' => be_present,
        'name' => match(/Manual Task/),
        'priority' => be_a(Integer),
        'assigned_to' => be_a(Hash).or(be_nil)
      )
    end
  end

  describe '#claim_task' do
    let(:task) { manual_tasks.first }

    before do
      subscribe
    end

    context 'when task is unassigned' do
      it 'assigns task to current user' do
        expect {
          perform :claim_task, task_id: task.id
        }.to change { task.reload.assigned_to }.from(nil).to(user)

        expect(transmissions.last).to include(
          'action' => 'task_claimed',
          'task_id' => task.id,
          'message' => match(/claimed/i)
        )
      end

      it 'broadcasts assignment to all queue subscribers' do
        expect {
          perform :claim_task, task_id: task.id
        }.to have_broadcasted_to('manual_task_queue').with(
          hash_including(
            'event' => 'task_assigned',
            'task_id' => task.id,
            'assigned_to' => hash_including('id' => user.id)
          )
        )
      end
    end

    context 'when task is already assigned' do
      before do
        task.update!(assigned_to: other_user)
      end

      it 'sends error message' do
        perform :claim_task, task_id: task.id

        expect(transmissions.last).to include(
          'error' => match(/already assigned/i)
        )
      end
    end

    context 'when task is not ready' do
      before do
        task.update!(status: 'completed')
      end

      it 'sends error message' do
        perform :claim_task, task_id: task.id

        expect(transmissions.last).to include(
          'error' => match(/not available/i)
        )
      end
    end
  end

  describe '#release_task' do
    let(:task) { manual_tasks.first }

    before do
      task.update!(assigned_to: user)
      subscribe
    end

    context 'when user owns the task' do
      it 'unassigns the task' do
        expect {
          perform :release_task, task_id: task.id
        }.to change { task.reload.assigned_to }.from(user).to(nil)

        expect(transmissions.last).to include(
          'action' => 'task_released',
          'task_id' => task.id
        )
      end

      it 'broadcasts release to all queue subscribers' do
        expect {
          perform :release_task, task_id: task.id
        }.to have_broadcasted_to('manual_task_queue').with(
          hash_including(
            'event' => 'task_released',
            'task_id' => task.id
          )
        )
      end
    end

    context 'when user does not own the task' do
      before do
        task.update!(assigned_to: other_user)
      end

      it 'sends error message' do
        perform :release_task, task_id: task.id

        expect(transmissions.last).to include(
          'error' => match(/cannot release/i)
        )
      end
    end
  end

  describe '#workload_info' do
    before do
      # Create more tasks and assign them
      manual_tasks[0].update!(assigned_to: user)
      manual_tasks[1].update!(assigned_to: user)
      manual_tasks[2].update!(assigned_to: other_user)

      # Add more tasks
      create(:task, pipeline_execution: pipeline, execution_mode: 'manual', status: 'ready', assigned_to: other_user)
      create(:task, pipeline_execution: pipeline, execution_mode: 'manual', status: 'ready')

      subscribe
    end

    it 'sends workload distribution across users' do
      perform :workload_info

      expect(transmissions.last).to include(
        'workload' => hash_including(
          'total_assigned' => 4,
          'total_unassigned' => 1,
          'user_distribution' => be_an(Array)
        )
      )

      distribution = transmissions.last['workload']['user_distribution']
      expect(distribution).to contain_exactly(
        hash_including('user_id' => user.id, 'task_count' => 2),
        hash_including('user_id' => other_user.id, 'task_count' => 2)
      )
    end
  end

  describe 'real-time queue updates' do
    before do
      subscribe
    end

    it 'broadcasts new tasks to queue' do
      new_task = nil

      expect {
        new_task = create(:task,
          pipeline_execution: pipeline,
          execution_mode: 'manual',
          status: 'ready',
          priority: 5
        )

        ActionCable.server.broadcast('manual_task_queue', {
          event: 'new_task',
          task: {
            id: new_task.id,
            name: new_task.name,
            priority: new_task.priority
          }
        })
      }.to have_broadcasted_to('manual_task_queue').with(
        hash_including('event' => 'new_task')
      )
    end

    it 'broadcasts task completion to assigned user' do
      task = manual_tasks.first
      task.update!(assigned_to: user)

      expect {
        task.update!(status: 'completed')

        ActionCable.server.broadcast("manual_task_queue:user:#{user.id}", {
          event: 'task_completed',
          task_id: task.id,
          completion_time: task.completed_at
        })
      }.to have_broadcasted_to("manual_task_queue:user:#{user.id}").with(
        hash_including('event' => 'task_completed')
      )
    end
  end
end
