class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :organization
  belongs_to :notifiable, polymorphic: true, optional: true

  TYPES = %w[
    data_sync_success data_sync_failure data_source_connected data_source_disconnected
    file_processing_complete file_processing_failed extraction_job_completed
    extraction_job_failed user_invited user_role_changed organization_updated
    billing_issue payment_success system_maintenance
  ].freeze

  PRIORITIES = {
    low: 0,
    normal: 1,
    high: 2,
    urgent: 3
  }.freeze

  validates :title, presence: true, length: { maximum: 255 }
  validates :message, presence: true, length: { maximum: 5000 }
  validates :notification_type, inclusion: { in: TYPES }
  validates :priority, inclusion: { in: PRIORITIES.values }

  # Security validations
  validate :title_safe_content
  validate :message_safe_content
  validate :metadata_safe_content

  # Sanitize content before saving
  before_validation :sanitize_content

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(notification_type: type) }
  scope :by_priority, ->(priority) { where(priority: PRIORITIES[priority.to_sym]) }
  scope :high_priority, -> { where(priority: [ PRIORITIES[:high], PRIORITIES[:urgent] ]) }

  def read?
    read_at.present?
  end

  def unread?
    !read?
  end

  def mark_as_read!
    update!(read_at: Time.current) unless read?
  end

  def mark_as_unread!
    update!(read_at: nil) if read?
  end

  def priority_name
    PRIORITIES.key(priority)
  end

  def high_priority?
    priority >= PRIORITIES[:high]
  end

  def icon
    case notification_type
    when "data_sync_success", "data_source_connected", "extraction_job_completed"
      "✅"
    when "data_sync_failure", "data_source_disconnected", "extraction_job_failed", "file_processing_failed"
      "❌"
    when "file_processing_complete"
      "📁"
    when "user_invited", "user_role_changed"
      "👤"
    when "organization_updated"
      "🏢"
    when "billing_issue"
      "💳"
    when "payment_success"
      "💰"
    when "system_maintenance"
      "🔧"
    else
      "📢"
    end
  end

  def color_class
    case priority
    when PRIORITIES[:urgent]
      "bg-red-50 border-red-200 text-red-800"
    when PRIORITIES[:high]
      "bg-orange-50 border-orange-200 text-orange-800"
    when PRIORITIES[:normal]
      "bg-blue-50 border-blue-200 text-blue-800"
    else
      "bg-gray-50 border-gray-200 text-gray-800"
    end
  end

  def self.create_for_data_sync(data_source, success, details = {})
    type = success ? "data_sync_success" : "data_sync_failure"
    priority = success ? PRIORITIES[:normal] : PRIORITIES[:high]

    title = if success
      "Data sync completed for #{data_source.name}"
    else
      "Data sync failed for #{data_source.name}"
    end

    message = if success
      "Successfully synced #{details[:records_count] || 0} records"
    else
      "Sync failed: #{details[:error_message] || 'Unknown error'}"
    end

    # Create notification for all organization users who can view data sources
    data_source.organization.users.each do |user|
      next unless user.can_view_analytics?

      create!(
        user: user,
        organization: data_source.organization,
        notifiable: data_source,
        title: title,
        message: message,
        notification_type: type,
        priority: priority,
        metadata: details
      )
    end
  end

  def self.create_for_file_processing(data_source, file_name, success, details = {})
    type = success ? "file_processing_complete" : "file_processing_failed"
    priority = success ? PRIORITIES[:normal] : PRIORITIES[:high]

    title = if success
      "File processing completed"
    else
      "File processing failed"
    end

    message = if success
      "Successfully processed #{file_name} with #{details[:records_count] || 0} records"
    else
      "Failed to process #{file_name}: #{details[:error_message] || 'Unknown error'}"
    end

    data_source.organization.users.each do |user|
      create!(
        user: user,
        organization: data_source.organization,
        notifiable: data_source,
        title: title,
        message: message,
        notification_type: type,
        priority: priority,
        metadata: details.merge(file_name: file_name)
      )
    end
  end

  private

  # SECURITY METHODS: Input validation and sanitization

  def sanitize_content
    self.title = sanitize_text(title) if title.present?
    self.message = sanitize_text(message) if message.present?
    self.metadata = sanitize_metadata_hash(metadata) if metadata.present?
  end

  def sanitize_text(text)
    return nil if text.blank?

    # Strip HTML tags, normalize whitespace, and remove dangerous content
    sanitized = ActionController::Base.helpers.strip_tags(text.to_s).squish

    # Remove common injection patterns
    sanitized = sanitized.gsub(/javascript:/i, "")
    sanitized = sanitized.gsub(/data:/i, "")
    sanitized = sanitized.gsub(/vbscript:/i, "")
    sanitized = sanitized.gsub(/<script[^>]*>.*?<\/script>/mi, "")
    sanitized = sanitized.gsub(/on\w+\s*=/i, "")

    # Limit character sets to prevent encoding attacks
    sanitized.gsub(/[^\p{L}\p{N}\p{P}\p{S}\p{Z}]/u, "")
  end

  def sanitize_metadata_hash(data)
    return {} if data.blank?

    case data
    when Hash
      sanitized = {}
      data.each do |key, value|
        sanitized_key = sanitize_metadata_key(key)
        sanitized_value = sanitize_metadata_value(value)
        sanitized[sanitized_key] = sanitized_value
      end
      sanitized.slice(*allowed_metadata_keys) # Only keep allowed keys
    else
      # Convert non-hash metadata to safe hash
      { "data" => sanitize_metadata_value(data) }
    end
  end

  def sanitize_metadata_key(key)
    key.to_s.gsub(/[^a-zA-Z0-9_]/, "_").truncate(50)
  end

  def sanitize_metadata_value(value)
    case value
    when String
      sanitize_text(value)
    when Hash
      sanitize_metadata_hash(value)
    when Array
      value.map { |v| sanitize_metadata_value(v) }.first(10) # Limit array size
    when Numeric, TrueClass, FalseClass, NilClass
      value
    else
      value.to_s.truncate(100) # Convert complex objects to string
    end
  end

  def allowed_metadata_keys
    %w[
      records_count error_message file_name retry_count duration
      source_type sync_type organization_id user_id data_source_id
      file_size processing_time error_code status timestamp
      api_calls_used storage_used bandwidth_used
    ]
  end

  # Validation methods for security
  def title_safe_content
    return unless title.present?

    if contains_dangerous_content?(title)
      errors.add(:title, "contains invalid or potentially dangerous content")
    end
  end

  def message_safe_content
    return unless message.present?

    if contains_dangerous_content?(message)
      errors.add(:message, "contains invalid or potentially dangerous content")
    end
  end

  def metadata_safe_content
    return unless metadata.present?

    if metadata.is_a?(Hash)
      metadata.each do |key, value|
        if contains_dangerous_content?(value.to_s)
          errors.add(:metadata, "contains invalid content in #{key}")
          break
        end
      end
    end

    # Check metadata size
    if metadata.to_json.bytesize > 10.kilobytes
      errors.add(:metadata, "is too large (maximum 10KB)")
    end
  end

  def contains_dangerous_content?(text)
    return false if text.blank?

    dangerous_patterns = [
      /<script[^>]*>/i,
      /javascript:/i,
      /data:text\/html/i,
      /vbscript:/i,
      /<iframe[^>]*>/i,
      /<object[^>]*>/i,
      /<embed[^>]*>/i,
      /<link[^>]*>/i,
      /<meta[^>]*>/i,
      /on\w+\s*=/i, # Event handlers like onclick, onload, etc.
      /expression\s*\(/i, # CSS expressions
      /url\s*\(/i, # CSS url() functions
      /@import/i # CSS imports
    ]

    dangerous_patterns.any? { |pattern| text.match?(pattern) }
  end
end
