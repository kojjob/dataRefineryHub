class DeliveryLog < ApplicationRecord
  belongs_to :user
  belongs_to :organization

  # Scopes
  scope :delivered, -> { where(status: "delivered") }
  scope :failed, -> { where(status: "failed") }
  scope :pending, -> { where(status: "pending") }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_channel, ->(channel) { where(channel: channel) }
  scope :today, -> { where(created_at: Date.current.all_day) }

  # Validations
  validates :channel, presence: true, inclusion: {
    in: %w[whatsapp email sms pdf slides webhook api]
  }
  validates :status, presence: true, inclusion: {
    in: %w[pending delivered failed retry]
  }
  validates :report_type, presence: true

  # Callbacks
  before_create :set_defaults

  # Check if delivery was successful
  def successful?
    status == "delivered"
  end

  # Check if delivery failed
  def failed?
    status == "failed"
  end

  # Get delivery duration
  def delivery_duration
    return nil unless delivered_at.present?
    delivered_at - created_at
  end

  # Retry delivery
  def retry_delivery
    return false unless failed?

    # Mark current log as retry attempted
    update!(status: "retry")

    # Trigger new delivery attempt
    DeliveryRetryJob.perform_later(self)
    true
  end

  private

  def set_defaults
    self.metadata ||= {}
    self.status ||= "pending"
  end
end
