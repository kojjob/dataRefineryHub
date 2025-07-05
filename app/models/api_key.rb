class ApiKey < ApplicationRecord
  belongs_to :organization
  belongs_to :user
  has_many :api_usages, dependent: :destroy

  validates :name, presence: true
  validates :key, presence: true, uniqueness: true
  validates :usage_count, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true) }

  before_create :generate_key

  def increment_usage!
    increment!(:usage_count)
    update!(last_used_at: Time.current)
  end

  def rate_limit_exceeded?
    # Simple rate limiting based on organization plan
    monthly_limit = organization.monthly_api_requests_limit || 1000
    monthly_usage = usage_count || 0

    monthly_usage >= monthly_limit
  end

  private

  def generate_key
    self.key ||= SecureRandom.hex(32)
  end
end
