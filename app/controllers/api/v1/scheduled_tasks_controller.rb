# API::V1::ScheduledTasksController
# API endpoints for scheduled task management
class Api::V1::ScheduledTasksController < Api::V1::BaseController
  before_action :set_scheduled_task, only: [ :show, :update, :destroy, :pause, :resume, :execute_now, :runs ]

  # GET /api/v1/scheduled_tasks
  # List all scheduled tasks
  def index
    scheduled_tasks = current_organization.scheduled_tasks
                                        .includes(:task_template, :created_by)

    # Apply filters
    scheduled_tasks = scheduled_tasks.active if params[:active] == "true"
    scheduled_tasks = scheduled_tasks.by_schedule_type(params[:schedule_type]) if params[:schedule_type].present?
    scheduled_tasks = filter_by_status(scheduled_tasks)
    scheduled_tasks = filter_by_date_range(scheduled_tasks, :next_run_at) if params[:next_run_from].present?

    # Apply sorting
    scheduled_tasks = apply_sorting(scheduled_tasks, %w[name next_run_at created_at run_count])

    # Paginate
    scheduled_tasks = paginate(scheduled_tasks)
    pagination_headers(scheduled_tasks)

    render json: scheduled_tasks, each_serializer: Api::V1::ScheduledTaskSerializer
  end

  # GET /api/v1/scheduled_tasks/upcoming
  # Get upcoming scheduled tasks
  def upcoming
    days_ahead = (params[:days] || 7).to_i

    scheduled_tasks = current_organization.scheduled_tasks
                                        .active
                                        .where("next_run_at <= ?", days_ahead.days.from_now)
                                        .order(next_run_at: :asc)

    # Group by day
    grouped = scheduled_tasks.group_by { |task| task.next_run_at.to_date }

    render json: {
      upcoming_days: days_ahead,
      total_tasks: scheduled_tasks.count,
      schedule: grouped.transform_values { |tasks|
        tasks.map { |t| Api::V1::ScheduledTaskSerializer.new(t) }
      }
    }
  end

  # GET /api/v1/scheduled_tasks/:id
  # Get detailed information about a scheduled task
  def show
    render json: @scheduled_task, serializer: Api::V1::ScheduledTaskDetailSerializer
  end

  # POST /api/v1/scheduled_tasks
  # Create a new scheduled task
  def create
    scheduled_task = current_organization.scheduled_tasks.build(scheduled_task_params)
    scheduled_task.created_by = current_user

    if scheduled_task.save
      render json: scheduled_task, serializer: Api::V1::ScheduledTaskSerializer, status: :created
    else
      render_error("Failed to create scheduled task", :unprocessable_entity, scheduled_task.errors.full_messages)
    end
  end

  # PATCH/PUT /api/v1/scheduled_tasks/:id
  # Update a scheduled task
  def update
    if @scheduled_task.update(scheduled_task_params)
      render json: @scheduled_task, serializer: Api::V1::ScheduledTaskSerializer
    else
      render_error("Failed to update scheduled task", :unprocessable_entity, @scheduled_task.errors.full_messages)
    end
  end

  # DELETE /api/v1/scheduled_tasks/:id
  # Delete a scheduled task
  def destroy
    @scheduled_task.destroy
    head :no_content
  end

  # POST /api/v1/scheduled_tasks/:id/pause
  # Pause a scheduled task
  def pause
    if @scheduled_task.active?
      @scheduled_task.pause!
      render json: {
        message: "Scheduled task paused successfully",
        scheduled_task: Api::V1::ScheduledTaskSerializer.new(@scheduled_task)
      }
    else
      render_error("Scheduled task is not active", :unprocessable_entity)
    end
  end

  # POST /api/v1/scheduled_tasks/:id/resume
  # Resume a paused scheduled task
  def resume
    if @scheduled_task.paused?
      @scheduled_task.resume!
      render json: {
        message: "Scheduled task resumed successfully",
        scheduled_task: Api::V1::ScheduledTaskSerializer.new(@scheduled_task)
      }
    else
      render_error("Scheduled task is not paused", :unprocessable_entity)
    end
  end

  # POST /api/v1/scheduled_tasks/:id/execute_now
  # Execute a scheduled task immediately
  def execute_now
    unless @scheduled_task.active?
      render_error("Only active scheduled tasks can be executed", :unprocessable_entity)
      return
    end

    begin
      run = @scheduled_task.execute!
      render json: {
        message: "Scheduled task execution started",
        run: Api::V1::ScheduledTaskRunSerializer.new(run),
        pipeline_execution_id: run.pipeline_execution_id
      }, status: :created
    rescue => e
      render_error("Failed to execute scheduled task", :unprocessable_entity, e.message)
    end
  end

  # GET /api/v1/scheduled_tasks/:id/runs
  # Get execution history for a scheduled task
  def runs
    runs = @scheduled_task.scheduled_task_runs
                         .includes(:pipeline_execution, :task)
                         .order(started_at: :desc)

    # Apply filters
    runs = filter_by_status(runs) if params[:status].present?
    runs = filter_by_date_range(runs, :started_at)

    # Paginate
    runs = paginate(runs)
    pagination_headers(runs)

    render json: runs, each_serializer: Api::V1::ScheduledTaskRunSerializer
  end

  # GET /api/v1/scheduled_tasks/statistics
  # Get scheduled task statistics
  def statistics
    stats = {
      total_scheduled_tasks: current_organization.scheduled_tasks.count,
      active_scheduled_tasks: current_organization.scheduled_tasks.active.count,
      tasks_by_schedule_type: current_organization.scheduled_tasks.group(:schedule_type).count,
      tasks_by_status: current_organization.scheduled_tasks.group(:status).count,
      executions_today: executions_today,
      executions_this_week: executions_this_week,
      upcoming_executions_24h: upcoming_executions_24h,
      most_frequent_tasks: most_frequent_tasks(5),
      failure_rate_by_task: failure_rate_by_task(10)
    }

    render json: stats
  end

  private

  def set_scheduled_task
    @scheduled_task = current_organization.scheduled_tasks.find(params[:id])
  end

  def scheduled_task_params
    params.require(:scheduled_task).permit(
      :name,
      :description,
      :task_template_id,
      :schedule_type,
      :scheduled_at,
      :time_of_day,
      :day_of_month,
      :cron_expression,
      :start_date,
      :end_date,
      :max_runs,
      days_of_week: [],
      configuration: {},
      task_overrides: {}
    )
  end

  def executions_today
    ScheduledTaskRun.joins(:scheduled_task)
                   .where(scheduled_tasks: { organization_id: current_organization.id })
                   .where("started_at >= ?", Date.current.beginning_of_day)
                   .count
  end

  def executions_this_week
    ScheduledTaskRun.joins(:scheduled_task)
                   .where(scheduled_tasks: { organization_id: current_organization.id })
                   .where("started_at >= ?", Date.current.beginning_of_week)
                   .count
  end

  def upcoming_executions_24h
    current_organization.scheduled_tasks
                       .active
                       .where("next_run_at <= ?", 24.hours.from_now)
                       .count
  end

  def most_frequent_tasks(limit)
    current_organization.scheduled_tasks
                       .active
                       .select("scheduled_tasks.*, run_count")
                       .order(run_count: :desc)
                       .limit(limit)
                       .map { |task|
                         {
                           id: task.id,
                           name: task.name,
                           schedule_type: task.schedule_type,
                           run_count: task.run_count,
                           next_run_at: task.next_run_at
                         }
                       }
  end

  def failure_rate_by_task(limit)
    runs = ScheduledTaskRun.joins(:scheduled_task)
                          .where(scheduled_tasks: { organization_id: current_organization.id })
                          .where("scheduled_task_runs.created_at >= ?", 30.days.ago)
                          .group(:scheduled_task_id)
                          .group(:status)
                          .count

    # Calculate failure rates
    failure_rates = {}
    runs.each do |(task_id, status), count|
      failure_rates[task_id] ||= { total: 0, failed: 0 }
      failure_rates[task_id][:total] += count
      failure_rates[task_id][:failed] += count if status == "failed"
    end

    # Sort by failure rate and get top N
    failure_rates.map do |task_id, counts|
      task = ScheduledTask.find_by(id: task_id)
      next unless task

      {
        scheduled_task_id: task_id,
        name: task&.name,
        total_runs: counts[:total],
        failed_runs: counts[:failed],
        failure_rate: (counts[:failed].to_f / counts[:total] * 100).round(2)
      }
    end.compact.sort_by { |r| -r[:failure_rate] }.first(limit)
  end
end
