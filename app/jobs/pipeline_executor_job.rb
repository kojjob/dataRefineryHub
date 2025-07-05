# PipelineExecutorJob
# Executes pipeline tasks in sequence, handling dependencies and failure modes
class PipelineExecutorJob < ApplicationJob
  queue_as :default

  def perform(pipeline_execution)
    Rails.logger.info "Starting pipeline execution: #{pipeline_execution.pipeline_name} (#{pipeline_execution.id})"

    # Process tasks in dependency order
    process_pipeline_tasks(pipeline_execution)

    # Update final pipeline status
    pipeline_execution.update_task_progress!

    Rails.logger.info "Pipeline execution completed: #{pipeline_execution.pipeline_name} (#{pipeline_execution.status})"
  rescue => e
    Rails.logger.error "Pipeline execution failed: #{e.message}"
    pipeline_execution.update!(
      status: "failed",
      error_message: e.message,
      completed_at: Time.current
    )
    raise e
  end

  private

  def process_pipeline_tasks(pipeline_execution)
    # Get tasks in execution order
    tasks = pipeline_execution.tasks.order(:position)

    tasks.each do |task|
      next unless should_execute_task?(task)

      # Check if pipeline is paused
      if pipeline_execution.reload.status == "paused"
        Rails.logger.info "Pipeline paused, stopping execution"
        break
      end

      # Execute automated tasks immediately
      if task.execution_mode == "automated"
        execute_automated_task(task)
      elsif task.execution_mode == "approval_required"
        task.request_approval!
      end

      # Manual tasks will be picked up by users from the queue
    end
  end

  def should_execute_task?(task)
    # Only execute if dependencies are satisfied and status is appropriate
    task.check_and_update_readiness
    task.reload.status == "ready"
  end

  def execute_automated_task(task)
    return unless task.status == "ready"

    Rails.logger.info "Executing automated task: #{task.name}"

    # Start task execution
    task.execute!

    # Queue the actual task processing
    TaskExecutorJob.perform_later(task)
  end
end
