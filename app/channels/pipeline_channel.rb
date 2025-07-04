# PipelineChannel
# Provides real-time updates for pipeline executions
class PipelineChannel < ApplicationCable::Channel
  def subscribed
    if params[:pipeline_id].present?
      # Subscribe to specific pipeline
      pipeline = PipelineExecution.find(params[:pipeline_id])
      
      # Verify user has access to this pipeline
      if can_access_pipeline?(pipeline)
        stream_from "pipeline_#{params[:pipeline_id]}"
        
        # Send initial pipeline state
        transmit({
          type: 'initial_state',
          pipeline: pipeline_summary(pipeline),
          tasks: pipeline.tasks.map { |t| task_summary(t) }
        })
      else
        reject
      end
    elsif params[:organization_id].present?
      # Subscribe to all pipelines for an organization
      if current_user.organization_id == params[:organization_id].to_i
        stream_from "organization_#{params[:organization_id]}_pipelines"
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
  
  # Client can request pipeline refresh
  def refresh
    if params[:pipeline_id].present?
      pipeline = PipelineExecution.find(params[:pipeline_id])
      
      if can_access_pipeline?(pipeline)
        transmit({
          type: 'refresh',
          pipeline: pipeline_summary(pipeline),
          tasks: pipeline.tasks.map { |t| task_summary(t) }
        })
      end
    end
  end
  
  # Client can request task details
  def task_details(data)
    task = Task.find(data['task_id'])
    
    if can_access_task?(task)
      transmit({
        type: 'task_details',
        task: detailed_task_summary(task)
      })
    end
  end
  
  private
  
  def can_access_pipeline?(pipeline)
    pipeline.organization_id == current_user.organization_id
  end
  
  def can_access_task?(task)
    task.pipeline_execution.organization_id == current_user.organization_id
  end
  
  def pipeline_summary(pipeline)
    {
      id: pipeline.id,
      pipeline_name: pipeline.pipeline_name,
      status: pipeline.status,
      progress_percentage: pipeline.progress_percentage,
      started_at: pipeline.started_at,
      completed_at: pipeline.completed_at,
      total_tasks: pipeline.total_tasks,
      completed_tasks: pipeline.completed_tasks,
      failed_tasks: pipeline.failed_tasks,
      duration_seconds: pipeline.duration_seconds
    }
  end
  
  def task_summary(task)
    {
      id: task.id,
      name: task.name,
      status: task.status,
      execution_mode: task.execution_mode,
      priority: task.priority,
      started_at: task.started_at,
      completed_at: task.completed_at,
      error_message: task.error_message,
      assignee_id: task.assignee_id,
      assignee_name: task.assignee&.name
    }
  end
  
  def detailed_task_summary(task)
    task_summary(task).merge({
      description: task.description,
      task_type: task.task_type,
      configuration: task.configuration,
      metadata: task.metadata,
      retry_count: task.retry_count,
      max_retries: task.max_retries,
      task_executions: task.task_executions.recent.limit(5).map do |execution|
        {
          id: execution.id,
          status: execution.status,
          started_at: execution.started_at,
          completed_at: execution.completed_at,
          duration_seconds: execution.duration_seconds,
          error_message: execution.error_message
        }
      end
    })
  end
end