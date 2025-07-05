# ScheduledTask Model
# Represents tasks that are scheduled to run at specific times or intervals
# Supports cron-like scheduling with flexible recurrence patterns
class ScheduledTask < ApplicationRecord
  belongs_to :organization
  belongs_to :task_template
  belongs_to :created_by, class_name: "User"
  has_many :scheduled_task_runs, dependent: :destroy

  # Constants
  STATUSES = %w[active paused completed expired].freeze
  SCHEDULE_TYPES = %w[once daily weekly monthly custom].freeze
  DAYS_OF_WEEK = %w[sunday monday tuesday wednesday thursday friday saturday].freeze

  # Validations
  validates :name, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :schedule_type, presence: true, inclusion: { in: SCHEDULE_TYPES }
  validates :scheduled_at, presence: true, if: -> { schedule_type == "once" }
  validates :cron_expression, presence: true, if: -> { schedule_type == "custom" }
  validates :time_of_day, presence: true, if: -> { schedule_type.in?([ "daily", "weekly", "monthly" ]) }
  validates :days_of_week, presence: true, if: -> { schedule_type == "weekly" }
  validates :day_of_month, presence: true, numericality: { in: 1..31 }, if: -> { schedule_type == "monthly" }
  validates :max_runs, numericality: { greater_than: 0 }, allow_nil: true
  validates :end_date, comparison: { greater_than: :start_date }, if: -> { end_date.present? }

  # Scopes
  scope :active, -> { where(status: "active") }
  scope :paused, -> { where(status: "paused") }
  scope :due_for_execution, -> { active.where("next_run_at <= ?", Time.current) }
  scope :by_schedule_type, ->(type) { where(schedule_type: type) }
  scope :expiring_soon, ->(days = 7) { active.where("end_date <= ?", days.days.from_now) }

  # Callbacks
  before_validation :set_defaults
  before_save :calculate_next_run_at
  after_create :schedule_first_run

  # Check if task should run
  def should_run?
    return false unless active?
    return false if expired?
    return false if reached_max_runs?
    return false if next_run_at > Time.current

    true
  end

  # Execute the scheduled task
  def execute!
    return false unless should_run?

    # Create pipeline execution from template
    pipeline_execution = create_pipeline_execution

    # Create task from template
    task = task_template.create_task_from_template(pipeline_execution, task_overrides)

    # Record the run
    run = scheduled_task_runs.create!(
      pipeline_execution: pipeline_execution,
      task: task,
      started_at: Time.current,
      status: "running"
    )

    # Update run count and next run time
    increment!(:run_count)
    calculate_and_save_next_run_at!

    # Check if this was the last run
    check_completion_status

    run
  end

  # Calculate next run time based on schedule
  def calculate_next_run_at
    return if status != "active"

    base_time = next_run_at || Time.current

    self.next_run_at = case schedule_type
    when "once"
      scheduled_at
    when "daily"
      next_daily_run(base_time)
    when "weekly"
      next_weekly_run(base_time)
    when "monthly"
      next_monthly_run(base_time)
    when "custom"
      next_cron_run(base_time)
    end

    # Ensure next run is within valid date range
    if end_date && next_run_at > end_date
      self.next_run_at = nil
      self.status = "expired" if status == "active"
    end
  end

  def calculate_and_save_next_run_at!
    calculate_next_run_at
    save!
  end

  # Status helpers
  def active?
    status == "active"
  end

  def paused?
    status == "paused"
  end

  def expired?
    status == "expired" || (end_date && end_date < Time.current)
  end

  def reached_max_runs?
    max_runs && run_count >= max_runs
  end

  # Pause the scheduled task
  def pause!
    update!(status: "paused", paused_at: Time.current)
  end

  # Resume the scheduled task
  def resume!
    update!(status: "active", resumed_at: Time.current)
    calculate_and_save_next_run_at!
  end

  # Get schedule description
  def schedule_description
    case schedule_type
    when "once"
      "Once at #{scheduled_at.strftime('%Y-%m-%d %H:%M')}"
    when "daily"
      "Daily at #{time_of_day}"
    when "weekly"
      "Weekly on #{days_of_week.join(', ')} at #{time_of_day}"
    when "monthly"
      "Monthly on day #{day_of_month} at #{time_of_day}"
    when "custom"
      "Custom: #{cron_expression}"
    end
  end

  # Get recent runs
  def recent_runs(limit = 10)
    scheduled_task_runs.includes(:pipeline_execution, :task)
                      .order(started_at: :desc)
                      .limit(limit)
  end

  # Get run statistics
  def run_statistics
    runs = scheduled_task_runs
    {
      total_runs: runs.count,
      successful_runs: runs.where(status: "completed").count,
      failed_runs: runs.where(status: "failed").count,
      average_duration: runs.where(status: "completed").average(:duration_seconds)&.to_i,
      last_run_at: runs.maximum(:started_at),
      next_run_at: next_run_at
    }
  end

  private

  def set_defaults
    self.status ||= "active"
    self.run_count ||= 0
    self.start_date ||= Date.current
    self.configuration ||= {}
    self.task_overrides ||= {}
  end

  def schedule_first_run
    if active? && next_run_at
      TaskSchedulerJob.set(wait_until: next_run_at).perform_later(self)
    end
  end

  def create_pipeline_execution
    PipelineExecution.create!(
      organization: organization,
      pipeline_name: "Scheduled: #{name}",
      data_source_id: configuration["data_source_id"],
      user: created_by,
      status: "running",
      execution_mode: "automated",
      metadata: {
        scheduled_task_id: id,
        scheduled_task_name: name,
        scheduled_at: Time.current
      }
    )
  end

  def check_completion_status
    if schedule_type == "once" || reached_max_runs? || expired?
      update!(status: "completed", completed_at: Time.current)
    end
  end

  # Schedule calculation methods
  def next_daily_run(from_time)
    next_time = from_time.change(
      hour: time_of_day.hour,
      min: time_of_day.min,
      sec: 0
    )

    # If the time has passed today, schedule for tomorrow
    next_time += 1.day if next_time <= from_time
    next_time
  end

  def next_weekly_run(from_time)
    target_days = days_of_week.map { |day| DAYS_OF_WEEK.index(day) }
    current_day = from_time.wday

    # Find next occurrence
    days_ahead = target_days.map do |target_day|
      days = (target_day - current_day) % 7
      days = 7 if days == 0 && from_time.change(hour: time_of_day.hour, min: time_of_day.min) <= from_time
      days
    end.min

    from_time.advance(days: days_ahead).change(
      hour: time_of_day.hour,
      min: time_of_day.min,
      sec: 0
    )
  end

  def next_monthly_run(from_time)
    next_time = from_time.change(
      day: [ day_of_month, from_time.end_of_month.day ].min,
      hour: time_of_day.hour,
      min: time_of_day.min,
      sec: 0
    )

    # If the date has passed this month, schedule for next month
    if next_time <= from_time
      next_time = next_time.next_month.change(
        day: [ day_of_month, next_time.next_month.end_of_month.day ].min
      )
    end

    next_time
  end

  def next_cron_run(from_time)
    # Simple cron parser - in production, use a gem like fugit or whenever
    # This is a placeholder for basic cron support
    # Format: "minute hour day month weekday"
    from_time + 1.hour # Placeholder - implement proper cron parsing
  end
end
