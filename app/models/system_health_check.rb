class SystemHealthCheck < ApplicationRecord
  belongs_to :organization

  CHECK_TYPES = %w[
    database
    cache
    job_queue
    storage
    api_shopify
    api_quickbooks
    api_stripe
    api_mailchimp
    api_google_analytics
  ].freeze

  STATUSES = %w[healthy degraded unhealthy].freeze

  validates :check_type, presence: true, inclusion: { in: CHECK_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :checked_at, presence: true

  scope :recent, -> { order(checked_at: :desc) }
  scope :by_type, ->(type) { where(check_type: type) }
  scope :healthy, -> { where(status: "healthy") }
  scope :unhealthy, -> { where(status: [ "degraded", "unhealthy" ]) }
  scope :latest_by_type, -> {
    select("DISTINCT ON (check_type) *")
      .order(:check_type, checked_at: :desc)
  }

  before_validation :set_defaults

  def healthy?
    status == "healthy"
  end

  def unhealthy?
    status == "unhealthy"
  end

  def degraded?
    status == "degraded"
  end

  private

  def set_defaults
    self.checked_at ||= Time.current
  end
end
