class Organization < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: :slugged

  PLANS = %w[free_trial starter growth scale enterprise].freeze
  STATUSES = %w[active suspended cancelled trial].freeze

  has_many :users, dependent: :destroy
  has_many :data_sources, dependent: :destroy
  has_many :dashboards, dependent: :destroy
  has_many :api_keys, dependent: :destroy
  has_many :audit_logs, dependent: :destroy

  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :plan, inclusion: { in: PLANS }
  validates :status, inclusion: { in: STATUSES }
  validates :stripe_customer_id, uniqueness: true, allow_blank: true

  scope :active, -> { where(status: 'active') }
  scope :by_plan, ->(plan) { where(plan: plan) }

  before_validation :set_defaults, on: :create
  before_validation :normalize_name

  def free_trial_plan?
    plan == 'free_trial'
  end

  def starter_plan?
    plan == 'starter'
  end

  def growth_plan?
    plan == 'growth'
  end

  def scale_plan?
    plan == 'scale'
  end

  def enterprise_plan?
    plan == 'enterprise'
  end

  def active?
    status == 'active'
  end

  def trial?
    status == 'trial'
  end

  def monthly_data_limit
    case plan
    when 'free_trial' then 10_000
    when 'starter' then 100_000
    when 'growth' then 500_000
    when 'scale' then 2_000_000
    when 'enterprise' then Float::INFINITY
    else 0
    end
  end

  def monthly_api_requests_limit
    case plan
    when 'free_trial' then 1_000
    when 'starter' then 10_000
    when 'growth' then 50_000
    when 'scale' then 200_000
    when 'enterprise' then Float::INFINITY
    else 0
    end
  end

  def max_users
    case plan
    when 'free_trial' then 2
    when 'starter' then 5
    when 'growth' then 20
    when 'scale' then 100
    when 'enterprise' then Float::INFINITY
    else 0
    end
  end

  def max_data_sources
    case plan
    when 'free_trial' then 2
    when 'starter' then 5
    when 'growth' then 15
    when 'scale' then 50
    when 'enterprise' then Float::INFINITY
    else 0
    end
  end

  def can_add_user?
    users.count < max_users
  end

  def can_add_data_source?
    data_sources.count < max_data_sources
  end

  private

  def set_defaults
    self.plan ||= 'free_trial'
    self.status ||= 'trial'
    self.plan_limits ||= {}
    self.settings ||= {}
  end

  def normalize_name
    self.name = name&.strip
  end
end
