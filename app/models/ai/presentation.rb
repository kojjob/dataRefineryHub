# AI Presentation Model
# Represents interactive presentations with AI capabilities

module Ai
  class Presentation < ApplicationRecord
    self.table_name = "presentations"

    # Associations
    belongs_to :organization
    belongs_to :user
    belongs_to :data_source, optional: true

    has_many :views, class_name: "Ai::PresentationView", dependent: :destroy
    has_many :interactions, class_name: "Ai::PresentationInteraction", dependent: :destroy
    has_many :feedback, class_name: "Ai::PresentationFeedback", dependent: :destroy
    has_many :performance_logs, class_name: "Ai::PresentationPerformanceLog", dependent: :destroy
    has_many :conversions, class_name: "Ai::PresentationConversion", dependent: :destroy
    has_many :ai_insights, class_name: "Ai::Insight", dependent: :destroy
    has_many :slides, class_name: "Ai::PresentationSlide", dependent: :destroy
    has_many :charts, class_name: "Ai::PresentationChart", dependent: :destroy

    # Validations
    validates :title, presence: true, length: { maximum: 255 }
    validates :presentation_type, presence: true, inclusion: {
      in: %w[interactive live_dashboard data_story monitoring],
      message: "%{value} is not a valid presentation type"
    }
    validates :status, presence: true, inclusion: {
      in: %w[draft active archived],
      message: "%{value} is not a valid status"
    }
    validates :engagement_score, numericality: {
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 100
    }, allow_nil: true

    # Scopes
    scope :active, -> { where(status: "active") }
    scope :draft, -> { where(status: "draft") }
    scope :archived, -> { where(status: "archived") }
    scope :recent, -> { where("created_at > ?", 30.days.ago) }
    scope :by_type, ->(type) { where(presentation_type: type) }
    scope :with_live_data, -> { where(live_data_enabled: true) }
    scope :collaborative, -> { where(collaboration_enabled: true) }

    # Callbacks
    before_create :set_defaults
    after_create :create_initial_slide
    after_update :update_engagement_score, if: :saved_change_to_view_count?

    # Serialized attributes
    serialize :configuration, coder: JSON
    serialize :metadata, coder: JSON
    serialize :interactive_elements, coder: JSON

    # Instance methods
    def live?
      status == "active" && live_data_enabled?
    end

    def completion_rate
      return 0.0 if views.count.zero?

      completed_views = views.where(completed: true).count
      (completed_views.to_f / views.count).round(3)
    end

    def average_view_duration
      views.where.not(duration: nil).average(:duration) || 0
    end

    def average_load_time
      performance_logs.where.not(load_time: nil).average(:load_time) || 0
    end

    def error_rate
      return 0.0 if performance_logs.count.zero?

      error_count = performance_logs.where(status: "error").count
      (error_count.to_f / performance_logs.count * 100).round(2)
    end

    def bounce_rate
      return 0.0 if views.count.zero?

      bounced_views = views.where("duration < ?", 30).count
      (bounced_views.to_f / views.count * 100).round(2)
    end

    def interaction_rate
      return 0.0 if views.count.zero?

      (interactions.count.to_f / views.count * 100).round(2)
    end

    def average_rating
      feedback.where.not(rating: nil).average(:rating) || 0.0
    end

    def total_revenue
      conversions.sum(:value) || 0
    end

    def conversion_rate
      return 0.0 if views.count.zero?

      (conversions.count.to_f / views.count * 100).round(2)
    end

    def geographic_distribution
      views.group(:country).count
    end

    def peak_viewing_hours
      views.group_by_hour_of_day(:created_at).count
    end

    def device_breakdown
      views.group(:device_type).count
    end

    def can_be_edited_by?(user)
      return true if self.user == user
      return true if user.admin?
      return true if collaboration_enabled? && collaborators.include?(user.id)

      false
    end

    def collaborators
      metadata&.dig("collaborators") || []
    end

    def add_collaborator(user_id)
      current_collaborators = collaborators
      current_collaborators << user_id unless current_collaborators.include?(user_id)

      update_metadata("collaborators", current_collaborators)
    end

    def remove_collaborator(user_id)
      current_collaborators = collaborators
      current_collaborators.delete(user_id)

      update_metadata("collaborators", current_collaborators)
    end

    def refresh_data!
      return unless live_data_enabled? && data_source

      begin
        # Refresh data from the associated data source
        fresh_data = data_source.fetch_latest_data

        # Update charts and visualizations
        charts.each do |chart|
          chart.update_data(fresh_data)
        end

        # Update last refreshed timestamp
        update_metadata("last_data_refresh", Time.current)

        # Log the refresh
        Rails.logger.info "Data refreshed for presentation #{id} at #{Time.current}"

        true
      rescue => e
        Rails.logger.error "Failed to refresh data for presentation #{id}: #{e.message}"
        false
      end
    end

    def generate_share_url(options = {})
      base_url = Rails.application.routes.url_helpers.ai_interactive_presentation_url(
        self,
        host: Rails.application.config.action_mailer.default_url_options[:host]
      )

      if options[:embed]
        "#{base_url}?embed=true"
      elsif options[:readonly]
        "#{base_url}?readonly=true"
      else
        base_url
      end
    end

    def export_data(format = "json")
      case format.downcase
      when "json"
        export_as_json
      when "pdf"
        export_as_pdf
      when "pptx"
        export_as_powerpoint
      else
        raise ArgumentError, "Unsupported export format: #{format}"
      end
    end

    def calculate_engagement_score!
      # Calculate engagement based on multiple factors
      view_score = normalize_score(views.count, 0, 1000) * 0.3
      interaction_score = normalize_score(interactions.count, 0, 500) * 0.25
      completion_score = completion_rate * 0.25
      rating_score = (average_rating / 5.0) * 0.2

      new_score = ((view_score + interaction_score + completion_score + rating_score) * 100).round(1)

      update(engagement_score: new_score)
      new_score
    end

    def trending?
      return false if created_at < 7.days.ago

      recent_views = views.where("created_at > ?", 24.hours.ago).count
      avg_daily_views = views.count.to_f / [ (Time.current - created_at) / 1.day, 1 ].max

      recent_views > avg_daily_views * 1.5
    end

    def health_status
      issues = []

      issues << "High load time" if average_load_time > 3.0
      issues << "High error rate" if error_rate > 5.0
      issues << "Low engagement" if engagement_score && engagement_score < 50
      issues << "Stale data" if live_data_enabled? && data_last_refreshed_at && data_last_refreshed_at < 1.hour.ago

      if issues.empty?
        { status: "healthy", issues: [] }
      elsif issues.length == 1
        { status: "warning", issues: issues }
      else
        { status: "critical", issues: issues }
      end
    end

    private

    def set_defaults
      self.status ||= "draft"
      self.view_count ||= 0
      self.engagement_score ||= 0.0
      self.configuration ||= {}
      self.metadata ||= {}
      self.interactive_elements ||= []
      self.live_data_enabled ||= false
      self.collaboration_enabled ||= false
      self.mobile_optimized ||= true
      self.sharing_enabled ||= true
    end

    def create_initial_slide
      slides.create!(
        title: "Welcome",
        content: "Welcome to your new presentation",
        slide_order: 1,
        slide_type: "title"
      )
    end

    def update_engagement_score
      calculate_engagement_score!
    end

    def update_metadata(key, value)
      current_metadata = metadata || {}
      current_metadata[key] = value
      update(metadata: current_metadata)
    end

    def normalize_score(value, min_val, max_val)
      return 0.0 if max_val == min_val

      normalized = (value.to_f - min_val) / (max_val - min_val)
      [ [ normalized, 0.0 ].max, 1.0 ].min
    end

    def data_last_refreshed_at
      metadata&.dig("last_data_refresh")&.to_time
    end

    def export_as_json
      {
        id: id,
        title: title,
        type: presentation_type,
        content: content,
        slides: slides.order(:slide_order).map(&:to_export_hash),
        charts: charts.map(&:to_export_hash),
        metadata: metadata,
        configuration: configuration,
        created_at: created_at,
        updated_at: updated_at
      }.to_json
    end

    def export_as_pdf
      # Implementation for PDF export
      # This would use a gem like Prawn or WickedPDF
      raise NotImplementedError, "PDF export not yet implemented"
    end

    def export_as_powerpoint
      # Implementation for PowerPoint export
      # This would use a gem like ruby-pptx
      raise NotImplementedError, "PowerPoint export not yet implemented"
    end
  end
end
