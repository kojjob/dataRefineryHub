# frozen_string_literal: true

class NotificationService
  class << self
    def create_notification(user:, type:, title:, message:, data: {})
      # Enhanced notification creation with persistence
      priority_value = determine_priority_value(type)
      
      # Create notification in database
      notification = Notification.create!(
        user: user,
        organization: user.organization,
        notification_type: type,
        title: title,
        message: message,
        metadata: data,
        priority: priority_value
      )

      # Log the notification with structured data
      Rails.logger.info do
        "NOTIFICATION_CREATED: #{type} for user #{user.id} - #{title}: #{message} | " \
        "Data: #{data.to_json} | Priority: #{notification.priority_name}"
      end

      # Broadcast real-time notification
      broadcast_notification(user, notification)

      # Send additional alerts for high-priority notifications
      send_additional_alerts(user, notification) if notification.high_priority?

      notification
    end

    def broadcast_notification(user, notification)
      broadcast_data = {
        type: "notification",
        id: notification.id,
        notification_type: notification.notification_type,
        title: notification.title,
        message: notification.message,
        data: notification.metadata,
        timestamp: notification.created_at.iso8601,
        read: notification.read?,
        priority: notification.priority_name,
        icon: notification.icon
      }

      # Broadcast to user-specific channel
      ActionCable.server.broadcast("user_#{user.id}", broadcast_data)

      # Also broadcast to organization dashboard if user has organization
      if user.organization
        ActionCable.server.broadcast("dashboard_#{user.organization.id}", broadcast_data)
      end
    end

    def mark_as_read(user:, notification_id:)
      # Implementation for marking notification as read
      Rails.logger.info "Marking notification #{notification_id} as read for user #{user.id}"
      
      notification = user.notifications.find_by(id: notification_id)
      notification&.mark_as_read!
    end

    def get_unread_count(user)
      # Implementation for getting unread notification count
      user.notifications.unread.count
    end

    def get_recent_notifications(user, limit: 10)
      # Implementation for getting recent notifications
      user.notifications.recent.limit(limit)
    end

    private

    def store_notification_enhanced(user, notification_data)
      # Generate unique ID for notification
      notification_id = SecureRandom.uuid
      enhanced_notification = notification_data.merge(
        id: notification_id,
        expires_at: Time.current + 30.days,
        metadata: {
          ip_address: extract_ip_from_context,
          user_agent: extract_user_agent_from_context,
          organization_id: user.organization&.id
        }
      )

      # Store in Rails cache with enhanced structure
      cache_key = "user_notifications_#{user.id}"
      cached_notifications = Rails.cache.read(cache_key) || []

      # Add new notification to the beginning
      cached_notifications.unshift(enhanced_notification)

      # Keep only last 100 notifications (increased limit)
      cached_notifications = cached_notifications.first(100)

      # Store back in cache with extended expiry
      Rails.cache.write(cache_key, cached_notifications, expires_in: 30.days)

      # Also store individual notification for quick lookup
      Rails.cache.write("notification_#{notification_id}", enhanced_notification, expires_in: 30.days)

      # Update notification counters
      update_notification_counters(user, enhanced_notification)

      enhanced_notification
    end

    def determine_priority(notification_type)
      case notification_type
      when "file_processing_failed", "circuit_breaker_open", "data_validation_critical"
        "high"
      when "file_processing_completed", "data_quality_warning"
        "medium"
      when "sync_scheduled", "data_source_connected"
        "low"
      else
        "medium"
      end
    end

    def determine_priority_value(notification_type)
      priority_name = determine_priority(notification_type)
      Notification::PRIORITIES[priority_name.to_sym] || Notification::PRIORITIES[:normal]
    end

    def categorize_notification(notification_type)
      case notification_type
      when /processing/
        "processing"
      when /validation/
        "data_quality"
      when /sync/
        "synchronization"
      when /connection/, /source/
        "data_source"
      when /circuit_breaker/
        "system"
      else
        "general"
      end
    end

    def send_additional_alerts(user, notification)
      # For high-priority notifications, send additional alerts
      category = categorize_notification(notification.notification_type)
      
      case category
      when "system"
        # System alerts could trigger external monitoring
        Rails.logger.error "HIGH_PRIORITY_SYSTEM_ALERT: #{notification.title} for user #{user.id}"

        # Could integrate with external alerting (Slack, PagerDuty, etc.)
        send_external_alert(user, notification) if Rails.env.production?

      when "processing"
        # Critical processing failures
        if notification.notification_type == "file_processing_failed"
          retry_count = notification.metadata&.dig("retry_count") || 0
          if retry_count >= 3
            Rails.logger.error "PROCESSING_FAILURE_THRESHOLD_EXCEEDED: #{notification.title} for user #{user.id}"
          end
        end
      end

      # Broadcast to admin channels for high-priority alerts
      broadcast_admin_alert(user, notification)
    end

    def broadcast_admin_alert(user, notification)
      # Broadcast high-priority alerts to admin monitoring channels
      admin_alert_data = {
        type: "admin_alert",
        alert_level: "high",
        user_id: user.id,
        organization_id: user.organization&.id,
        notification: {
          id: notification.id,
          type: notification.notification_type,
          title: notification.title,
          message: notification.message,
          category: categorize_notification(notification.notification_type)
        },
        timestamp: Time.current.iso8601
      }

      # Broadcast to system admin channel
      ActionCable.server.broadcast("admin_alerts", admin_alert_data)

      # Organization admins
      if user.organization
        ActionCable.server.broadcast("org_admin_#{user.organization.id}", admin_alert_data)
      end
    end

    def send_external_alert(user, notification)
      # Placeholder for external alerting integrations
      # Could integrate with Slack, Teams, PagerDuty, etc.
      Rails.logger.info "EXTERNAL_ALERT_TRIGGERED: #{notification[:title]} for user #{user.id}"
    end

    def update_notification_counters(user, notification)
      # Update notification counters for quick access
      counter_key = "notification_counters_#{user.id}"
      counters = Rails.cache.read(counter_key) || {
        total: 0,
        unread: 0,
        by_category: {},
        by_priority: { high: 0, medium: 0, low: 0 }
      }

      counters[:total] += 1
      counters[:unread] += 1
      counters[:by_category][notification[:category]] = (counters[:by_category][notification[:category]] || 0) + 1
      counters[:by_priority][notification[:priority].to_sym] += 1

      Rails.cache.write(counter_key, counters, expires_in: 30.days)
    end

    def extract_ip_from_context
      # Extract IP from current request context if available
      if defined?(Current) && Current.respond_to?(:request)
        Current.request&.remote_ip
      else
        nil
      end
    end

    def extract_user_agent_from_context
      # Extract user agent from current request context if available
      if defined?(Current) && Current.respond_to?(:request)
        Current.request&.user_agent
      else
        nil
      end
    end
  end
end
