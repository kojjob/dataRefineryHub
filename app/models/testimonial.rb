class Testimonial < ApplicationRecord
  validates :name, presence: true, length: { maximum: 100 }
  validates :company, presence: true, length: { maximum: 100 }
  validates :role, presence: true, length: { maximum: 100 }
  validates :quote, presence: true, length: { maximum: 1000 }
  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :highlight, presence: true, length: { maximum: 200 }
  validates :ai_feature, presence: true, length: { maximum: 200 }

  scope :active, -> { where(active: true) }
  scope :featured, -> { where(active: true).order(:display_order, :created_at) }

  def initials
    name.split.map(&:first).join.upcase
  end

  def self.seed_data
    return if exists?

    create!([
      {
        name: "Sarah Chen",
        company: "TechStart Inc.",
        role: "CEO",
        quote: "DataReflow's AI agent predicted a 30% revenue drop 2 weeks early. We pivoted our marketing strategy and ended up growing 40% instead.",
        rating: 5,
        highlight: "AI Prediction Accuracy",
        ai_feature: "Autonomous Business Intelligence Agent",
        active: true,
        display_order: 1
      },
      {
        name: "Michael Rodriguez",
        company: "GrowthCorp",
        role: "VP of Operations",
        quote: "The real-time anomaly detection caught inventory issues our team missed. Saved us $250K in lost sales during Black Friday.",
        rating: 5,
        highlight: "Real-time Anomaly Detection",
        ai_feature: "Smart Alerting System",
        active: true,
        display_order: 2
      },
      {
        name: "Emma Thompson",
        company: "ScaleUp Solutions",
        role: "Data Director",
        quote: "Setup took 15 minutes. AI immediately identified 3 revenue opportunities worth $500K. ROI was 2000% in month one.",
        rating: 5,
        highlight: "Instant Business Insights",
        ai_feature: "Enhanced Data Intelligence",
        active: true,
        display_order: 3
      }
    ])
  end
end
