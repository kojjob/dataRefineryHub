# ManualTasksController
# Handles manual task queue management and execution
class ManualTasksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_task, only: [:show, :execute, :approve, :reject]
  before_action :authorize_task_execution, only: [:execute, :approve, :reject]

  def index
    @queue_service = ManualTaskQueueService.instance
    
    # Get tasks based on filters
    @tasks = @queue_service.pending_tasks(
      assignee_id: params[:assigned_to_me] ? current_user.id : nil,
      pipeline_name: params[:pipeline_name]
    ).page(params[:page])
    
    # Get queue statistics
    @statistics = @queue_service.cached_metrics
    
    # Get priority grouped tasks for sidebar
    @tasks_by_priority = @queue_service.tasks_by_priority
    
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def show
    @task_executions = @task.task_executions.recent.limit(10)
    @pipeline_execution = @task.pipeline_execution
    @data_source = @pipeline_execution.data_source
    
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def execute
    if request.post?
      begin
        @queue_service = ManualTaskQueueService.instance
        @queue_service.execute_manual_task(@task.id, current_user, execution_params)
        
        redirect_to manual_tasks_path, notice: "Task '#{@task.name}' has been started."
      rescue => e
        redirect_to manual_task_path(@task), alert: "Failed to execute task: #{e.message}"
      end
    else
      # GET request - show execution form
      render :execute
    end
  end

  def approve
    if request.post?
      if @task.approve!(current_user)
        # Execute the task after approval
        @task.execute!(current_user)
        
        respond_to do |format|
          format.html { redirect_to manual_tasks_path, notice: "Task '#{@task.name}' has been approved and started." }
          format.turbo_stream {
            render turbo_stream: [
              turbo_stream.remove(@task),
              turbo_stream.prepend("notifications", partial: "shared/notification", 
                locals: { type: "success", message: "Task approved and started" })
            ]
          }
        end
      else
        respond_to do |format|
          format.html { redirect_to manual_task_path(@task), alert: "Failed to approve task." }
          format.turbo_stream {
            render turbo_stream: turbo_stream.prepend("notifications", partial: "shared/notification", 
              locals: { type: "error", message: "Failed to approve task" })
          }
        end
      end
    else
      # GET request - show approval form
      render :approve
    end
  end

  def reject
    if request.post?
      if @task.reject!(current_user, params[:reason])
        respond_to do |format|
          format.html { redirect_to manual_tasks_path, notice: "Task '#{@task.name}' has been rejected." }
          format.turbo_stream {
            render turbo_stream: [
              turbo_stream.remove(@task),
              turbo_stream.prepend("notifications", partial: "shared/notification", 
                locals: { type: "info", message: "Task rejected" })
            ]
          }
        end
      else
        respond_to do |format|
          format.html { redirect_to manual_task_path(@task), alert: "Failed to reject task." }
          format.turbo_stream {
            render turbo_stream: turbo_stream.prepend("notifications", partial: "shared/notification", 
              locals: { type: "error", message: "Failed to reject task" })
          }
        end
      end
    else
      # GET request - show rejection form
      render :reject
    end
  end

  # Auto-assign tasks to available users
  def auto_assign
    authorize :manual_task, :auto_assign?
    
    @queue_service = ManualTaskQueueService.instance
    assigned_count = @queue_service.auto_assign_tasks(
      max_tasks_per_user: params[:max_tasks_per_user]&.to_i || 5
    )
    
    redirect_to manual_tasks_path, notice: "Successfully auto-assigned #{assigned_count} tasks."
  end

  # Clear stale task assignments
  def clear_stale
    authorize :manual_task, :manage?
    
    @queue_service = ManualTaskQueueService.instance
    cleared_count = @queue_service.clear_stale_assignments
    
    redirect_to manual_tasks_path, notice: "Cleared #{cleared_count} stale task assignments."
  end

  private

  def set_task
    @task = Task.find(params[:id])
  end

  def authorize_task_execution
    # Users can execute tasks assigned to them
    # Admins can execute any manual task
    unless @task.assignee == current_user || current_user.admin?
      redirect_to manual_tasks_path, alert: "You are not authorized to perform this action."
    end
  end

  def execution_params
    params.permit(:notes, configuration: {})
  end
end