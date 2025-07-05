# TaskExecutorJob
# Executes individual tasks with support for hybrid execution modes
# Leverages Solid Queue for reliable job processing
class TaskExecutorJob < ApplicationJob
  queue_as :default

  # Retry configuration with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 3 do |job, error|
    task = job.arguments.first
    Rails.logger.error "Task execution failed for task #{task.id}: #{error.class.name} - #{error.message}"

    # Update task with failure if all retries exhausted
    task.fail!(error.message, false) # false = don't retry anymore
  end

  # Don't retry if task is deleted
  discard_on ActiveRecord::RecordNotFound

  def perform(task)
    # Reload task to get latest state
    task.reload

    # Check if task can still be executed
    unless task.can_execute?
      Rails.logger.info "Task #{task.id} cannot be executed in current state: #{task.status}"
      return
    end

    # Create execution record
    execution = task.task_executions.create!(
      execution_id: task.execution_id,
      executed_by: task.assignee,
      status: "running",
      started_at: Time.current,
      metadata: {
        job_id: job_id,
        queue: queue_name,
        execution_mode: task.execution_mode
      }
    )

    begin
      # Execute task based on execution mode and type
      result = execute_task_by_mode(task, execution)

      # Mark task and execution as completed
      execution.complete!(result)
      task.complete!(result)

      # Process dependent tasks
      process_dependent_tasks(task)

      Rails.logger.info "Task #{task.id} completed successfully"

    rescue => error
      # Handle execution failure
      handle_task_failure(task, execution, error)
      raise # Re-raise for retry mechanism
    end
  end

  private

  def execute_task_by_mode(task, execution)
    case task.execution_mode
    when "automated"
      execute_automated_task(task)
    when "manual"
      execute_manual_task(task, execution)
    when "approval_required"
      execute_approval_task(task, execution)
    when "hybrid"
      execute_hybrid_task(task, execution)
    end
  end

  def execute_automated_task(task)
    Rails.logger.info "Executing automated task: #{task.name}"

    # Execute based on task type
    case task.task_type
    when "extraction"
      execute_extraction_task(task)
    when "transformation"
      execute_transformation_task(task)
    when "validation"
      execute_validation_task(task)
    when "notification"
      execute_notification_task(task)
    when "custom"
      execute_custom_task(task)
    else
      raise "Unknown task type: #{task.task_type}"
    end
  end

  def execute_manual_task(task, execution)
    Rails.logger.info "Executing manual task: #{task.name} by user #{task.assignee.name}"

    # Manual tasks are typically UI-driven actions
    # Here we execute any automated portions
    result = execute_automated_task(task)

    # Add manual execution metadata
    result[:manual_execution] = {
      executed_by: task.assignee.id,
      executed_at: Time.current
    }

    result
  end

  def execute_approval_task(task, execution)
    Rails.logger.info "Executing approval task: #{task.name}"

    # For approval tasks, we execute after approval is granted
    # The approval itself is handled by the approve! method on the Task model
    execute_automated_task(task)
  end

  def execute_hybrid_task(task, execution)
    Rails.logger.info "Executing hybrid task: #{task.name}"

    # Hybrid tasks can switch between automated and manual
    # Decision logic based on task configuration
    if should_execute_automatically?(task)
      execute_automated_task(task)
    else
      # Convert to manual execution
      task.update!(execution_mode: "manual", status: "ready")
      broadcast_manual_task_notification(task)

      { status: "converted_to_manual", reason: "Conditions require manual intervention" }
    end
  end

  def should_execute_automatically?(task)
    # Check task configuration for automation conditions
    config = task.configuration || {}

    # Example conditions (customize based on your needs)
    return false if config["require_manual_on_error"] && task.retry_count > 0
    return false if config["business_hours_only"] && !business_hours?
    return false if config["max_auto_amount"] && exceeds_threshold?(task, config["max_auto_amount"])

    true
  end

  def business_hours?
    # Example: Monday-Friday, 9 AM - 5 PM in the configured timezone
    current_time = Time.current.in_time_zone(Rails.application.config.time_zone)
    current_time.on_weekday? && current_time.hour.between?(9, 17)
  end

  def exceeds_threshold?(task, threshold)
    # Check if task parameters exceed configured threshold
    task.configuration["amount"].to_f > threshold.to_f rescue false
  end

  # Task type execution methods
  def execute_extraction_task(task)
    config = task.configuration
    data_source_id = config["data_source_id"]

    raise "No data source specified for extraction task" unless data_source_id

    # Delegate to existing extraction job
    ExtractionJobProcessor.new.perform(data_source_id)

    { status: "extracted", data_source_id: data_source_id }
  end

  def execute_transformation_task(task)
    config = task.configuration
    data_source_id = config["data_source_id"]
    transformation_rules = config["transformation_rules"]

    # Delegate to existing transformation job
    TransformationJobProcessor.new.perform(data_source_id)

    { status: "transformed", data_source_id: data_source_id }
  end

  def execute_validation_task(task)
    config = task.configuration
    data_source_id = config["data_source_id"]
    validation_rules = config["validation_rules"] || {}

    # Perform validation
    validator = DataQualityValidationService.new
    validation_result = validator.validate_data_source(data_source_id, validation_rules)

    if validation_result[:valid]
      { status: "validated", validation_result: validation_result }
    else
      raise "Validation failed: #{validation_result[:errors].join(', ')}"
    end
  end

  def execute_notification_task(task)
    config = task.configuration
    notification_type = config["notification_type"]
    recipients = config["recipients"]
    message = config["message"]

    # Send notification (implement your notification logic)
    case notification_type
    when "email"
      # Send email notification
      Rails.logger.info "Sending email to #{recipients}: #{message}"
    when "slack"
      # Send Slack notification
      Rails.logger.info "Sending Slack message: #{message}"
    when "webhook"
      # Call webhook
      Rails.logger.info "Calling webhook: #{config['webhook_url']}"
    end

    { status: "notified", notification_type: notification_type, recipients: recipients }
  end

  def execute_custom_task(task)
    config = task.configuration
    custom_handler = config["handler_class"]

    if custom_handler && Object.const_defined?(custom_handler)
      handler = custom_handler.constantize.new
      handler.execute(task)
    else
      raise "Custom handler not found: #{custom_handler}"
    end
  end

  def handle_task_failure(task, execution, error)
    Rails.logger.error "Task #{task.id} execution failed: #{error.message}"
    Rails.logger.error error.backtrace.join("\n")

    # Update execution record
    execution.fail!(
      error.message,
      {
        error_class: error.class.name,
        backtrace: error.backtrace.first(10)
      }
    )

    # Update task (will retry if under retry limit)
    task.fail!(error.message)

    # Notify about failure if configured
    notify_task_failure(task, error) if task.configuration["notify_on_failure"]
  end

  def process_dependent_tasks(completed_task)
    # Find tasks that depend on this one
    dependent_tasks = completed_task.pipeline_execution.tasks
                                   .where("depends_on @> ARRAY[?]::varchar[]", completed_task.name)
                                   .pending

    dependent_tasks.each do |task|
      task.check_and_update_readiness

      # Auto-execute if it's automated and ready
      if task.ready? && task.execution_mode == "automated"
        TaskExecutorJob.perform_later(task)
      end
    end
  end

  def broadcast_manual_task_notification(task)
    # Notify that a manual task needs attention
    ActionCable.server.broadcast(
      "manual_task_queue",
      {
        type: "manual_task_required",
        task: {
          id: task.id,
          name: task.name,
          description: task.description,
          pipeline_name: task.pipeline_execution.pipeline_name,
          priority: task.priority
        },
        timestamp: Time.current
      }
    )
  end

  def notify_task_failure(task, error)
    # Implement failure notification logic
    Rails.logger.info "Notifying about task failure: #{task.name}"

    # Example: Send email or Slack notification
    # FailureNotificationJob.perform_later(task, error.message)
  end
end
