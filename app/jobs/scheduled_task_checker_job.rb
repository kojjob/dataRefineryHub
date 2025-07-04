# ScheduledTaskCheckerJob
# Periodic job that checks for scheduled tasks that are due for execution
# This ensures tasks don't get missed due to system restarts or job failures
class ScheduledTaskCheckerJob < ApplicationJob
  queue_as :scheduled_tasks
  
  def perform
    Rails.logger.info "Checking for due scheduled tasks..."
    
    # Find all tasks that should have run but haven't
    due_tasks = ScheduledTask.active
                            .where('next_run_at <= ?', Time.current)
                            .where.not(next_run_at: nil)
    
    due_count = due_tasks.count
    
    if due_count > 0
      Rails.logger.info "Found #{due_count} scheduled tasks due for execution"
      
      due_tasks.find_each do |scheduled_task|
        # Queue each task for execution
        TaskSchedulerJob.perform_later(scheduled_task)
        
        Rails.logger.info "Queued scheduled task: #{scheduled_task.name} (ID: #{scheduled_task.id})"
      end
    else
      Rails.logger.info "No scheduled tasks due for execution"
    end
    
    # Also check for any tasks that might have been missed during downtime
    check_missed_tasks
  end
  
  private
  
  def check_missed_tasks
    # Look for active tasks where the last run was more than expected
    missed_tasks = ScheduledTask.active.where.not(next_run_at: nil).select do |task|
      last_run = task.scheduled_task_runs.maximum(:started_at)
      
      if last_run && task.next_run_at
        # Check if we've missed any runs
        case task.schedule_type
        when 'daily'
          last_run < 1.day.ago && task.next_run_at < Time.current
        when 'weekly'
          last_run < 1.week.ago && task.next_run_at < Time.current
        when 'monthly'
          last_run < 1.month.ago && task.next_run_at < Time.current
        else
          false
        end
      else
        # No previous runs and next_run_at is in the past
        task.next_run_at < 1.hour.ago
      end
    end
    
    if missed_tasks.any?
      Rails.logger.warn "Found #{missed_tasks.count} potentially missed scheduled tasks"
      
      missed_tasks.each do |task|
        Rails.logger.warn "Missed task: #{task.name} (ID: #{task.id}, next_run_at: #{task.next_run_at})"
        
        # Update next_run_at to current time to trigger execution
        task.update!(next_run_at: Time.current)
        TaskSchedulerJob.perform_later(task)
      end
    end
  end
end