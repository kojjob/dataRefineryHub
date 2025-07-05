# TaskExecution Model
# Records individual execution attempts of tasks with results and metrics
class TaskExecution < ApplicationRecord
  belongs_to :task
  belongs_to :executed_by, class_name: "User", optional: true

  # Constants
  STATUSES = %w[pending running completed failed cancelled].freeze

  # Validations
  validates :execution_id, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :successful, -> { where(status: "completed") }
  scope :failed, -> { where(status: "failed") }
  scope :running, -> { where(status: "running") }

  # Callbacks
  before_create :set_defaults
  before_save :calculate_duration

  # State transitions
  def start!
    self.status = "running"
    self.started_at = Time.current
    save!
  end

  def complete!(result = {})
    self.status = "completed"
    self.completed_at = Time.current
    self.result = result
    save!
  end

  def fail!(error_message, error_details = {})
    self.status = "failed"
    self.completed_at = Time.current
    self.error_message = error_message
    self.error_details = error_details
    save!
  end

  def cancel!
    self.status = "cancelled"
    self.completed_at = Time.current
    save!
  end

  # Status checks
  def completed?
    status == "completed"
  end

  def failed?
    status == "failed"
  end

  def running?
    status == "running"
  end

  def finished?
    completed? || failed? || cancelled?
  end

  def cancelled?
    status == "cancelled"
  end

  # Badge class helper
  def status_badge_class
    case status
    when "completed" then "bg-green-100 text-green-800"
    when "failed" then "bg-red-100 text-red-800"
    when "running" then "bg-blue-100 text-blue-800"
    when "cancelled" then "bg-gray-100 text-gray-800"
    else "bg-gray-50 text-gray-600"
    end
  end

  # Metrics
  def duration
    return nil unless started_at && completed_at
    completed_at - started_at
  end

  def duration_formatted
    return "N/A" unless duration_seconds

    seconds = duration_seconds
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    secs = seconds % 60

    if hours > 0
      "#{hours}h #{minutes}m #{secs}s"
    elsif minutes > 0
      "#{minutes}m #{secs}s"
    else
      "#{secs}s"
    end
  end

  # Summary methods
  def to_summary_hash
    {
      id: id,
      execution_id: execution_id,
      task_id: task_id,
      task_name: task.name,
      status: status,
      started_at: started_at,
      completed_at: completed_at,
      duration: duration_formatted,
      executed_by: executed_by&.name,
      error_message: error_message
    }
  end

  def to_detailed_hash
    summary = to_summary_hash
    summary.merge({
      result: result,
      error_details: error_details,
      metadata: metadata,
      created_at: created_at,
      updated_at: updated_at
    })
  end

  private

  def set_defaults
    self.execution_id ||= SecureRandom.uuid
    self.status ||= "pending"
    self.metadata ||= {}
    self.result ||= {}
    self.error_details ||= {}
  end

  def calculate_duration
    if started_at && completed_at
      self.duration_seconds = (completed_at - started_at).to_i
    end
  end
end
