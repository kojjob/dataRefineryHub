# API::V1::TasksController
# API endpoints for task management
class Api::V1::TasksController < Api::V1::BaseController
  before_action :set_task, only: [ :show, :execute, :approve, :reject, :assign, :unassign, :cancel, :retry ]

  # GET /api/v1/tasks
  # List all tasks with filtering and pagination
  def index
    tasks = Task.joins(:pipeline_execution)
                .where(pipeline_executions: { organization_id: current_organization.id })
                .includes(:pipeline_execution, :assignee, :task_template)

    # Apply filters
    tasks = filter_by_status(tasks)
    tasks = filter_by_date_range(tasks)
    tasks = filter_by_task_type(tasks)
    tasks = filter_by_execution_mode(tasks)
    tasks = filter_by_assignee(tasks)
    tasks = filter_by_pipeline(tasks)

    # Apply sorting
    tasks = apply_sorting(tasks, %w[created_at priority status name position])

    # Paginate
    tasks = paginate(tasks)
    pagination_headers(tasks)

    render json: tasks, each_serializer: Api::V1::TaskSerializer
  end

  # GET /api/v1/tasks/:id
  # Get detailed information about a specific task
  def show
    render json: @task, serializer: Api::V1::TaskDetailSerializer
  end

  # GET /api/v1/tasks/manual_queue
  # Get manual tasks waiting in queue
  def manual_queue
    queue_service = ManualTaskQueueService.instance

    tasks = queue_service.pending_tasks(
      assignee_id: params[:assigned_to_me] == "true" ? current_user.id : nil,
      pipeline_name: params[:pipeline_name]
    )

    # Paginate
    tasks = paginate(tasks)
    pagination_headers(tasks)

    # Include queue statistics
    stats = queue_service.cached_metrics

    render json: {
      tasks: ActiveModelSerializers::SerializableResource.new(
        tasks,
        each_serializer: Api::V1::TaskSerializer
      ),
      statistics: stats[:statistics],
      workload: stats[:workload]
    }
  end

  # POST /api/v1/tasks/:id/execute
  # Execute a manual task
  def execute
    authorize @task, :execute?

    if @task.execution_mode != "manual"
      render_error("Task is not a manual task", :unprocessable_entity)
      return
    end

    if @task.can_execute?
      @task.assignee = current_user if @task.assignee.nil?
      @task.execute!(current_user)

      render json: {
        message: "Task execution started",
        task: Api::V1::TaskSerializer.new(@task)
      }
    else
      render_error("Task cannot be executed in current state", :unprocessable_entity)
    end
  end

  # POST /api/v1/tasks/:id/approve
  # Approve a task requiring approval
  def approve
    authorize @task, :approve?

    if @task.status != "waiting_approval"
      render_error("Task is not waiting for approval", :unprocessable_entity)
      return
    end

    if @task.approve!(current_user)
      # Execute the task after approval if configured
      if params[:execute_after_approval] == "true"
        @task.execute!(current_user)
      end

      render json: {
        message: "Task approved successfully",
        task: Api::V1::TaskSerializer.new(@task)
      }
    else
      render_error("Failed to approve task", :unprocessable_entity)
    end
  end

  # POST /api/v1/tasks/:id/reject
  # Reject a task requiring approval
  def reject
    authorize @task, :approve?

    if @task.status != "waiting_approval"
      render_error("Task is not waiting for approval", :unprocessable_entity)
      return
    end

    reason = params[:reason] || "Rejected via API"

    if @task.reject!(current_user, reason)
      render json: {
        message: "Task rejected successfully",
        task: Api::V1::TaskSerializer.new(@task)
      }
    else
      render_error("Failed to reject task", :unprocessable_entity)
    end
  end

  # POST /api/v1/tasks/:id/assign
  # Assign a task to a user
  def assign
    authorize @task, :manage?

    assignee = if params[:user_id].present?
      current_organization.users.find(params[:user_id])
    else
      current_user
    end

    queue_service = ManualTaskQueueService.instance

    begin
      task = queue_service.assign_task(@task.id, assignee)
      render json: {
        message: "Task assigned successfully",
        task: Api::V1::TaskSerializer.new(task)
      }
    rescue => e
      render_error(e.message, :unprocessable_entity)
    end
  end

  # POST /api/v1/tasks/:id/unassign
  # Unassign a task
  def unassign
    authorize @task, :manage?

    queue_service = ManualTaskQueueService.instance

    begin
      task = queue_service.unassign_task(@task.id)
      render json: {
        message: "Task unassigned successfully",
        task: Api::V1::TaskSerializer.new(task)
      }
    rescue => e
      render_error(e.message, :unprocessable_entity)
    end
  end

  # POST /api/v1/tasks/:id/cancel
  # Cancel a task
  def cancel
    authorize @task, :manage?

    if @task.can_cancel?
      @task.cancel!
      render json: {
        message: "Task cancelled successfully",
        task: Api::V1::TaskSerializer.new(@task)
      }
    else
      render_error("Task cannot be cancelled in current state", :unprocessable_entity)
    end
  end

  # POST /api/v1/tasks/:id/retry
  # Retry a failed task
  def retry
    authorize @task, :manage?

    if @task.failed?
      @task.status = "ready"
      @task.error_message = nil
      @task.save!

      # Re-execute if it's an automated task
      if @task.execution_mode == "automated"
        @task.execute!
      end

      render json: {
        message: "Task retry initiated",
        task: Api::V1::TaskSerializer.new(@task)
      }
    else
      render_error("Only failed tasks can be retried", :unprocessable_entity)
    end
  end

  # GET /api/v1/tasks/statistics
  # Get task execution statistics
  def statistics
    stats = {
      total_tasks: count_tasks,
      tasks_by_status: count_by_status,
      tasks_by_type: count_by_type,
      tasks_by_execution_mode: count_by_execution_mode,
      manual_queue_depth: manual_queue_depth,
      average_execution_time: average_execution_time,
      tasks_last_24h: tasks_last_24h,
      top_failing_tasks: top_failing_tasks(10)
    }

    render json: stats
  end

  private

  def set_task
    @task = Task.joins(:pipeline_execution)
                .where(pipeline_executions: { organization_id: current_organization.id })
                .find(params[:id])
  end

  def filter_by_task_type(scope)
    if params[:task_type].present?
      types = params[:task_type].split(",").map(&:strip)
      scope = scope.where(task_type: types)
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

  def filter_by_assignee(scope)
    if params[:assignee_id].present?
      if params[:assignee_id] == "unassigned"
        scope = scope.where(assignee_id: nil)
      else
        scope = scope.where(assignee_id: params[:assignee_id])
      end
    end
    scope
  end

  def filter_by_pipeline(scope)
    if params[:pipeline_id].present?
      scope = scope.where(pipeline_execution_id: params[:pipeline_id])
    elsif params[:pipeline_name].present?
      scope = scope.joins(:pipeline_execution)
                   .where(pipeline_executions: { pipeline_name: params[:pipeline_name] })
    end
    scope
  end

  def count_tasks
    Task.joins(:pipeline_execution)
        .where(pipeline_executions: { organization_id: current_organization.id })
        .count
  end

  def count_by_status
    Task.joins(:pipeline_execution)
        .where(pipeline_executions: { organization_id: current_organization.id })
        .group(:status)
        .count
  end

  def count_by_type
    Task.joins(:pipeline_execution)
        .where(pipeline_executions: { organization_id: current_organization.id })
        .group(:task_type)
        .count
  end

  def count_by_execution_mode
    Task.joins(:pipeline_execution)
        .where(pipeline_executions: { organization_id: current_organization.id })
        .group(:execution_mode)
        .count
  end

  def manual_queue_depth
    ManualTaskQueueService.instance.queue_statistics[:total_pending]
  end

  def average_execution_time
    completed_tasks = Task.joins(:pipeline_execution)
                         .where(pipeline_executions: { organization_id: current_organization.id })
                         .completed
                         .where.not(duration_seconds: nil)

    return 0 if completed_tasks.empty?

    (completed_tasks.average(:duration_seconds) || 0).round(2)
  end

  def tasks_last_24h
    Task.joins(:pipeline_execution)
        .where(pipeline_executions: { organization_id: current_organization.id })
        .where("tasks.created_at >= ?", 24.hours.ago)
        .group(:status)
        .count
  end

  def top_failing_tasks(limit)
    Task.joins(:pipeline_execution)
        .where(pipeline_executions: { organization_id: current_organization.id })
        .where(status: "failed")
        .where("tasks.created_at >= ?", 7.days.ago)
        .group(:name, :task_type)
        .count
        .sort_by { |_, count| -count }
        .first(limit)
        .map { |(name, type), count| { name: name, task_type: type, failure_count: count } }
  end
end
