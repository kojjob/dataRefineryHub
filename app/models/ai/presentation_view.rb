# AI Presentation View Model
# Tracks individual views of presentations

module Ai
  class PresentationView < ApplicationRecord
    self.table_name = "ai_presentation_views"

    # Associations
    belongs_to :presentation, class_name: "Ai::Presentation"
    belongs_to :user, optional: true
    belongs_to :organization

    # Validations
    validates :session_id, presence: true
    validates :ip_address, presence: true
    validates :user_agent, presence: true
    validates :duration, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validates :device_type, inclusion: {
      in: %w[desktop mobile tablet],
      message: "%{value} is not a valid device type"
    }, allow_nil: true

    # Scopes
    scope :recent, -> { where("created_at > ?", 30.days.ago) }
    scope :completed, -> { where(completed: true) }
    scope :by_country, ->(country) { where(country: country) }
    scope :by_device, ->(device) { where(device_type: device) }
    scope :anonymous, -> { where(user_id: nil) }
    scope :authenticated, -> { where.not(user_id: nil) }

    # Callbacks
    before_create :set_defaults
    before_create :extract_device_info
    before_create :geolocate_ip
    after_create :increment_presentation_view_count

    # Instance methods
    def bounce?
      duration && duration < 30
    end

    def engaged?
      duration && duration > 120
    end

    def mobile?
      device_type == "mobile"
    end

    def desktop?
      device_type == "desktop"
    end

    def tablet?
      device_type == "tablet"
    end

    def anonymous?
      user_id.nil?
    end

    def engagement_level
      return "unknown" unless duration

      case duration
      when 0..30
        "bounce"
      when 31..120
        "brief"
      when 121..300
        "engaged"
      else
        "highly_engaged"
      end
    end

    def browser_name
      return "Unknown" unless user_agent

      case user_agent.downcase
      when /chrome/
        "Chrome"
      when /firefox/
        "Firefox"
      when /safari/
        "Safari"
      when /edge/
        "Edge"
      when /opera/
        "Opera"
      else
        "Other"
      end
    end

    def operating_system
      return "Unknown" unless user_agent

      case user_agent.downcase
      when /windows/
        "Windows"
      when /macintosh|mac os x/
        "macOS"
      when /linux/
        "Linux"
      when /android/
        "Android"
      when /iphone|ipad/
        "iOS"
      else
        "Other"
      end
    end

    def update_duration(new_duration)
      self.duration = new_duration
      self.completed = true if new_duration > (presentation.estimated_duration || 300) * 0.8
      save
    end

    def mark_completed!
      update(completed: true, completed_at: Time.current)
    end

    def add_interaction(interaction_type, data = {})
      presentation.interactions.create!(
        user: user,
        session_id: session_id,
        interaction_type: interaction_type,
        interaction_data: data,
        created_at: Time.current
      )
    end

    private

    def set_defaults
      self.started_at ||= Time.current
      self.completed ||= false
      self.referrer ||= "direct"
    end

    def extract_device_info
      return unless user_agent

      ua = user_agent.downcase

      self.device_type = if ua.include?("mobile") || ua.include?("android") || ua.include?("iphone")
                          "mobile"
      elsif ua.include?("tablet") || ua.include?("ipad")
                          "tablet"
      else
                          "desktop"
      end

      self.browser = browser_name
      self.os = operating_system
    end

    def geolocate_ip
      return unless ip_address && ip_address != "127.0.0.1"

      begin
        # In a real implementation, you would use a geolocation service
        # like MaxMind GeoIP2 or a similar service
        # For now, we'll set default values
        self.country ||= "Unknown"
        self.region ||= "Unknown"
        self.city ||= "Unknown"
        self.timezone ||= "UTC"
      rescue => e
        Rails.logger.error "Failed to geolocate IP #{ip_address}: #{e.message}"
        self.country = "Unknown"
        self.region = "Unknown"
        self.city = "Unknown"
        self.timezone = "UTC"
      end
    end

    def increment_presentation_view_count
      presentation.increment!(:view_count)
    end
  end
end
