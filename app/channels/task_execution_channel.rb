# TaskExecutionChannel
# Provides real-time updates for individual task executions
class TaskExecutionChannel < ApplicationCable::Channel
  def subscribed
    if params[:task_id].present?
      task = Task.find(params[:task_id])

      # Verify user has access to this task
      if can_access_task?(task)
        stream_from "task_#{params[:task_id]}"

        # Send initial task state
        transmit({
          type: "initial_state",
          task: detailed_task_summary(task)
        })
      else
        reject
      end
    else
      reject
    end
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  # Client can request task refresh
  def refresh
    task = Task.find(params[:task_id])

    if can_access_task?(task)
      transmit({
        type: "refresh",
        task: detailed_task_summary(task)
      })
    end
  end

  # Client can execute the task (if manual)
  def execute_task(data)
    task = Task.find(params[:task_id])

    if can_execute_task?(task)
      begin
        task.execute!(current_user)
        transmit({
          type: "execution_started",
          task_id: task.id,
          success: true
        })
      rescue => e
        transmit({
          type: "execution_failed",
          task_id: task.id,
          error: e.message,
          success: false
        })
      end
    else
      transmit({
        type: "execution_denied",
        task_id: task.id,
        error: "You are not authorized to execute this task",
        success: false
      })
    end
  end

  # Client can approve the task (if approval required)
  def approve_task(data)
    task = Task.find(params[:task_id])

    if can_approve_task?(task)
      begin
        task.approve!(current_user)
        transmit({
          type: "task_approved",
          task_id: task.id,
          success: true
        })
      rescue => e
        transmit({
          type: "approval_failed",
          task_id: task.id,
          error: e.message,
          success: false
        })
      end
    else
      transmit({
        type: "approval_denied",
        task_id: task.id,
        error: "You are not authorized to approve this task",
        success: false
      })
    end
  end

  # Client can reject the task (if approval required)
  def reject_task(data)
    task = Task.find(params[:task_id])
    reason = data["reason"]

    if can_approve_task?(task)
      begin
        task.reject!(current_user, reason)
        transmit({
          type: "task_rejected",
          task_id: task.id,
          success: true
        })
      rescue => e
        transmit({
          type: "rejection_failed",
          task_id: task.id,
          error: e.message,
          success: false
        })
      end
    else
      transmit({
        type: "rejection_denied",
        task_id: task.id,
        error: "You are not authorized to reject this task",
        success: false
      })
    end
  end

  private

  def can_access_task?(task)
    task.pipeline_execution.organization_id == current_user.organization_id
  end

  def can_execute_task?(task)
    can_access_task?(task) &&
    (task.assignee == current_user || current_user.admin?) &&
    task.can_execute?
  end

  def can_approve_task?(task)
    can_access_task?(task) &&
    (task.assignee == current_user || current_user.admin?) &&
    task.status == "waiting_approval"
  end

  def detailed_task_summary(task)
    {
      id: task.id,
      name: task.name,
      description: task.description,
      task_type: task.task_type,
      execution_mode: task.execution_mode,
      status: task.status,
      priority: task.priority,
      configuration: task.configuration,
      metadata: task.metadata,
      error_message: task.error_message,
      started_at: task.started_at,
      completed_at: task.completed_at,
      duration_seconds: task.duration_seconds,
      retry_count: task.retry_count,
      max_retries: task.max_retries,
      assignee: task.assignee ? {
        id: task.assignee.id,
        name: task.assignee.name,
        email: task.assignee.email
      } : nil,
      pipeline: {
        id: task.pipeline_execution.id,
        name: task.pipeline_execution.pipeline_name,
        status: task.pipeline_execution.status
      },
      task_executions: task.task_executions.recent.limit(5).map do |execution|
        {
          id: execution.id,
          status: execution.status,
          started_at: execution.started_at,
          completed_at: execution.completed_at,
          duration_seconds: execution.duration_seconds,
          output: execution.output,
          error_message: execution.error_message
        }
      end
    }
  end
end
