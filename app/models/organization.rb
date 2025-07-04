class Organization < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: :slugged

  PLANS = %w[free_trial starter growth scale enterprise].freeze
  STATUSES = %w[active suspended cancelled trial].freeze

  has_many :users, dependent: :destroy
  has_many :data_sources, dependent: :destroy
  has_many :extraction_jobs, through: :data_sources
  has_many :raw_data_records, through: :data_sources
  has_many :dashboards, dependent: :destroy
  has_many :api_keys, dependent: :destroy
  has_many :audit_logs, dependent: :destroy
  has_many :visualizations, dependent: :destroy
  has_many :presentations, dependent: :destroy
  has_many :pipeline_executions, dependent: :destroy
  
  # AI-related associations
  has_many :ai_presentations, class_name: 'Ai::Presentation', dependent: :destroy
  has_many :ai_presentation_views, class_name: 'Ai::PresentationView', dependent: :destroy
  has_many :ai_presentation_interactions, class_name: 'Ai::PresentationInteraction', dependent: :destroy
  has_many :ai_insights, class_name: 'Ai::Insight', dependent: :destroy
  has_many :alerts, dependent: :destroy

  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :plan, inclusion: { in: PLANS }
  validates :status, inclusion: { in: STATUSES }
  validates :stripe_customer_id, uniqueness: true, allow_blank: true
  validates :timezone, presence: true, inclusion: { 
    in: ActiveSupport::TimeZone.all.map(&:name), 
    message: "must be a valid timezone" 
  }, allow_blank: true
  validates :phone, format: { 
    with: /\A[\+]?[1-9][\d\s\-\(\)]{7,14}\z/, 
    message: "must be a valid phone number" 
  }, allow_blank: true

  scope :active, -> { where(status: "active") }
  scope :by_plan, ->(plan) { where(plan: plan) }

  before_validation :set_defaults, on: :create
  before_validation :normalize_name

  def free_trial_plan?
    plan == "free_trial"
  end

  def starter_plan?
    plan == "starter"
  end

  def growth_plan?
    plan == "growth"
  end

  def scale_plan?
    plan == "scale"
  end

  def enterprise_plan?
    plan == "enterprise"
  end

  def active?
    status == "active"
  end

  def trial?
    status == "trial"
  end

  def monthly_data_limit
    case plan
    when "free_trial" then 10_000
    when "starter" then 100_000
    when "growth" then 500_000
    when "scale" then 2_000_000
    when "enterprise" then Float::INFINITY
    else 0
    end
  end

  def monthly_api_requests_limit
    case plan
    when "free_trial" then 1_000
    when "starter" then 10_000
    when "growth" then 50_000
    when "scale" then 200_000
    when "enterprise" then Float::INFINITY
    else 0
    end
  end

  def max_users
    case plan
    when "free_trial" then 2
    when "starter" then 5
    when "growth" then 20
    when "scale" then 100
    when "enterprise" then Float::INFINITY
    else 0
    end
  end

  def max_data_sources
    case plan
    when "free_trial" then 2
    when "starter" then 5
    when "growth" then 15
    when "scale" then 50
    when "enterprise" then Float::INFINITY
    else 0
    end
  end

  def can_add_user?
    users.count < max_users
  end

  def can_add_data_source?
    data_sources.count < max_data_sources
  end
  
  # AI Presentation methods
  def monthly_presentation_limit
    case plan
    when "free_trial" then 5
    when "starter" then 25
    when "growth" then 100
    when "scale" then 500
    when "enterprise" then Float::INFINITY
    else 0
    end
  end
  
  def monthly_view_limit
    case plan
    when "free_trial" then 100
    when "starter" then 1000
    when "growth" then 10000
    when "scale" then 50000
    when "enterprise" then Float::INFINITY
    else 0
    end
  end
  
  def presentations_this_month
    ai_presentations.where(
      'created_at >= ? AND created_at <= ?',
      Time.current.beginning_of_month,
      Time.current.end_of_month
    ).count
  end
  
  def views_this_month
    ai_presentation_views.where(
      'created_at >= ? AND created_at <= ?',
      Time.current.beginning_of_month,
      Time.current.end_of_month
    ).count
  end
  
  def within_presentation_limit?
    presentations_this_month < monthly_presentation_limit
  end
  
  def within_view_limit?
    views_this_month < monthly_view_limit
  end
  
  def recent_presentations(limit = 10)
    ai_presentations.includes(:user)
                   .order(created_at: :desc)
                   .limit(limit)
  end
  
  def engagement_metrics(days = 30)
    start_date = days.days.ago
    
    presentations = ai_presentations.where('created_at >= ?', start_date)
    views = ai_presentation_views.where('created_at >= ?', start_date)
    interactions = ai_presentation_interactions.where('timestamp >= ?', start_date)
    
    {
      total_presentations: presentations.count,
      total_views: views.count,
      total_interactions: interactions.count,
      unique_viewers: views.distinct.count(:user_id),
      avg_view_duration: views.average(:duration)&.to_f&.round(2) || 0,
      completion_rate: calculate_completion_rate(views),
      engagement_score: calculate_engagement_score(interactions)
    }
  end

  private

  def set_defaults
    self.plan ||= "free_trial"
    self.status ||= "trial"
    self.plan_limits ||= {}
    self.settings ||= {}
    self.timezone ||= "UTC"
  end

  def normalize_name
    self.name = name&.strip
  end
  
  def calculate_completion_rate(views)
    return 0 if views.empty?
    
    completed_views = views.where('completion_percentage >= ?', 80).count
    (completed_views.to_f / views.count * 100).round(2)
  end
  
  def calculate_engagement_score(interactions)
    return 0 if interactions.empty?
    
    total_score = interactions.sum do |interaction|
      case interaction.interaction_type
      when 'click', 'button_press' then 3
      when 'form_submit', 'poll_response' then 5
      when 'share', 'bookmark' then 4
      when 'comment', 'feedback' then 6
      else 1
      end
    end
    
    (total_score.to_f / interactions.count).round(2)
  end
end
