require 'rails_helper'

RSpec.describe PipelineChannel, type: :channel do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }
  let(:pipeline) { create(:pipeline_execution, organization: organization, user: user) }

  let!(:tasks) do
    %w[extraction transformation validation].map.with_index do |type, i|
      create(:task,
        pipeline_execution: pipeline,
        task_type: type,
        position: i + 1,
        status: 'pending'
      )
    end
  end

  before do
    stub_connection current_user: user
  end

  describe '#subscribed' do
    context 'with pipeline_id' do
      it 'subscribes to specific pipeline stream' do
        subscribe(pipeline_id: pipeline.id)

        expect(subscription).to be_confirmed
        expect(subscription).to have_stream_from("pipeline_#{pipeline.id}")
      end

      it 'rejects subscription for unauthorized pipeline' do
        other_org = create(:organization)
        other_pipeline = create(:pipeline_execution, organization: other_org)

        subscribe(pipeline_id: other_pipeline.id)
        expect(subscription).to be_rejected
      end
    end

    context 'without pipeline_id' do
      it 'subscribes to organization-wide pipeline stream' do
        subscribe

        expect(subscription).to be_confirmed
        expect(subscription).to have_stream_from("pipelines:organization:#{organization.id}")
      end
    end
  end

  describe '#refresh' do
    before do
      subscribe(pipeline_id: pipeline.id)
    end

    it 'sends current pipeline state with all tasks' do
      # Update some task states
      tasks[0].update!(status: 'completed', completed_at: Time.current)
      tasks[1].update!(status: 'running', started_at: Time.current)

      perform :refresh

      expect(transmissions.last).to include(
        'pipeline' => hash_including(
          'id' => pipeline.id,
          'status' => pipeline.status,
          'progress' => be_a(Numeric),
          'tasks' => be_an(Array)
        )
      )

      tasks_data = transmissions.last['pipeline']['tasks']
      expect(tasks_data.size).to eq(3)
      expect(tasks_data[0]['status']).to eq('completed')
      expect(tasks_data[1]['status']).to eq('running')
      expect(tasks_data[2]['status']).to eq('pending')
    end

    it 'calculates correct progress percentage' do
      tasks[0].update!(status: 'completed')
      tasks[1].update!(status: 'completed')

      perform :refresh

      # 2 out of 3 tasks completed = 67%
      expect(transmissions.last['pipeline']['progress']).to be_within(1).of(67)
    end
  end

  describe '#task_details' do
    let(:task) { tasks.first }

    before do
      subscribe(pipeline_id: pipeline.id)

      # Add some execution details to the task
      task.update!(
        status: 'running',
        started_at: 1.hour.ago,
        metadata: {
          input_records: 1000,
          processed_records: 750,
          error_records: 5,
          processing_rate: 12.5
        }
      )
    end

    it 'sends detailed task information' do
      perform :task_details, task_id: task.id

      expect(transmissions.last).to include(
        'task' => hash_including(
          'id' => task.id,
          'name' => task.name,
          'status' => 'running',
          'started_at' => be_present,
          'duration' => be_present,
          'metadata' => hash_including(
            'input_records' => 1000,
            'processed_records' => 750,
            'error_records' => 5
          )
        )
      )
    end

    it 'handles non-existent tasks' do
      perform :task_details, task_id: 'non-existent'

      expect(transmissions.last).to include(
        'error' => match(/task not found/i)
      )
    end

    it 'prevents access to tasks from other pipelines' do
      other_pipeline = create(:pipeline_execution, organization: organization)
      other_task = create(:task, pipeline_execution: other_pipeline)

      perform :task_details, task_id: other_task.id

      expect(transmissions.last).to include(
        'error' => match(/not found|unauthorized/i)
      )
    end
  end

  describe 'organization-wide pipeline monitoring' do
    let!(:other_pipelines) do
      2.times.map do
        create(:pipeline_execution, organization: organization)
      end
    end

    before do
      subscribe  # No pipeline_id = organization-wide
    end

    it 'receives updates for all organization pipelines' do
      # Update one of the other pipelines
      other_pipeline = other_pipelines.first

      expect {
        ActionCable.server.broadcast("pipelines:organization:#{organization.id}", {
          event: 'pipeline_started',
          pipeline_id: other_pipeline.id,
          pipeline_name: other_pipeline.pipeline_name
        })
      }.to have_broadcasted_to("pipelines:organization:#{organization.id}").with(
        hash_including('event' => 'pipeline_started')
      )
    end
  end

  describe 'real-time pipeline updates' do
    before do
      subscribe(pipeline_id: pipeline.id)
    end

    it 'broadcasts task state changes' do
      task = tasks.first

      expect {
        task.update!(status: 'running', started_at: Time.current)

        ActionCable.server.broadcast("pipeline_#{pipeline.id}", {
          event: 'task_started',
          task_id: task.id,
          task_name: task.name,
          started_at: task.started_at
        })
      }.to have_broadcasted_to("pipeline_#{pipeline.id}").with(
        hash_including(
          'event' => 'task_started',
          'task_id' => task.id
        )
      )
    end

    it 'broadcasts pipeline completion' do
      # Complete all tasks
      tasks.each { |t| t.update!(status: 'completed', completed_at: Time.current) }
      pipeline.update!(status: 'completed', completed_at: Time.current)

      expect {
        ActionCable.server.broadcast("pipeline_#{pipeline.id}", {
          event: 'pipeline_completed',
          pipeline_id: pipeline.id,
          duration: pipeline.duration_seconds,
          total_records_processed: 10000
        })
      }.to have_broadcasted_to("pipeline_#{pipeline.id}").with(
        hash_including(
          'event' => 'pipeline_completed',
          'total_records_processed' => 10000
        )
      )
    end

    it 'broadcasts pipeline failure' do
      failing_task = tasks[1]
      error_details = {
        message: 'Data validation failed',
        code: 'VALIDATION_ERROR',
        details: 'Missing required fields'
      }

      expect {
        failing_task.update!(
          status: 'failed',
          error_message: error_details[:message],
          metadata: { error: error_details }
        )
        pipeline.update!(status: 'failed')

        ActionCable.server.broadcast("pipeline_#{pipeline.id}", {
          event: 'pipeline_failed',
          pipeline_id: pipeline.id,
          failed_task_id: failing_task.id,
          error: error_details
        })
      }.to have_broadcasted_to("pipeline_#{pipeline.id}").with(
        hash_including(
          'event' => 'pipeline_failed',
          'error' => hash_including('message' => 'Data validation failed')
        )
      )
    end
  end
end
