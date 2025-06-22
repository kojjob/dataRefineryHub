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
  validates :message, presence: true
  validates :notification_type, inclusion: { in: TYPES }
  validates :priority, inclusion: { in: PRIORITIES.values }

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(notification_type: type) }
  scope :by_priority, ->(priority) { where(priority: PRIORITIES[priority.to_sym]) }
  scope :high_priority, -> { where(priority: [PRIORITIES[:high], PRIORITIES[:urgent]]) }

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
    when 'data_sync_success', 'data_source_connected', 'extraction_job_completed'
      '✅'
    when 'data_sync_failure', 'data_source_disconnected', 'extraction_job_failed', 'file_processing_failed'
      '❌'
    when 'file_processing_complete'
      '📁'
    when 'user_invited', 'user_role_changed'
      '👤'
    when 'organization_updated'
      '🏢'
    when 'billing_issue'
      '💳'
    when 'payment_success'
      '💰'
    when 'system_maintenance'
      '🔧'
    else
      '📢'
    end
  end

  def color_class
    case priority
    when PRIORITIES[:urgent]
      'bg-red-50 border-red-200 text-red-800'
    when PRIORITIES[:high]
      'bg-orange-50 border-orange-200 text-orange-800'
    when PRIORITIES[:normal]
      'bg-blue-50 border-blue-200 text-blue-800'
    else
      'bg-gray-50 border-gray-200 text-gray-800'
    end
  end

  def self.create_for_data_sync(data_source, success, details = {})
    type = success ? 'data_sync_success' : 'data_sync_failure'
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
    type = success ? 'file_processing_complete' : 'file_processing_failed'
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
end
