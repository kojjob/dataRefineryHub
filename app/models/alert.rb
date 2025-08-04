class Alert < ApplicationRecord
  # Alert types for different system components
  ALERT_TYPES = %w[
    pipeline
    data_quality
    system
    security
    performance
    integration
    ai_processing
    storage
    user_activity
  ].freeze

  # Severity levels
  SEVERITY_LEVELS = %w[
    low
    medium
    high
    critical
  ].freeze

  # Status options
  STATUS_OPTIONS = %w[
    active
    acknowledged
    resolved
    dismissed
  ].freeze

  # Associations
  belongs_to :organization
  belongs_to :user, optional: true
  belongs_to :data_source, optional: true
  belongs_to :pipeline_execution, optional: true

  # Validations
  validates :alert_type, presence: true, inclusion: { in: ALERT_TYPES }
  validates :severity, presence: true, inclusion: { in: SEVERITY_LEVELS }
  validates :status, presence: true, inclusion: { in: STATUS_OPTIONS }
  validates :title, presence: true, length: { maximum: 255 }
  validates :message, presence: true, length: { maximum: 2000 }

  # Scopes
  scope :active, -> { where(status: "active") }
  scope :resolved, -> { where(status: "resolved") }
  scope :acknowledged, -> { where(status: "acknowledged") }
  scope :dismissed, -> { where(status: "dismissed") }
  scope :unresolved, -> { where.not(status: [ "resolved", "dismissed" ]) }

  scope :by_type, ->(type) { where(alert_type: type) }
  scope :by_severity, ->(severity) { where(severity: severity) }
  scope :critical, -> { where(severity: "critical") }
  scope :high_priority, -> { where(severity: [ "critical", "high" ]) }

  scope :recent, -> { order(created_at: :desc) }
  scope :oldest_first, -> { order(created_at: :asc) }

  # Callbacks
  before_validation :set_defaults, on: :create
  after_create :notify_users, if: :should_notify?

  # Instance methods
  def resolved?
    status == "resolved"
  end

  def acknowledged?
    status == "acknowledged"
  end

  def active?
    status == "active"
  end

  def dismissed?
    status == "dismissed"
  end

  def critical?
    severity == "critical"
  end

  def high_priority?
    %w[critical high].include?(severity)
  end

  def resolve!(resolved_by_user = nil)
    update!(
      status: "resolved",
      resolved_at: Time.current,
      resolved_by: resolved_by_user
    )
  end

  def acknowledge!(acknowledged_by_user = nil)
    update!(
      status: "acknowledged",
      acknowledged_at: Time.current,
      acknowledged_by: acknowledged_by_user
    )
  end

  def dismiss!(dismissed_by_user = nil)
    update!(
      status: "dismissed",
      dismissed_at: Time.current,
      dismissed_by: dismissed_by_user
    )
  end

  def severity_color
    case severity
    when "critical"
      "red"
    when "high"
      "orange"
    when "medium"
      "yellow"
    when "low"
      "blue"
    else
      "gray"
    end
  end

  def severity_icon
    case severity
    when "critical"
      "exclamation-triangle"
    when "high"
      "exclamation-circle"
    when "medium"
      "information-circle"
    when "low"
      "check-circle"
    else
      "bell"
    end
  end

  def type_icon
    case alert_type
    when "pipeline"
      "cog"
    when "data_quality"
      "shield-check"
    when "system"
      "server"
    when "security"
      "lock-closed"
    when "performance"
      "chart-bar"
    when "integration"
      "link"
    when "ai_processing"
      "cpu-chip"
    when "storage"
      "circle-stack"
    when "user_activity"
      "user"
    else
      "bell"
    end
  end

  def formatted_created_at
    created_at.strftime("%B %d, %Y at %I:%M %p")
  end

  def time_since_created
    time_ago_in_words = ActionController::Base.helpers.time_ago_in_words(created_at)
    "#{time_ago_in_words} ago"
  end

  private

  def set_defaults
    self.status ||= "active"
    self.severity ||= "medium"
  end

  def should_notify?
    %w[critical high].include?(severity) && active?
  end

  def notify_users
    # This could be expanded to send notifications via email, Slack, etc.
    # For now, we'll just log the alert creation
    Rails.logger.info "Critical alert created: #{title} for organization #{organization.name}"
  end
end
