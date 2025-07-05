# AI Insight Model
# Stores AI-generated insights and recommendations

module Ai
  class Insight < ApplicationRecord
    self.table_name = "ai_insights"

    # Associations
    belongs_to :organization
    belongs_to :user, optional: true
    belongs_to :presentation, class_name: "Ai::Presentation", optional: true
    belongs_to :data_source, optional: true

    # Validations
    validates :insight_type, presence: true, inclusion: {
      in: %w[performance engagement content trend quality usage strategy recommendation],
      message: "%{value} is not a valid insight type"
    }
    validates :title, presence: true, length: { maximum: 255 }
    validates :description, presence: true, length: { maximum: 1000 }
    validates :confidence_score, presence: true, numericality: {
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 1.0
    }
    validates :impact_level, presence: true, inclusion: {
      in: %w[low medium high critical],
      message: "%{value} is not a valid impact level"
    }

    # Scopes
    scope :recent, -> { where("created_at > ?", 30.days.ago) }
    scope :by_type, ->(type) { where(insight_type: type) }
    scope :by_impact, ->(level) { where(impact_level: level) }
    scope :actionable, -> { where(actionable: true) }
    scope :high_confidence, -> { where("confidence_score > ?", 0.7) }
    scope :critical, -> { where(impact_level: "critical") }
    scope :unread, -> { where(read_at: nil) }
    scope :acknowledged, -> { where.not(acknowledged_at: nil) }

    # Callbacks
    before_create :set_defaults
    after_create :notify_stakeholders, if: :critical?

    # Instance methods
    def critical?
      impact_level == "critical"
    end

    def high_impact?
      %w[high critical].include?(impact_level)
    end

    def high_confidence?
      confidence_score > 0.7
    end

    def reliable?
      high_confidence? && high_impact?
    end

    def read?
      read_at.present?
    end

    def acknowledged?
      acknowledged_at.present?
    end

    def mark_as_read!(user = nil)
      update(
        read_at: Time.current,
        read_by: user&.id
      )
    end

    def acknowledge!(user = nil)
      update(
        acknowledged_at: Time.current,
        acknowledged_by: user&.id
      )
    end

    def dismiss!(reason = nil)
      update(
        dismissed_at: Time.current,
        dismissal_reason: reason
      )
    end

    def age_in_days
      (Time.current - created_at) / 1.day
    end

    def stale?
      age_in_days > 7
    end

    def priority_score
      # Calculate priority based on impact, confidence, and age
      impact_weight = case impact_level
      when "critical" then 1.0
      when "high" then 0.8
      when "medium" then 0.6
      when "low" then 0.4
      end

      confidence_weight = confidence_score
      age_weight = [ 1.0 - (age_in_days / 30.0), 0.1 ].max # Decreases over time

      (impact_weight * 0.5 + confidence_weight * 0.3 + age_weight * 0.2) * 100
    end

    def context_object
      presentation || data_source
    end

    def context_type
      return "presentation" if presentation
      return "data_source" if data_source
      "organization"
    end

    def context_name
      case context_type
      when "presentation"
        presentation.title
      when "data_source"
        data_source.name
      else
        organization.name
      end
    end

    def generate_action_items
      return [] unless actionable?

      case insight_type
      when "performance"
        generate_performance_actions
      when "engagement"
        generate_engagement_actions
      when "content"
        generate_content_actions
      when "quality"
        generate_quality_actions
      else
        []
      end
    end

    def estimated_effort
      # Return estimated effort to implement recommendations
      case impact_level
      when "critical"
        "high"
      when "high"
        "medium"
      when "medium"
        "low"
      when "low"
        "minimal"
      end
    end

    def expected_impact
      # Return expected impact description
      metadata&.dig("expected_impact") || "#{impact_level.capitalize} improvement expected"
    end

    def related_insights
      # Find related insights based on type and context
      scope = organization.ai_insights.where.not(id: id)

      if presentation
        scope = scope.where(presentation: presentation)
      elsif data_source
        scope = scope.where(data_source: data_source)
      end

      scope.where(insight_type: insight_type)
           .recent
           .limit(5)
    end

    def to_notification_hash
      {
        id: id,
        type: insight_type,
        title: title,
        description: description,
        impact: impact_level,
        confidence: confidence_score,
        actionable: actionable?,
        context: {
          type: context_type,
          name: context_name,
          id: context_object&.id
        },
        created_at: created_at,
        priority_score: priority_score
      }
    end

    # Class methods
    def self.generate_summary(insights)
      return {} if insights.empty?

      {
        total: insights.count,
        by_type: insights.group(:insight_type).count,
        by_impact: insights.group(:impact_level).count,
        actionable: insights.where(actionable: true).count,
        high_confidence: insights.where("confidence_score > ?", 0.7).count,
        unread: insights.where(read_at: nil).count,
        avg_confidence: insights.average(:confidence_score)&.round(2) || 0.0,
        latest: insights.order(created_at: :desc).first&.created_at
      }
    end

    def self.trending_types(days = 7)
      where("created_at > ?", days.days.ago)
        .group(:insight_type)
        .order("count_id DESC")
        .count(:id)
        .first(3)
        .to_h
    end

    private

    def set_defaults
      self.actionable ||= false
      self.metadata ||= {}
      self.recommendations ||= []
    end

    def notify_stakeholders
      # Send notifications for critical insights
      NotificationService.new(organization).notify_critical_insight(self)
    rescue => e
      Rails.logger.error "Failed to notify stakeholders for insight #{id}: #{e.message}"
    end

    def generate_performance_actions
      actions = []

      if metadata&.dig("avg_load_time")&.> 3.0
        actions << {
          type: "optimization",
          title: "Optimize Loading Performance",
          description: "Reduce image sizes and optimize data queries",
          effort: "medium",
          impact: "high"
        }
      end

      if metadata&.dig("error_rate")&.> 0.05
        actions << {
          type: "debugging",
          title: "Fix Error Issues",
          description: "Investigate and resolve presentation errors",
          effort: "high",
          impact: "critical"
        }
      end

      actions
    end

    def generate_engagement_actions
      actions = []

      if metadata&.dig("completion_rate")&.< 0.7
        actions << {
          type: "content",
          title: "Improve Content Engagement",
          description: "Add interactive elements or reduce content length",
          effort: "medium",
          impact: "high"
        }
      end

      if metadata&.dig("interaction_rate")&.< 0.1
        actions << {
          type: "interactivity",
          title: "Increase Interactivity",
          description: "Add polls, quizzes, or clickable elements",
          effort: "low",
          impact: "medium"
        }
      end

      actions
    end

    def generate_content_actions
      actions = []

      if metadata&.dig("avg_rating")&.< 4.0
        actions << {
          type: "content_review",
          title: "Review Content Quality",
          description: "Analyze feedback and improve content based on user comments",
          effort: "medium",
          impact: "medium"
        }
      end

      actions
    end

    def generate_quality_actions
      actions = []

      if metadata&.dig("quality_score")&.< 0.8
        actions << {
          type: "data_quality",
          title: "Improve Data Quality",
          description: "Implement data validation and cleansing processes",
          effort: "high",
          impact: "critical"
        }
      end

      actions
    end
  end
end
