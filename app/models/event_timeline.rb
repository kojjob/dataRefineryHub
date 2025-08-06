class EventTimeline < ApplicationRecord
  belongs_to :organization

  # Polymorphic association for the resource that triggered the event
  belongs_to :resource, polymorphic: true, optional: true

  # Event categories
  CATEGORIES = %w[
    pipeline
    data_source
    alert
    system
    user_action
    error
    configuration
  ].freeze

  # Event types
  EVENT_TYPES = %w[
    pipeline_started
    pipeline_completed
    pipeline_failed
    data_sync_started
    data_sync_completed
    data_sync_failed
    alert_created
    alert_resolved
    user_login
    user_logout
    configuration_changed
    error_occurred
    system_health_check
  ].freeze

  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }
  validates :event_category, presence: true, inclusion: { in: CATEGORIES }
  validates :title, presence: true
  validates :occurred_at, presence: true

  scope :recent, -> { order(occurred_at: :desc) }
  scope :by_category, ->(category) { where(event_category: category) }
  scope :by_type, ->(type) { where(event_type: type) }
  scope :today, -> { where(occurred_at: Time.current.beginning_of_day..Time.current.end_of_day) }

  before_validation :set_defaults

  private

  def set_defaults
    self.occurred_at ||= Time.current
  end
end
