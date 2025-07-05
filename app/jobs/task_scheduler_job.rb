# TaskSchedulerJob
# Executes scheduled tasks and manages their recurring execution
class TaskSchedulerJob < ApplicationJob
  queue_as :scheduled_tasks

  # Retry configuration for transient failures
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(scheduled_task)
    return unless scheduled_task.should_run?

    Rails.logger.info "Executing scheduled task: #{scheduled_task.name} (ID: #{scheduled_task.id})"

    begin
      # Execute the scheduled task
      run = scheduled_task.execute!

      # Monitor the execution
      monitor_execution(run)

      # Schedule next run if applicable
      schedule_next_run(scheduled_task) if scheduled_task.active?

      Rails.logger.info "Successfully executed scheduled task: #{scheduled_task.name}"
    rescue => e
      Rails.logger.error "Failed to execute scheduled task #{scheduled_task.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      # Record failure if run was created
      run&.fail!(e.message)

      # Still schedule next run to continue the schedule
      schedule_next_run(scheduled_task) if scheduled_task.active?

      raise e # Re-raise for retry mechanism
    end
  end

  # Class method to check and execute all due tasks
  def self.check_and_execute_due_tasks
    ScheduledTask.due_for_execution.find_each do |scheduled_task|
      perform_later(scheduled_task)
    end
  end

  # Class method to reschedule all active tasks (useful after restart)
  def self.reschedule_all_active_tasks
    ScheduledTask.active.where.not(next_run_at: nil).find_each do |scheduled_task|
      if scheduled_task.next_run_at > Time.current
        set(wait_until: scheduled_task.next_run_at).perform_later(scheduled_task)
      else
        perform_later(scheduled_task)
      end
    end
  end

  private

  def monitor_execution(run)
    return unless run.task

    # Set up monitoring for the task execution
    start_time = Time.current
    timeout = 30.minutes # Maximum time to monitor

    loop do
      task = run.task.reload

      case task.status
      when "completed"
        run.complete!(task.metadata[:result])
        break
      when "failed", "cancelled"
        run.fail!(task.error_message || "Task #{task.status}")
        break
      when "in_progress"
        # Continue monitoring
        if Time.current - start_time > timeout
          run.fail!("Task execution timed out after #{timeout / 60} minutes")
          break
        end
        sleep 5 # Check every 5 seconds
      else
        # Task hasn't started yet or is in unexpected state
        if Time.current - start_time > 5.minutes
          run.fail!("Task failed to start within 5 minutes")
          break
        end
        sleep 2
      end
    end
  end

  def schedule_next_run(scheduled_task)
    return unless scheduled_task.active? && scheduled_task.next_run_at

    # Schedule the next execution
    self.class.set(wait_until: scheduled_task.next_run_at).perform_later(scheduled_task)

    Rails.logger.info "Scheduled next run for task #{scheduled_task.id} at #{scheduled_task.next_run_at}"
  end
end
