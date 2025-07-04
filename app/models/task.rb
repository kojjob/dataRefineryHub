# Task Model
# Represents individual executable units within a pipeline
# Supports multiple execution modes: automated, manual, approval_required, hybrid
class Task < ApplicationRecord
  belongs_to :pipeline_execution
  belongs_to :assignee, class_name: 'User', optional: true
  has_many :task_executions, dependent: :destroy
  
  # Broadcast changes for real-time updates
  broadcasts_refreshes
  
  # Constants
  EXECUTION_MODES = %w[automated manual approval_required hybrid].freeze
  STATUSES = %w[pending ready waiting_approval in_progress completed failed cancelled skipped].freeze
  TASK_TYPES = %w[extraction transformation validation notification approval custom].freeze
  
  # Validations
  validates :name, presence: true
  validates :task_type, presence: true, inclusion: { in: TASK_TYPES }
  validates :execution_mode, presence: true, inclusion: { in: EXECUTION_MODES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :priority, numericality: { greater_than_or_equal_to: 0 }
  validates :timeout_seconds, numericality: { greater_than: 0 }
  validates :max_retries, numericality: { greater_than_or_equal_to: 0 }
  validates :retry_count, numericality: { greater_than_or_equal_to: 0 }
  
  # Scopes
  scope :pending, -> { where(status: 'pending') }
  scope :ready, -> { where(status: 'ready') }
  scope :manual, -> { where(execution_mode: 'manual') }
  scope :automated, -> { where(execution_mode: 'automated') }
  scope :requiring_approval, -> { where(status: 'waiting_approval') }
  scope :in_progress, -> { where(status: 'in_progress') }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :by_priority, -> { order(priority: :desc, position: :asc) }
  scope :for_manual_queue, -> { where(execution_mode: 'manual', status: 'ready') }
  
  # Callbacks
  before_create :set_defaults
  before_save :update_pipeline_execution_status
  after_update_commit :broadcast_status_change, if: :saved_change_to_status?
  
  # State machine-like methods
  def ready_for_execution?
    status == 'ready' && dependencies_satisfied?
  end
  
  def can_execute?
    case execution_mode
    when 'automated'
      ready_for_execution?
    when 'manual'
      ready_for_execution? && assignee.present?
    when 'approval_required'
      status == 'waiting_approval' && assignee.present?
    when 'hybrid'
      ready_for_execution? || (status == 'waiting_approval' && assignee.present?)
    end
  end
  
  def execute!(user = nil)
    return false unless can_execute?
    
    self.assignee = user if user
    self.status = 'in_progress'
    self.started_at = Time.current
    self.execution_id = SecureRandom.uuid
    save!
    
    # Queue the task execution job
    TaskExecutorJob.perform_later(self)
    true
  end
  
  def complete!(result = {})
    self.status = 'completed'
    self.completed_at = Time.current
    self.metadata = (metadata || {}).merge(result: result)
    save!
  end
  
  def fail!(error_message, retry_task = true)
    self.error_message = error_message
    self.retry_count += 1
    
    if retry_task && retry_count < max_retries
      self.status = 'ready'
      Rails.logger.info "Task #{id} failed, retrying (#{retry_count}/#{max_retries})"
    else
      self.status = 'failed'
      self.completed_at = Time.current
      Rails.logger.error "Task #{id} failed permanently: #{error_message}"
    end
    
    save!
  end
  
  def cancel!
    return false unless can_cancel?
    
    self.status = 'cancelled'
    self.completed_at = Time.current
    save!
  end
  
  def skip!
    self.status = 'skipped'
    self.completed_at = Time.current
    save!
  end
  
  def request_approval!(approver = nil)
    return false unless execution_mode.in?(['approval_required', 'hybrid'])
    
    self.status = 'waiting_approval'
    self.assignee = approver if approver
    save!
  end
  
  def approve!(user)
    return false unless status == 'waiting_approval'
    
    self.assignee = user
    self.status = 'ready'
    self.metadata = (metadata || {}).merge(
      approved_by: user.id,
      approved_at: Time.current
    )
    save!
  end
  
  def reject!(user, reason = nil)
    return false unless status == 'waiting_approval'
    
    self.status = 'cancelled'
    self.completed_at = Time.current
    self.metadata = (metadata || {}).merge(
      rejected_by: user.id,
      rejected_at: Time.current,
      rejection_reason: reason
    )
    save!
  end
  
  # Dependency management
  def dependencies_satisfied?
    return true if depends_on.blank?
    
    dependency_tasks = pipeline_execution.tasks.where(name: depends_on)
    dependency_tasks.all?(&:completed?)
  end
  
  def check_and_update_readiness
    if dependencies_satisfied? && status == 'pending'
      update!(status: 'ready')
    end
  end
  
  # Status checks
  def completed?
    status == 'completed'
  end
  
  def failed?
    status == 'failed'
  end
  
  def in_progress?
    status == 'in_progress'
  end
  
  def pending?
    status == 'pending'
  end
  
  def can_cancel?
    status.in?(['pending', 'ready', 'waiting_approval', 'in_progress'])
  end
  
  # Metrics
  def duration
    return nil unless started_at && completed_at
    completed_at - started_at
  end
  
  def duration_seconds
    duration&.to_i
  end
  
  # Display helpers
  def display_name
    "#{name} (#{task_type})"
  end
  
  def execution_mode_badge_class
    case execution_mode
    when 'automated' then 'bg-blue-100 text-blue-800'
    when 'manual' then 'bg-yellow-100 text-yellow-800'
    when 'approval_required' then 'bg-red-100 text-red-800'
    when 'hybrid' then 'bg-purple-100 text-purple-800'
    end
  end
  
  def status_badge_class
    case status
    when 'completed' then 'bg-green-100 text-green-800'
    when 'failed' then 'bg-red-100 text-red-800'
    when 'in_progress' then 'bg-blue-100 text-blue-800'
    when 'waiting_approval' then 'bg-yellow-100 text-yellow-800'
    when 'cancelled', 'skipped' then 'bg-gray-100 text-gray-800'
    else 'bg-gray-50 text-gray-600'
    end
  end
  
  # Cache key for efficient caching with Solid Cache
  def cache_key_with_version
    "#{model_name.cache_key}/#{id}/#{updated_at.to_fs(:number)}"
  end
  
  private
  
  def set_defaults
    self.execution_id ||= SecureRandom.uuid
    self.status ||= 'pending'
    self.priority ||= 0
    self.retry_count ||= 0
    self.configuration ||= {}
    self.metadata ||= {}
    self.depends_on ||= []
  end
  
  def update_pipeline_execution_status
    return unless saved_change_to_status?
    
    # Update pipeline execution progress
    pipeline_execution.update_task_progress!
  end
  
  def broadcast_status_change
    # Broadcast to pipeline channel
    ActionCable.server.broadcast(
      "pipeline_#{pipeline_execution_id}",
      {
        type: 'task_status_update',
        task_id: id,
        status: status,
        timestamp: Time.current
      }
    )
    
    # Broadcast to manual task queue if applicable
    if execution_mode == 'manual' && status == 'ready'
      ActionCable.server.broadcast(
        "manual_task_queue",
        {
          type: 'new_manual_task',
          task: {
            id: id,
            name: name,
            pipeline_name: pipeline_execution.pipeline_name,
            priority: priority
          }
        }
      )
    end
  end
end
