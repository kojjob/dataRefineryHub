# ManualTaskQueueChannel
# Provides real-time updates for the manual task queue
class ManualTaskQueueChannel < ApplicationCable::Channel
  def subscribed
    # Subscribe to general manual task queue updates
    stream_from "manual_task_queue"
    
    # Subscribe to user-specific task updates
    stream_from "user_#{current_user.id}_tasks"
    
    # Send initial queue state
    queue_service = ManualTaskQueueService.instance
    transmit({
      type: 'initial_queue_state',
      statistics: queue_service.queue_statistics,
      assigned_tasks: user_assigned_tasks
    })
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
  
  # Client requests queue refresh
  def refresh_queue
    queue_service = ManualTaskQueueService.instance
    transmit({
      type: 'queue_refresh',
      statistics: queue_service.queue_statistics,
      assigned_tasks: user_assigned_tasks,
      timestamp: Time.current
    })
  end
  
  # Client requests to claim a task
  def claim_task(data)
    task_id = data['task_id']
    queue_service = ManualTaskQueueService.instance
    
    begin
      task = queue_service.assign_task(task_id, current_user)
      transmit({
        type: 'task_claimed',
        task: task_summary(task),
        success: true
      })
    rescue => e
      transmit({
        type: 'task_claim_failed',
        task_id: task_id,
        error: e.message,
        success: false
      })
    end
  end
  
  # Client requests to release a task
  def release_task(data)
    task_id = data['task_id']
    queue_service = ManualTaskQueueService.instance
    
    begin
      task = queue_service.unassign_task(task_id)
      transmit({
        type: 'task_released',
        task_id: task_id,
        success: true
      })
    rescue => e
      transmit({
        type: 'task_release_failed',
        task_id: task_id,
        error: e.message,
        success: false
      })
    end
  end
  
  # Client requests workload information
  def workload_info
    queue_service = ManualTaskQueueService.instance
    workload = queue_service.workload_by_user
    
    transmit({
      type: 'workload_info',
      workload: workload.map { |u| 
        {
          user_id: u.id,
          name: u.name,
          task_count: u.task_count,
          is_current_user: u.id == current_user.id
        }
      }
    })
  end
  
  private
  
  def user_assigned_tasks
    current_user.assigned_tasks
                .where(status: ['ready', 'waiting_approval'], execution_mode: 'manual')
                .includes(:pipeline_execution)
                .map { |t| task_summary(t) }
  end
  
  def task_summary(task)
    {
      id: task.id,
      name: task.name,
      description: task.description,
      priority: task.priority,
      status: task.status,
      execution_mode: task.execution_mode,
      pipeline_id: task.pipeline_execution_id,
      pipeline_name: task.pipeline_execution.pipeline_name,
      created_at: task.created_at,
      assigned_at: task.metadata&.dig('assigned_at')
    }
  end
end