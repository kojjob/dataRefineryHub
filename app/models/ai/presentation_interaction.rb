# Presentation Interaction Model
# Tracks user interactions with presentations (clicks, hovers, form submissions, etc.)

module Ai
  class PresentationInteraction < ApplicationRecord
    self.table_name = "ai_presentation_interactions"

    # Associations
    belongs_to :presentation, class_name: "Ai::Presentation"
    belongs_to :user, optional: true
    belongs_to :organization

    # Validations
    validates :interaction_type, presence: true, inclusion: {
      in: %w[click hover scroll form_submit button_press navigation slide_change
             zoom pan filter sort search download share bookmark comment vote poll_response
             quiz_answer feedback rating time_spent session_start session_end],
      message: "%{value} is not a valid interaction type"
    }
    validates :session_id, presence: true
    validates :timestamp, presence: true
    validates :element_id, length: { maximum: 255 }
    validates :element_type, length: { maximum: 100 }
    validates :page_url, length: { maximum: 500 }
    validates :user_agent, length: { maximum: 500 }
    validates :ip_address, format: {
      with: /\A(?:[0-9]{1,3}\.){3}[0-9]{1,3}\z|\A(?:[0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}\z/,
      message: "Invalid IP address format",
      allow_blank: true
    }

    # Scopes
    scope :recent, -> { where("timestamp > ?", 24.hours.ago) }
    scope :by_type, ->(type) { where(interaction_type: type) }
    scope :by_session, ->(session_id) { where(session_id: session_id) }
    scope :by_user, ->(user) { where(user: user) }
    scope :by_element, ->(element_id) { where(element_id: element_id) }
    scope :engagement_interactions, -> { where(interaction_type: %w[click button_press form_submit poll_response quiz_answer]) }
    scope :navigation_interactions, -> { where(interaction_type: %w[navigation slide_change scroll]) }
    scope :content_interactions, -> { where(interaction_type: %w[zoom pan filter sort search]) }
    scope :social_interactions, -> { where(interaction_type: %w[share bookmark comment vote]) }
    scope :feedback_interactions, -> { where(interaction_type: %w[feedback rating]) }
    scope :session_interactions, -> { where(interaction_type: %w[session_start session_end time_spent]) }

    # Serialized attributes
    serialize :metadata, coder: JSON
  serialize :coordinates, coder: JSON
  serialize :form_data, coder: JSON

    # Callbacks
    before_create :set_defaults
    before_create :extract_device_info
    after_create :update_presentation_metrics

    # Instance methods
    def engagement_interaction?
      %w[click button_press form_submit poll_response quiz_answer].include?(interaction_type)
    end

    def navigation_interaction?
      %w[navigation slide_change scroll].include?(interaction_type)
    end

    def content_interaction?
      %w[zoom pan filter sort search].include?(interaction_type)
    end

    def social_interaction?
      %w[share bookmark comment vote].include?(interaction_type)
    end

    def feedback_interaction?
      %w[feedback rating].include?(interaction_type)
    end

    def session_interaction?
      %w[session_start session_end time_spent].include?(interaction_type)
    end

    def valuable_interaction?
      # Interactions that indicate meaningful engagement
      engagement_interaction? || social_interaction? || feedback_interaction?
    end

    def duration_seconds
      return 0 unless duration
      duration / 1000.0 # Convert milliseconds to seconds
    end

    def coordinates_x
      coordinates&.dig("x") || 0
    end

    def coordinates_y
      coordinates&.dig("y") || 0
    end

    def viewport_width
      metadata&.dig("viewport", "width") || 0
    end

    def viewport_height
      metadata&.dig("viewport", "height") || 0
    end

    def device_type
      metadata&.dig("device", "type") || "unknown"
    end

    def browser
      metadata&.dig("browser", "name") || "unknown"
    end

    def operating_system
      metadata&.dig("os", "name") || "unknown"
    end

    def mobile_device?
      device_type == "mobile"
    end

    def tablet_device?
      device_type == "tablet"
    end

    def desktop_device?
      device_type == "desktop"
    end

    def element_context
      {
        id: element_id,
        type: element_type,
        text: element_text,
        value: element_value
      }
    end

    def interaction_context
      {
        type: interaction_type,
        timestamp: timestamp,
        duration: duration_seconds,
        coordinates: coordinates,
        element: element_context,
        device: {
          type: device_type,
          browser: browser,
          os: operating_system
        },
        viewport: {
          width: viewport_width,
          height: viewport_height
        }
      }
    end

    def session_interactions
      self.class.by_session(session_id)
                .where(presentation: presentation)
                .order(:timestamp)
    end

    def previous_interaction
      session_interactions.where("timestamp < ?", timestamp).last
    end

    def next_interaction
      session_interactions.where("timestamp > ?", timestamp).first
    end

    def time_since_previous
      prev = previous_interaction
      return 0 unless prev

      (timestamp - prev.timestamp) / 1000.0 # Convert to seconds
    end

    def interaction_sequence_position
      session_interactions.where("timestamp <= ?", timestamp).count
    end

    def engagement_score
      # Calculate engagement score based on interaction type and context
      base_score = case interaction_type
      when "click", "button_press" then 3
      when "form_submit", "poll_response", "quiz_answer" then 5
      when "share", "bookmark" then 4
      when "comment", "feedback", "rating" then 6
      when "download" then 4
      when "navigation", "slide_change" then 2
      when "scroll", "hover" then 1
      when "zoom", "pan", "filter", "sort", "search" then 3
      else 1
      end

      # Adjust based on duration
      duration_multiplier = if duration_seconds > 5
                           1.5
      elsif duration_seconds > 2
                           1.2
      else
                           1.0
      end

      # Adjust based on sequence position (later interactions are more valuable)
      position_multiplier = [ 1.0 + (interaction_sequence_position * 0.1), 2.0 ].min

      (base_score * duration_multiplier * position_multiplier).round(2)
    end

    def to_analytics_hash
      {
        id: id,
        type: interaction_type,
        timestamp: timestamp.iso8601,
        duration: duration_seconds,
        element: element_context,
        coordinates: coordinates,
        device: device_type,
        browser: browser,
        engagement_score: engagement_score,
        session_position: interaction_sequence_position,
        valuable: valuable_interaction?
      }
    end

    # Class methods
    def self.engagement_metrics(presentation_id, time_range = 24.hours)
      interactions = where(presentation_id: presentation_id)
                    .where("timestamp > ?", time_range.ago)

      total_interactions = interactions.count
      unique_sessions = interactions.distinct.count(:session_id)
      unique_users = interactions.where.not(user_id: nil).distinct.count(:user_id)

      engagement_interactions = interactions.engagement_interactions.count
      valuable_interactions = interactions.select(&:valuable_interaction?).count

      avg_session_interactions = unique_sessions > 0 ? (total_interactions.to_f / unique_sessions).round(2) : 0
      avg_engagement_score = interactions.sum(&:engagement_score) / [ total_interactions, 1 ].max

      {
        total_interactions: total_interactions,
        unique_sessions: unique_sessions,
        unique_users: unique_users,
        engagement_interactions: engagement_interactions,
        valuable_interactions: valuable_interactions,
        avg_session_interactions: avg_session_interactions,
        avg_engagement_score: avg_engagement_score.round(2),
        engagement_rate: total_interactions > 0 ? (engagement_interactions.to_f / total_interactions * 100).round(2) : 0
      }
    end

    def self.popular_elements(presentation_id, limit = 10)
      where(presentation_id: presentation_id)
        .where.not(element_id: nil)
        .group(:element_id, :element_type)
        .order("count_id DESC")
        .limit(limit)
        .count(:id)
        .map do |key, count|
          {
            element_id: key[0],
            element_type: key[1],
            interaction_count: count
          }
        end
    end

    def self.interaction_heatmap(presentation_id, width = 1920, height = 1080)
      interactions = where(presentation_id: presentation_id)
                    .where.not(coordinates: nil)
                    .where(interaction_type: %w[click hover])

      grid_size = 50
      x_buckets = (width / grid_size).ceil
      y_buckets = (height / grid_size).ceil

      heatmap = Array.new(y_buckets) { Array.new(x_buckets, 0) }

      interactions.find_each do |interaction|
        x = interaction.coordinates_x
        y = interaction.coordinates_y

        next if x < 0 || y < 0 || x >= width || y >= height

        x_bucket = (x / grid_size).floor
        y_bucket = (y / grid_size).floor

        heatmap[y_bucket][x_bucket] += 1
      end

      {
        width: width,
        height: height,
        grid_size: grid_size,
        data: heatmap
      }
    end

    def self.session_flow(session_id)
      where(session_id: session_id)
        .order(:timestamp)
        .map(&:to_analytics_hash)
    end

    def self.conversion_funnel(presentation_id, funnel_steps)
      # Track users through a defined conversion funnel
      sessions = where(presentation_id: presentation_id)
                .distinct
                .pluck(:session_id)

      funnel_data = funnel_steps.map.with_index do |step, index|
        step_sessions = where(presentation_id: presentation_id)
                       .where(session_id: sessions)
                       .where(interaction_type: step[:interaction_type])

        step_sessions = step_sessions.where(element_id: step[:element_id]) if step[:element_id]

        completed_sessions = step_sessions.distinct.count(:session_id)

        {
          step: index + 1,
          name: step[:name],
          interaction_type: step[:interaction_type],
          element_id: step[:element_id],
          completed_sessions: completed_sessions,
          conversion_rate: sessions.count > 0 ? (completed_sessions.to_f / sessions.count * 100).round(2) : 0
        }
      end

      {
        total_sessions: sessions.count,
        funnel_steps: funnel_data
      }
    end

    private

    def set_defaults
      self.timestamp ||= Time.current
      self.metadata ||= {}
      self.coordinates ||= {}
      self.form_data ||= {}
    end

    def extract_device_info
      return unless user_agent.present?

      # Simple user agent parsing (in production, use a proper library)
      self.metadata ||= {}

      # Device type detection
      device_type = if user_agent.match?(/Mobile|Android|iPhone|iPad/i)
                     if user_agent.match?(/iPad/i)
                       "tablet"
                     else
                       "mobile"
                     end
      else
                     "desktop"
      end

      # Browser detection
      browser_name = case user_agent
      when /Chrome/i then "Chrome"
      when /Firefox/i then "Firefox"
      when /Safari/i then "Safari"
      when /Edge/i then "Edge"
      else "Unknown"
      end

      # OS detection
      os_name = case user_agent
      when /Windows/i then "Windows"
      when /Mac/i then "macOS"
      when /Linux/i then "Linux"
      when /Android/i then "Android"
      when /iOS/i then "iOS"
      else "Unknown"
      end

      self.metadata.merge!({
        device: { type: device_type },
        browser: { name: browser_name },
        os: { name: os_name }
      })
    end

    def update_presentation_metrics
      # Update presentation engagement metrics asynchronously
      UpdatePresentationMetricsJob.perform_later(presentation.id) if presentation
    rescue => e
      Rails.logger.error "Failed to update presentation metrics for interaction #{id}: #{e.message}"
    end
  end
end
