require 'rails_helper'

RSpec.describe 'API Endpoints Integration', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization, role: 'admin') }
  let(:api_key) { create(:api_key, organization: organization, user: user) }
  let(:headers) { { 'X-API-Key' => api_key.key, 'Content-Type' => 'application/json' } }

  before do
    # Configure Solid Queue to process jobs inline for real processing
    ActiveJob::Base.queue_adapter = :inline

    # Track API usage with real job
    allow(TrackApiUsageJob).to receive(:perform_later).and_call_original
  end

  after do
    ActiveJob::Base.queue_adapter = :test
  end

  describe 'Pipeline API endpoints' do
    let(:data_source) { create(:data_source, organization: organization) }
    let(:pipelines) { create_list(:pipeline_execution, rand(5..10),
      organization: organization,
      data_source: data_source,
      user: user,
      status: [ 'running', 'completed', 'failed', 'paused' ].sample,
      priority: rand(0..10)
    ) }

    before do
      # Create tasks for each pipeline
      pipelines.each do |pipeline|
        task_count = rand(3..6)
        task_count.times do |i|
          create(:task,
            pipeline_execution: pipeline,
            name: "Task #{i + 1} - #{[ 'Extract', 'Transform', 'Load' ].sample} #{SecureRandom.hex(3)}",
            task_type: [ 'extraction', 'transformation', 'validation', 'notification' ].sample,
            execution_mode: [ 'automated', 'manual', 'approval_required' ].sample,
            status: [ 'pending', 'ready', 'in_progress', 'completed', 'failed' ].sample,
            position: i + 1,
            priority: rand(0..10),
            started_at: [ 'completed', 'in_progress' ].include?(pipeline.status) ? rand(1..60).minutes.ago : nil,
            completed_at: pipeline.status == 'completed' ? rand(1..30).minutes.ago : nil
          )
        end
      end
    end

    describe 'GET /api/v1/pipelines' do
      it 'returns paginated pipeline list with filters' do
        # Test without filters
        get '/api/v1/pipelines', headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json['data']).to be_an(Array)
        expect(response.headers['X-Total-Count']).to eq(pipelines.count.to_s)

        # Test with status filter
        running_pipelines = pipelines.select { |p| p.status == 'running' }
        if running_pipelines.any?
          get '/api/v1/pipelines', params: { status: 'running' }, headers: headers

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)
          expect(json['data'].count).to eq(running_pipelines.count)
        end

        # Test with date range filter
        start_date = 2.days.ago.iso8601
        end_date = Time.current.iso8601

        get '/api/v1/pipelines', params: { start_date: start_date, end_date: end_date }, headers: headers
        expect(response).to have_http_status(:ok)

        # Test sorting
        get '/api/v1/pipelines', params: { sort: 'priority:desc' }, headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        priorities = json['data'].map { |p| p['priority'] }
        expect(priorities).to eq(priorities.sort.reverse)

        # Test pagination
        per_page = 2
        get '/api/v1/pipelines', params: { page: 1, per_page: per_page }, headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data'].count).to be <= per_page
        expect(response.headers['X-Per-Page']).to eq(per_page.to_s)
      end
    end

    describe 'POST /api/v1/pipelines' do
      it 'creates new pipeline execution' do
        pipeline_params = {
          pipeline: {
            pipeline_name: "API Created Pipeline #{SecureRandom.hex(4)}",
            data_source_id: data_source.id,
            execution_mode: 'manual',
            priority: rand(5..10),
            configuration: {
              batch_size: rand(100..1000),
              skip_validation: [ true, false ].sample,
              notification_emails: [ "test#{rand(1..100)}@example.com" ]
            }
          }
        }

        expect {
          post '/api/v1/pipelines', params: pipeline_params.to_json, headers: headers
        }.to change(PipelineExecution, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)

        expect(json['data']['pipeline_name']).to eq(pipeline_params[:pipeline][:pipeline_name])
        expect(json['data']['status']).to eq('queued')
        expect(json['data']['configuration']).to eq(pipeline_params[:pipeline][:configuration].stringify_keys)

        # Verify job was queued
        new_pipeline = PipelineExecution.find(json['data']['id'])
        expect(new_pipeline).to be_present
      end
    end

    describe 'Pipeline control endpoints' do
      let(:pipeline) { pipelines.find { |p| p.status == 'running' } || pipelines.first }

      it 'manages pipeline lifecycle' do
        # Ensure pipeline is running
        pipeline.update!(status: 'running')

        # Pause pipeline
        post "/api/v1/pipelines/#{pipeline.id}/pause", headers: headers

        expect(response).to have_http_status(:ok)
        pipeline.reload
        expect(pipeline.status).to eq('paused')

        # Resume pipeline
        post "/api/v1/pipelines/#{pipeline.id}/resume", headers: headers

        expect(response).to have_http_status(:ok)
        pipeline.reload
        expect(pipeline.status).to eq('running')

        # Cancel pipeline
        post "/api/v1/pipelines/#{pipeline.id}/cancel", headers: headers

        expect(response).to have_http_status(:ok)
        pipeline.reload
        expect(pipeline.status).to eq('cancelled')

        # Retry failed pipeline
        pipeline.update!(status: 'failed')

        expect {
          post "/api/v1/pipelines/#{pipeline.id}/retry", headers: headers
        }.to change(PipelineExecution, :count).by(1)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        new_pipeline = PipelineExecution.find(json['data']['id'])
        expect(new_pipeline.retry_count).to eq(1)
        expect(new_pipeline.metadata['original_pipeline_id']).to eq(pipeline.id)
      end
    end

    describe 'GET /api/v1/pipelines/:id/tasks' do
      let(:pipeline) { pipelines.sample }

      it 'returns pipeline tasks with filters' do
        # Get all tasks
        get "/api/v1/pipelines/#{pipeline.id}/tasks", headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json['data'].count).to eq(pipeline.tasks.count)

        # Filter by status
        completed_tasks = pipeline.tasks.where(status: 'completed')
        if completed_tasks.any?
          get "/api/v1/pipelines/#{pipeline.id}/tasks",
              params: { status: 'completed' },
              headers: headers

          json = JSON.parse(response.body)
          expect(json['data'].count).to eq(completed_tasks.count)
        end

        # Filter by execution mode
        manual_tasks = pipeline.tasks.where(execution_mode: 'manual')
        if manual_tasks.any?
          get "/api/v1/pipelines/#{pipeline.id}/tasks",
              params: { execution_mode: 'manual' },
              headers: headers

          json = JSON.parse(response.body)
          expect(json['data'].count).to eq(manual_tasks.count)
        end
      end
    end

    describe 'GET /api/v1/pipelines/statistics' do
      it 'returns comprehensive pipeline statistics' do
        get '/api/v1/pipelines/statistics', headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json).to include(
          'total_executions',
          'executions_by_status',
          'executions_last_24h',
          'average_duration',
          'success_rate',
          'executions_by_day'
        )

        # Verify calculations
        total = pipelines.count
        expect(json['total_executions']).to eq(total)

        # Check status breakdown
        status_counts = pipelines.group_by(&:status).transform_values(&:count)
        expect(json['executions_by_status']).to eq(status_counts)

        # Verify success rate calculation
        completed = pipelines.count { |p| p.status == 'completed' }
        failed = pipelines.count { |p| p.status == 'failed' }
        if (completed + failed) > 0
          expected_rate = (completed.to_f / (completed + failed) * 100).round(1)
          expect(json['success_rate']).to eq(expected_rate)
        end
      end
    end
  end

  describe 'Task API endpoints' do
    let(:tasks) { Task.all }

    describe 'GET /api/v1/tasks' do
      it 'returns filtered task list' do
        # Create diverse tasks
        create_list(:task, rand(5..10),
          pipeline_execution: pipelines.sample,
          execution_mode: 'manual',
          status: [ 'pending', 'ready', 'in_progress' ].sample,
          assignee: [ user, nil ].sample,
          priority: rand(0..10)
        )

        # Get all tasks
        get '/api/v1/tasks', headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']).to be_an(Array)

        # Filter by assignee
        get '/api/v1/tasks', params: { assignee_id: user.id }, headers: headers

        json = JSON.parse(response.body)
        expect(json['data'].all? { |t| t['assignee'] && t['assignee']['id'] == user.id }).to be true

        # Filter unassigned
        get '/api/v1/tasks', params: { assignee_id: 'unassigned' }, headers: headers

        json = JSON.parse(response.body)
        expect(json['data'].all? { |t| t['assignee'].nil? }).to be true

        # Filter by pipeline name
        pipeline_name = pipelines.first.pipeline_name
        get '/api/v1/tasks', params: { pipeline_name: pipeline_name }, headers: headers

        json = JSON.parse(response.body)
        expect(json['data'].all? { |t| t['pipeline']['pipeline_name'] == pipeline_name }).to be true
      end
    end

    describe 'GET /api/v1/tasks/manual_queue' do
      before do
        # Create manual tasks
        create_list(:task, rand(3..6),
          pipeline_execution: pipelines.sample,
          execution_mode: 'manual',
          status: 'ready',
          priority: rand(0..10)
        )
      end

      it 'returns manual task queue with statistics' do
        get '/api/v1/tasks/manual_queue', headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json).to include('tasks', 'statistics', 'workload_distribution')

        # Verify queue statistics
        stats = json['statistics']
        expect(stats).to include(
          'total_pending',
          'ready_for_assignment',
          'in_progress',
          'by_priority',
          'by_type'
        )

        # Check workload distribution
        if json['workload_distribution'].any?
          json['workload_distribution'].each do |workload|
            expect(workload).to include('user_id', 'user_name', 'assigned_count', 'in_progress_count')
          end
        end
      end
    end

    describe 'Task execution endpoints' do
      let(:manual_task) { create(:task,
        pipeline_execution: pipelines.first,
        execution_mode: 'manual',
        status: 'ready',
        assignee: user
      ) }

      it 'executes manual tasks' do
        post "/api/v1/tasks/#{manual_task.id}/execute", headers: headers

        expect(response).to have_http_status(:ok)
        manual_task.reload
        expect(manual_task.status).to eq('in_progress')
        expect(manual_task.started_at).to be_present
      end

      it 'handles task assignment' do
        unassigned_task = create(:task,
          pipeline_execution: pipelines.first,
          execution_mode: 'manual',
          status: 'ready',
          assignee: nil
        )

        # Assign to self
        post "/api/v1/tasks/#{unassigned_task.id}/assign", headers: headers

        expect(response).to have_http_status(:ok)
        unassigned_task.reload
        expect(unassigned_task.assignee).to eq(user)

        # Unassign
        post "/api/v1/tasks/#{unassigned_task.id}/unassign", headers: headers

        expect(response).to have_http_status(:ok)
        unassigned_task.reload
        expect(unassigned_task.assignee).to be_nil
      end

      it 'handles approval workflow' do
        approval_task = create(:task,
          pipeline_execution: pipelines.first,
          execution_mode: 'approval_required',
          status: 'waiting_approval'
        )

        # Approve task
        post "/api/v1/tasks/#{approval_task.id}/approve",
             params: { execute_after_approval: true }.to_json,
             headers: headers

        expect(response).to have_http_status(:ok)
        approval_task.reload
        expect(approval_task.status).to eq('in_progress')
        expect(approval_task.metadata['approved_by']).to eq(user.id)

        # Test rejection
        another_approval_task = create(:task,
          pipeline_execution: pipelines.first,
          execution_mode: 'approval_required',
          status: 'waiting_approval'
        )

        rejection_params = { reason: "Budget constraints require review" }
        post "/api/v1/tasks/#{another_approval_task.id}/reject",
             params: rejection_params.to_json,
             headers: headers

        expect(response).to have_http_status(:ok)
        another_approval_task.reload
        expect(another_approval_task.status).to eq('rejected')
        expect(another_approval_task.metadata['rejection_reason']).to eq(rejection_params[:reason])
      end
    end
  end

  describe 'Task Template API endpoints' do
    let(:templates) { create_list(:task_template, rand(3..5), organization: organization) }

    describe 'GET /api/v1/task_templates' do
      it 'returns filtered template list' do
        # Create templates with tags
        templates.each do |template|
          template.update!(
            tags: [ 'etl', 'validation', 'notification', 'automated' ].sample(rand(1..3)).join(', ')
          )
        end

        get '/api/v1/task_templates', headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data'].count).to eq(templates.count)

        # Filter by tags
        tag_to_search = 'validation'
        get '/api/v1/task_templates', params: { tags: tag_to_search }, headers: headers

        json = JSON.parse(response.body)
        expect(json['data'].all? { |t| t['tags'].include?(tag_to_search) }).to be true

        # Search by name
        search_term = templates.first.name.split.first
        get '/api/v1/task_templates', params: { q: search_term }, headers: headers

        json = JSON.parse(response.body)
        expect(json['data'].any? { |t| t['name'].include?(search_term) }).to be true
      end
    end

    describe 'POST /api/v1/task_templates/:id/create_task' do
      let(:template) { templates.first }
      let(:pipeline) { pipelines.first }

      it 'creates task from template' do
        task_params = {
          pipeline_execution_id: pipeline.id,
          name: "Custom Task #{SecureRandom.hex(4)}",
          timeout_seconds: rand(60..600),
          configuration: {
            batch_size: rand(100..1000),
            custom_param: 'value'
          }
        }

        expect {
          post "/api/v1/task_templates/#{template.id}/create_task",
               params: task_params.to_json,
               headers: headers
        }.to change(Task, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)

        new_task = Task.find(json['data']['id'])
        expect(new_task.task_template_id).to eq(template.id)
        expect(new_task.name).to eq(task_params[:name])
        expect(new_task.timeout_seconds).to eq(task_params[:timeout_seconds])
        expect(new_task.configuration['batch_size']).to eq(task_params[:configuration][:batch_size])
      end
    end
  end

  describe 'Scheduled Task API endpoints' do
    let(:scheduled_tasks) { create_list(:scheduled_task, rand(3..5),
      organization: organization,
      task_template: templates.sample
    ) }

    describe 'GET /api/v1/scheduled_tasks/upcoming' do
      before do
        # Create upcoming scheduled tasks
        scheduled_tasks.each_with_index do |task, index|
          task.update!(
            schedule_type: 'once',
            scheduled_at: (index + 1).days.from_now,
            active: true
          )
        end
      end

      it 'returns upcoming scheduled tasks' do
        get '/api/v1/scheduled_tasks/upcoming', headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        # Should return tasks scheduled within default period (7 days)
        expect(json['data']).to be_an(Array)
        expect(json['data'].all? { |t| Time.parse(t['next_run']) <= 7.days.from_now }).to be true

        # Test custom period
        get '/api/v1/scheduled_tasks/upcoming', params: { days: 3 }, headers: headers

        json = JSON.parse(response.body)
        expect(json['data'].all? { |t| Time.parse(t['next_run']) <= 3.days.from_now }).to be true
      end
    end

    describe 'POST /api/v1/scheduled_tasks' do
      it 'creates scheduled task with various schedule types' do
        template = templates.first

        schedule_params = {
          scheduled_task: {
            name: "API Scheduled Task #{SecureRandom.hex(4)}",
            description: "Created via API",
            task_template_id: template.id,
            schedule_type: 'weekly',
            time_of_day: '10:30',
            days_of_week: [ 'monday', 'wednesday', 'friday' ],
            start_date: 1.day.from_now.to_date.iso8601,
            end_date: 30.days.from_now.to_date.iso8601,
            configuration: {
              priority: rand(5..10),
              notify_on_completion: true
            }
          }
        }

        expect {
          post '/api/v1/scheduled_tasks',
               params: schedule_params.to_json,
               headers: headers
        }.to change(ScheduledTask, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)

        new_schedule = ScheduledTask.find(json['data']['id'])
        expect(new_schedule.schedule_type).to eq('weekly')
        expect(new_schedule.days_of_week).to eq(schedule_params[:scheduled_task][:days_of_week])
        expect(new_schedule.next_run).to be_present
      end
    end
  end

  describe 'Rate limiting and API usage tracking' do
    it 'tracks API usage and enforces rate limits' do
      # Make multiple requests
      request_count = rand(5..10)

      request_count.times do |i|
        get '/api/v1/pipelines', headers: headers
        expect(response).to have_http_status(:ok)

        # Check rate limit headers
        expect(response.headers['X-RateLimit-Limit']).to be_present
        expect(response.headers['X-RateLimit-Remaining']).to be_present
        expect(response.headers['X-RateLimit-Reset']).to be_present

        remaining = response.headers['X-RateLimit-Remaining'].to_i
        expect(remaining).to be < response.headers['X-RateLimit-Limit'].to_i
      end

      # Verify API usage was tracked
      api_key.reload
      expect(api_key.usage_count).to eq(request_count)
    end
  end

  describe 'Error handling' do
    it 'returns appropriate error responses' do
      # 404 - Not found
      get '/api/v1/pipelines/999999', headers: headers

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json['error']).to be_present
      expect(json['error']['status']).to eq(404)

      # 422 - Invalid parameters
      invalid_params = { pipeline: { pipeline_name: '' } }
      post '/api/v1/pipelines', params: invalid_params.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['error']['details']).to be_an(Array)

      # 401 - Unauthorized
      get '/api/v1/pipelines', headers: { 'X-API-Key' => 'invalid_key' }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
