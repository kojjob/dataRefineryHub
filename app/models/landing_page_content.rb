class LandingPageContent < ApplicationRecord
  validates :section, presence: true, length: { maximum: 100 }
  validates :title, presence: true, length: { maximum: 200 }
  validates :content, presence: true
  validates :display_order, presence: true, numericality: { greater_than: 0 }

  scope :active, -> { where(active: true) }
  scope :by_section, ->(section) { where(section: section) }
  scope :ordered, -> { order(:display_order, :created_at) }

  SECTIONS = %w[
    hero_stats ai_features integrations pricing_plans
    hero_content value_propositions social_proof
  ].freeze

  validates :section, inclusion: { in: SECTIONS }

  def self.for_section(section)
    active.by_section(section).ordered
  end

  def self.seed_data
    return if exists?

    # Hero Stats
    create!([
      {
        section: "hero_stats",
        title: "AI Insights Generated",
        content: "50M+",
        metadata: { icon: "brain", color: "blue" },
        active: true,
        display_order: 1
      },
      {
        section: "hero_stats",
        title: "Anomalies Detected",
        content: "2.5M+",
        metadata: { icon: "alert", color: "green" },
        active: true,
        display_order: 2
      },
      {
        section: "hero_stats",
        title: "Businesses Served",
        content: "10,000+",
        metadata: { icon: "users", color: "purple" },
        active: true,
        display_order: 3
      },
      {
        section: "hero_stats",
        title: "Prediction Accuracy",
        content: "94.7%",
        metadata: { icon: "target", color: "indigo" },
        active: true,
        display_order: 4
      },
      {
        section: "hero_stats",
        title: "Records Processed",
        content: "2.5B+",
        metadata: { icon: "database", color: "red" },
        active: true,
        display_order: 5
      },
      {
        section: "hero_stats",
        title: "Uptime SLA",
        content: "99.99%",
        metadata: { icon: "shield", color: "gray" },
        active: true,
        display_order: 6
      }
    ])

    # AI Features
    create!([
      {
        section: "ai_features",
        title: "Autonomous Business Intelligence Agent",
        content: "AI agent that monitors your business 24/7, generates proactive insights, and alerts you to opportunities and risks before they impact your bottom line.",
        metadata: {
          icon: "ai-brain",
          demo_available: true,
          benefits: ["Proactive Insights", "24/7 Monitoring", "Predictive Analytics", "Risk Assessment"]
        },
        active: true,
        display_order: 1
      },
      {
        section: "ai_features",
        title: "Real-Time Anomaly Detection",
        content: "Advanced ML algorithms detect unusual patterns in your data instantly, preventing issues before they become problems.",
        metadata: {
          icon: "anomaly-detection",
          demo_available: true,
          benefits: ["Instant Alerts", "Smart Thresholds", "Pattern Learning", "False Positive Reduction"]
        },
        active: true,
        display_order: 2
      },
      {
        section: "ai_features",
        title: "Enhanced Data Intelligence",
        content: "AI automatically understands your business context, identifies data patterns, and suggests optimizations for maximum ROI.",
        metadata: {
          icon: "data-intelligence",
          demo_available: true,
          benefits: ["Context Recognition", "Quality Scoring", "ROI Estimation", "Auto-Optimization"]
        },
        active: true,
        display_order: 3
      }
    ])

    # Integrations
    integrations = [
      { name: "Shopify", ai_feature: "Revenue Predictions" },
      { name: "QuickBooks", ai_feature: "Financial Anomalies" },
      { name: "Stripe", ai_feature: "Churn Prediction" },
      { name: "Mailchimp", ai_feature: "Campaign Optimization" },
      { name: "Google Analytics", ai_feature: "Behavior Analysis" },
      { name: "HubSpot", ai_feature: "Lead Scoring" },
      { name: "Zendesk", ai_feature: "Support Intelligence" },
      { name: "Slack", ai_feature: "Team Productivity" },
      { name: "Salesforce", ai_feature: "Sales Forecasting" },
      { name: "Airtable", ai_feature: "Workflow Optimization" }
    ]

    integrations.each_with_index do |integration, index|
      create!(
        section: "integrations",
        title: integration[:name],
        content: integration[:ai_feature],
        metadata: { status: "active", category: "business" },
        active: true,
        display_order: index + 1
      )
    end
  end
end
