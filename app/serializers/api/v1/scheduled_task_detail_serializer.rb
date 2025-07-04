# API::V1::ScheduledTaskDetailSerializer
# Detailed serializer for scheduled task with configuration and statistics
class Api::V1::ScheduledTaskDetailSerializer < Api::V1::ScheduledTaskSerializer
  attributes :scheduled_at, :time_of_day, :days_of_week, :day_of_month,
             :cron_expression, :configuration, :task_overrides, :paused_at,
             :resumed_at, :completed_at, :run_statistics
  
  has_many :recent_runs, serializer: Api::V1::ScheduledTaskRunSerializer
  
  def recent_runs
    object.recent_runs(5)
  end
  
  def run_statistics
    object.run_statistics
  end
end