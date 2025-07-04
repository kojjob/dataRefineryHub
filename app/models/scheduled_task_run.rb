# ScheduledTaskRun Model
# Records individual executions of scheduled tasks
class ScheduledTaskRun < ApplicationRecord
  belongs_to :scheduled_task
  belongs_to :pipeline_execution, optional: true
  belongs_to :task, optional: true
  
  # Constants
  STATUSES = %w[pending running completed failed cancelled].freeze
  
  # Validations
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :started_at, presence: true
  
  # Scopes
  scope :recent, -> { order(started_at: :desc) }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :running, -> { where(status: 'running') }
  
  # Callbacks
  before_validation :set_defaults
  after_update :update_duration, if: :saved_change_to_completed_at?
  
  # Complete the run successfully
  def complete!(output = nil)
    update!(
      status: 'completed',
      completed_at: Time.current,
      output: output
    )
  end
  
  # Mark the run as failed
  def fail!(error_message)
    update!(
      status: 'failed',
      completed_at: Time.current,
      error_message: error_message
    )
  end
  
  # Status checks
  def running?
    status == 'running'
  end
  
  def completed?
    status == 'completed'
  end
  
  def failed?
    status == 'failed'
  end
  
  # Duration in seconds
  def duration_seconds
    return nil unless started_at && completed_at
    (completed_at - started_at).to_i
  end
  
  # Display helpers
  def status_badge_class
    case status
    when 'completed' then 'bg-green-100 text-green-800'
    when 'failed' then 'bg-red-100 text-red-800'
    when 'running' then 'bg-blue-100 text-blue-800'
    when 'cancelled' then 'bg-gray-100 text-gray-800'
    else 'bg-gray-50 text-gray-600'
    end
  end
  
  private
  
  def set_defaults
    self.status ||= 'pending'
    self.started_at ||= Time.current
  end
  
  def update_duration
    self.duration_seconds = (completed_at - started_at).to_i if completed_at && started_at
  end
end