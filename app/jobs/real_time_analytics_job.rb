# frozen_string_literal: true

class RealTimeAnalyticsJob < ApplicationJob
  queue_as :ai_monitoring

  # Run continuously until stopped
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(organization_id, monitoring_duration = nil)
    @organization = Organization.find(organization_id)
    @analytics_service = Ai::RealTimeAnalyticsService.new(organization: @organization)

    Rails.logger.info "Starting real-time analytics monitoring for #{@organization.name}"

    # Set monitoring duration (default: run indefinitely)
    end_time = monitoring_duration ? Time.current + monitoring_duration : nil

    begin
      monitor_loop(end_time)
    rescue => e
      Rails.logger.error "Real-time analytics monitoring failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      # Send error notification
      send_monitoring_error_notification(e)

      raise e
    end
  end

  private

  def monitor_loop(end_time = nil)
    loop do
      # Check if we should stop monitoring
      break if end_time && Time.current >= end_time
      break if should_stop_monitoring?

      # Perform monitoring cycle
      perform_monitoring_cycle

      # Wait before next cycle (5 minutes)
      sleep(5.minutes)
    end

    Rails.logger.info "Real-time analytics monitoring stopped for #{@organization.name}"
  end

  def perform_monitoring_cycle
    Rails.logger.debug "Performing real-time analytics cycle for #{@organization.name}"

    begin
      # Get current dashboard data
      dashboard_data = @analytics_service.get_real_time_dashboard_data

      # Check for anomalies
      anomalies = dashboard_data[:anomalies] || []

      # Process any new anomalies
      process_anomalies(anomalies)

      # Check for critical alerts
      alerts = dashboard_data[:alerts] || []
      process_critical_alerts(alerts)

      # Generate real-time insights
      insights = @analytics_service.generate_real_time_insights
      process_insights(insights)

      # Broadcast updates via ActionCable
      broadcast_dashboard_updates(dashboard_data)

      # Store metrics for historical analysis
      store_metrics_snapshot(dashboard_data[:metrics])

    rescue => e
      Rails.logger.error "Monitoring cycle error: #{e.message}"
      # Continue monitoring even if one cycle fails
    end
  end

  def process_anomalies(anomalies)
    return if anomalies.empty?

    Rails.logger.info "Processing #{anomalies.count} anomalies for #{@organization.name}"

    anomalies.each do |anomaly|
      # Create smart alerts for significant anomalies
      if should_create_alert_for_anomaly?(anomaly)
        alert = @analytics_service.create_smart_alert(anomaly)

        if alert
          # Send notifications for critical alerts
          send_anomaly_notification(alert) if alert[:severity].in?(%w[high critical])

          # Log the alert
          Rails.logger.warn "Alert created for #{@organization.name}: #{alert[:title]}"
        end
      end
    end
  end

  def process_critical_alerts(alerts)
    critical_alerts = alerts.select { |alert| alert[:severity] == "critical" }
    return if critical_alerts.empty?

    Rails.logger.warn "Processing #{critical_alerts.count} critical alerts for #{@organization.name}"

    critical_alerts.each do |alert|
      # Send immediate notifications for critical alerts
      send_critical_alert_notification(alert)

      # Auto-escalate if alert persists
      schedule_alert_escalation(alert)
    end
  end

  def process_insights(insights)
    return unless insights[:insights]&.any?

    # Look for actionable insights
    actionable_insights = insights[:insights].select do |insight|
      insight[:impact_score] && insight[:impact_score] > 7
    end

    if actionable_insights.any?
      Rails.logger.info "Found #{actionable_insights.count} high-impact insights for #{@organization.name}"

      # Send insight notifications for high-impact insights
      send_insights_notification(actionable_insights)
    end
  end

  def broadcast_dashboard_updates(dashboard_data)
    # Broadcast to organization-specific channel
    ActionCable.server.broadcast(
      "real_time_analytics_#{@organization.id}",
      {
        type: "dashboard_update",
        data: dashboard_data,
        timestamp: Time.current.iso8601
      }
    )
  end

  def store_metrics_snapshot(metrics)
    return unless metrics

    # Store metrics snapshot for historical analysis
    # In production, this would save to a metrics table
    Rails.logger.debug "Storing metrics snapshot: #{metrics.keys.join(', ')}"

    # Example metrics storage (would be implemented with actual model)
    begin
      MetricsSnapshot.create!(
        organization: @organization,
        metrics_data: metrics,
        captured_at: Time.current
      ) if defined?(MetricsSnapshot)
    rescue => e
      Rails.logger.warn "Failed to store metrics snapshot: #{e.message}"
    end
  end

  def should_stop_monitoring?
    # Check if monitoring should be stopped
    # This could check a Redis flag, database setting, etc.

    # For now, check if organization is still active
    @organization.reload
    !@organization.active?
  end

  def should_create_alert_for_anomaly?(anomaly)
    # Business logic to determine if anomaly warrants an alert
    return false unless anomaly[:current_value]

    # Don't alert for minor revenue anomalies
    if anomaly[:metric] == "revenue" && anomaly[:current_value] < 50
      return false
    end

    # Don't alert for minor customer activity changes
    if anomaly[:metric] == "customers" && anomaly[:current_value] < 5
      return false
    end

    # Alert for processing performance issues
    if anomaly[:metric] == "processing_performance" && anomaly[:current_value] < 70
      return true
    end

    # Default: alert for significant deviations
    deviation = anomaly[:deviation] || 0
    deviation > 2.0
  end

  def send_anomaly_notification(alert)
    # Send notification for anomaly alert
    Rails.logger.info "Sending anomaly notification: #{alert[:title]}"

    # This would integrate with notification service
    if defined?(NotificationService)
      NotificationService.new.send_anomaly_alert(
        organization: @organization,
        alert: alert
      )
    end
  end

  def send_critical_alert_notification(alert)
    # Send immediate notification for critical alert
    Rails.logger.warn "Sending critical alert notification: #{alert[:title]}"

    # This would send immediate notifications (email, SMS, Slack, etc.)
    if defined?(NotificationService)
      NotificationService.new.send_critical_alert(
        organization: @organization,
        alert: alert,
        channels: %w[email sms slack] # Multiple channels for critical alerts
      )
    end
  end

  def send_insights_notification(insights)
    # Send notification for high-impact insights
    Rails.logger.info "Sending insights notification for #{insights.count} insights"

    if defined?(NotificationService)
      NotificationService.new.send_insights_summary(
        organization: @organization,
        insights: insights
      )
    end
  end

  def send_monitoring_error_notification(error)
    # Send notification when monitoring fails
    Rails.logger.error "Sending monitoring error notification: #{error.message}"

    if defined?(NotificationService)
      NotificationService.new.send_system_alert(
        organization: @organization,
        error: error,
        system: "real_time_analytics"
      )
    end
  end

  def schedule_alert_escalation(alert)
    # Schedule escalation for persistent critical alerts
    RealTimeAlertEscalationJob.perform_in(
      30.minutes,
      @organization.id,
      alert[:id]
    ) if defined?(RealTimeAlertEscalationJob)
  end
end
