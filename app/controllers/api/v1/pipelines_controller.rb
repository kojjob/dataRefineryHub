# API::V1::PipelinesController
# API endpoints for pipeline executions
class Api::V1::PipelinesController < Api::V1::BaseController
  before_action :set_pipeline, only: [ :show, :pause, :resume, :cancel, :retry, :tasks, :logs ]

  # GET /api/v1/pipelines
  # List all pipeline executions with filtering and pagination
  def index
    pipelines = current_organization.pipeline_executions
                                   .includes(:data_source, :user)

    # Apply filters
    pipelines = filter_by_status(pipelines)
    pipelines = filter_by_date_range(pipelines, :started_at)
    pipelines = filter_by_data_source(pipelines)
    pipelines = filter_by_execution_mode(pipelines)

    # Apply sorting
    pipelines = apply_sorting(pipelines, %w[started_at completed_at status pipeline_name])

    # Paginate
    pipelines = paginate(pipelines)
    pagination_headers(pipelines)

    render json: pipelines, each_serializer: Api::V1::PipelineSerializer
  end

  # GET /api/v1/pipelines/:id
  # Get detailed information about a specific pipeline
  def show
    render json: @pipeline, serializer: Api::V1::PipelineDetailSerializer
  end

  # POST /api/v1/pipelines
  # Create and start a new pipeline execution
  def create
    pipeline = current_organization.pipeline_executions.build(pipeline_params)
    pipeline.user = current_user
    pipeline.status = "queued"

    if pipeline.save
      # Start the pipeline execution
      PipelineExecutorJob.perform_later(pipeline)

      render json: pipeline, serializer: Api::V1::PipelineSerializer, status: :created
    else
      render_error("Failed to create pipeline", :unprocessable_entity, pipeline.errors.full_messages)
    end
  end

  # POST /api/v1/pipelines/:id/pause
  # Pause a running pipeline
  def pause
    authorize @pipeline, :manage?

    if @pipeline.can_pause?
      @pipeline.pause!
      render json: { message: "Pipeline paused successfully", pipeline: Api::V1::PipelineSerializer.new(@pipeline) }
    else
      render_error("Pipeline cannot be paused in current state", :unprocessable_entity)
    end
  end

  # POST /api/v1/pipelines/:id/resume
  # Resume a paused pipeline
  def resume
    authorize @pipeline, :manage?

    if @pipeline.can_resume?
      @pipeline.resume!
      render json: { message: "Pipeline resumed successfully", pipeline: Api::V1::PipelineSerializer.new(@pipeline) }
    else
      render_error("Pipeline cannot be resumed in current state", :unprocessable_entity)
    end
  end

  # POST /api/v1/pipelines/:id/cancel
  # Cancel a pipeline execution
  def cancel
    authorize @pipeline, :manage?

    if @pipeline.can_cancel?
      @pipeline.cancel!
      render json: { message: "Pipeline cancelled successfully", pipeline: Api::V1::PipelineSerializer.new(@pipeline) }
    else
      render_error("Pipeline cannot be cancelled in current state", :unprocessable_entity)
    end
  end

  # POST /api/v1/pipelines/:id/retry
  # Retry a failed pipeline
  def retry
    authorize @pipeline, :manage?

    if @pipeline.can_retry?
      new_pipeline = @pipeline.retry!
      PipelineExecutorJob.perform_later(new_pipeline)

      render json: {
        message: "Pipeline retry initiated successfully",
        original_pipeline_id: @pipeline.id,
        new_pipeline: Api::V1::PipelineSerializer.new(new_pipeline)
      }, status: :created
    else
      render_error("Pipeline cannot be retried in current state", :unprocessable_entity)
    end
  end

  # GET /api/v1/pipelines/:id/tasks
  # Get all tasks for a pipeline
  def tasks
    tasks = @pipeline.tasks.includes(:assignee, :task_executions)

    # Apply task filters
    tasks = filter_by_status(tasks) if params[:status].present?
    tasks = filter_by_task_type(tasks) if params[:task_type].present?
    tasks = filter_by_execution_mode(tasks) if params[:execution_mode].present?

    # Apply sorting
    tasks = apply_sorting(tasks, %w[position status created_at priority])

    render json: tasks, each_serializer: Api::V1::TaskSerializer
  end

  # GET /api/v1/pipelines/:id/logs
  # Get execution logs for a pipeline
  def logs
    logs = @pipeline.execution_logs

    # Filter by log level
    if params[:level].present?
      levels = params[:level].split(",").map(&:strip)
      logs = logs.where(level: levels)
    end

    # Filter by time range
    logs = filter_by_date_range(logs, :created_at)

    # Paginate
    logs = paginate(logs.order(created_at: :desc))
    pagination_headers(logs)

    render json: logs, each_serializer: Api::V1::ExecutionLogSerializer
  end

  # GET /api/v1/pipelines/statistics
  # Get pipeline execution statistics
  def statistics
    stats = {
      total_executions: current_organization.pipeline_executions.count,
      executions_by_status: current_organization.pipeline_executions.group(:status).count,
      executions_last_24h: current_organization.pipeline_executions.where("created_at >= ?", 24.hours.ago).count,
      average_duration: calculate_average_duration,
      success_rate: calculate_success_rate,
      executions_by_day: executions_by_day(30),
      top_failing_pipelines: top_failing_pipelines(5)
    }

    render json: stats
  end

  private

  def set_pipeline
    @pipeline = current_organization.pipeline_executions.find(params[:id])
  end

  def pipeline_params
    params.require(:pipeline).permit(
      :pipeline_name,
      :data_source_id,
      :execution_mode,
      :priority,
      :scheduled_at,
      configuration: {},
      metadata: {}
    )
  end

  def filter_by_data_source(scope)
    if params[:data_source_id].present?
      scope = scope.where(data_source_id: params[:data_source_id])
    end
    scope
  end

  def filter_by_execution_mode(scope)
    if params[:execution_mode].present?
      modes = params[:execution_mode].split(",").map(&:strip)
      scope = scope.where(execution_mode: modes)
    end
    scope
  end

  def filter_by_task_type(scope)
    if params[:task_type].present?
      types = params[:task_type].split(",").map(&:strip)
      scope = scope.where(task_type: types)
    end
    scope
  end

  def calculate_average_duration
    completed = current_organization.pipeline_executions.completed
    return 0 if completed.empty?

    total_duration = completed.sum { |p| p.duration_seconds || 0 }
    (total_duration / completed.count.to_f).round(2)
  end

  def calculate_success_rate
    total = current_organization.pipeline_executions.where("created_at >= ?", 30.days.ago).count
    return 0 if total == 0

    successful = current_organization.pipeline_executions.where("created_at >= ?", 30.days.ago).completed.count
    ((successful.to_f / total) * 100).round(2)
  end

  def executions_by_day(days)
    current_organization.pipeline_executions
                       .where("created_at >= ?", days.days.ago)
                       .group("DATE(created_at)")
                       .group(:status)
                       .count
                       .transform_keys { |k| { date: k[0].to_s, status: k[1] } }
  end

  def top_failing_pipelines(limit)
    current_organization.pipeline_executions
                       .where(status: "failed")
                       .where("created_at >= ?", 7.days.ago)
                       .group(:pipeline_name)
                       .count
                       .sort_by { |_, count| -count }
                       .first(limit)
                       .map { |name, count| { pipeline_name: name, failure_count: count } }
  end
end
