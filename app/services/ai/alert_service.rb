# AI Alert Service
# Handles alert management and notifications for the organization

module Ai
  class AlertService
    include Singleton

    attr_reader :organization

    def initialize(organization:)
      @organization = organization
    end

    # Fetch active alerts for the organization
    def fetch_active_alerts
      alerts = organization.alerts
                          .active
                          .includes(:data_source, :user)
                          .order(created_at: :desc)
                          .limit(10)

      alerts.map do |alert|
        {
          id: alert.id,
          type: alert.alert_type,
          message: alert.message,
          severity: alert.severity,
          source: alert.data_source&.name || "System",
          created_at: alert.created_at,
          acknowledged: alert.acknowledged?,
          url: generate_alert_url(alert)
        }
      end
    rescue => e
      Rails.logger.error "Failed to fetch active alerts: #{e.message}"
      []
    end

    # Create a new alert
    def create_alert(alert_params)
      alert = organization.alerts.build(alert_params)

      if alert.save
        notify_stakeholders(alert) if alert.severity == "critical"
        alert
      else
        Rails.logger.error "Failed to create alert: #{alert.errors.full_messages.join(', ')}"
        nil
      end
    rescue => e
      Rails.logger.error "Failed to create alert: #{e.message}"
      nil
    end

    # Acknowledge an alert
    def acknowledge_alert(alert_id, user_id)
      alert = organization.alerts.find_by(id: alert_id)
      return false unless alert

      alert.update(
        acknowledged: true,
        acknowledged_by: user_id,
        acknowledged_at: Time.current
      )
    rescue => e
      Rails.logger.error "Failed to acknowledge alert #{alert_id}: #{e.message}"
      false
    end

    # Get alert statistics
    def get_alert_stats(time_range = 7.days.ago..Time.current)
      alerts = organization.alerts.where(created_at: time_range)

      {
        total: alerts.count,
        critical: alerts.where(severity: "critical").count,
        warning: alerts.where(severity: "warning").count,
        info: alerts.where(severity: "info").count,
        acknowledged: alerts.where(acknowledged: true).count,
        pending: alerts.where(acknowledged: false).count
      }
    rescue => e
      Rails.logger.error "Failed to get alert stats: #{e.message}"
      {
        total: 0,
        critical: 0,
        warning: 0,
        info: 0,
        acknowledged: 0,
        pending: 0
      }
    end

    # Check for data quality alerts
    def check_data_quality_alerts
      data_sources = organization.data_sources.active
      alerts_created = []

      data_sources.each do |data_source|
        # Check for data freshness
        if data_stale?(data_source)
          alert = create_data_freshness_alert(data_source)
          alerts_created << alert if alert
        end

        # Check for data volume anomalies
        if data_volume_anomaly?(data_source)
          alert = create_data_volume_alert(data_source)
          alerts_created << alert if alert
        end

        # Check for data quality issues
        if data_quality_issues?(data_source)
          alert = create_data_quality_alert(data_source)
          alerts_created << alert if alert
        end
      end

      alerts_created
    rescue => e
      Rails.logger.error "Failed to check data quality alerts: #{e.message}"
      []
    end

    # Check for performance alerts
    def check_performance_alerts
      presentations = organization.presentations.active
      alerts_created = []

      presentations.each do |presentation|
        # Check load time performance
        if slow_performance?(presentation)
          alert = create_performance_alert(presentation)
          alerts_created << alert if alert
        end

        # Check error rates
        if high_error_rate?(presentation)
          alert = create_error_rate_alert(presentation)
          alerts_created << alert if alert
        end
      end

      alerts_created
    rescue => e
      Rails.logger.error "Failed to check performance alerts: #{e.message}"
      []
    end

    private

    def generate_alert_url(alert)
      case alert.alert_type
      when "data_quality"
        "/data_sources/#{alert.data_source_id}/quality"
      when "performance"
        "/presentations/#{alert.presentation_id}/analytics"
      when "system"
        "/admin/system_health"
      else
        "/alerts/#{alert.id}"
      end
    end

    def notify_stakeholders(alert)
      # Send notifications to relevant stakeholders
      stakeholders = organization.users.where(role: [ "admin", "manager" ])

      stakeholders.each do |user|
        AlertMailer.critical_alert_notification(user, alert).deliver_later
      end

      # Send to Slack/Teams if configured
      send_slack_notification(alert) if organization.slack_webhook_url.present?
    rescue => e
      Rails.logger.error "Failed to notify stakeholders for alert #{alert.id}: #{e.message}"
    end

    def send_slack_notification(alert)
      # Implementation for Slack notification
      # This would use the organization's Slack webhook URL
    end

    # Data quality check methods
    def data_stale?(data_source)
      return false unless data_source.last_updated_at

      threshold = PresentationConfig.get("monitoring.data_freshness_threshold", 24).hours
      data_source.last_updated_at < threshold.ago
    end

    def data_volume_anomaly?(data_source)
      recent_volume = data_source.daily_volumes.last(7).sum
      historical_avg = data_source.daily_volumes.last(30).sum / 30.0

      return false if historical_avg.zero?

      deviation = (recent_volume - historical_avg).abs / historical_avg
      deviation > PresentationConfig.get("monitoring.volume_anomaly_threshold", 0.5)
    end

    def data_quality_issues?(data_source)
      quality_score = data_source.latest_quality_score
      return false unless quality_score

      threshold = PresentationConfig.get("monitoring.quality_threshold", 0.8)
      quality_score < threshold
    end

    # Performance check methods
    def slow_performance?(presentation)
      avg_load_time = presentation.performance_logs
                                 .where("created_at > ?", 1.hour.ago)
                                 .average(:load_time)

      return false unless avg_load_time

      threshold = PresentationConfig.get("performance.load_time_threshold", 3.0)
      avg_load_time > threshold
    end

    def high_error_rate?(presentation)
      total_requests = presentation.performance_logs
                                  .where("created_at > ?", 1.hour.ago)
                                  .count

      return false if total_requests.zero?

      error_count = presentation.performance_logs
                                .where("created_at > ?", 1.hour.ago)
                                .where(status: "error")
                                .count

      error_rate = error_count.to_f / total_requests
      threshold = PresentationConfig.get("performance.error_rate_threshold", 0.05)

      error_rate > threshold
    end

    # Alert creation methods
    def create_data_freshness_alert(data_source)
      create_alert(
        alert_type: "data_quality",
        severity: "warning",
        message: "Data source '#{data_source.name}' has stale data. Last updated: #{data_source.last_updated_at&.strftime('%Y-%m-%d %H:%M')}",
        data_source: data_source,
        metadata: {
          last_updated: data_source.last_updated_at,
          threshold_hours: PresentationConfig.get("monitoring.data_freshness_threshold", 24)
        }
      )
    end

    def create_data_volume_alert(data_source)
      create_alert(
        alert_type: "data_quality",
        severity: "warning",
        message: "Data volume anomaly detected in '#{data_source.name}'",
        data_source: data_source,
        metadata: {
          recent_volume: data_source.daily_volumes.last(7).sum,
          historical_average: data_source.daily_volumes.last(30).sum / 30.0
        }
      )
    end

    def create_data_quality_alert(data_source)
      create_alert(
        alert_type: "data_quality",
        severity: "critical",
        message: "Data quality issues detected in '#{data_source.name}'. Quality score: #{data_source.latest_quality_score}",
        data_source: data_source,
        metadata: {
          quality_score: data_source.latest_quality_score,
          threshold: PresentationConfig.get("monitoring.quality_threshold", 0.8)
        }
      )
    end

    def create_performance_alert(presentation)
      avg_load_time = presentation.performance_logs
                                 .where("created_at > ?", 1.hour.ago)
                                 .average(:load_time)

      create_alert(
        alert_type: "performance",
        severity: "warning",
        message: "Slow performance detected in presentation '#{presentation.title}'. Average load time: #{avg_load_time.round(2)}s",
        presentation: presentation,
        metadata: {
          avg_load_time: avg_load_time,
          threshold: PresentationConfig.get("performance.load_time_threshold", 3.0)
        }
      )
    end

    def create_error_rate_alert(presentation)
      total_requests = presentation.performance_logs
                                  .where("created_at > ?", 1.hour.ago)
                                  .count

      error_count = presentation.performance_logs
                                .where("created_at > ?", 1.hour.ago)
                                .where(status: "error")
                                .count

      error_rate = (error_count.to_f / total_requests * 100).round(2)

      create_alert(
        alert_type: "performance",
        severity: "critical",
        message: "High error rate detected in presentation '#{presentation.title}'. Error rate: #{error_rate}%",
        presentation: presentation,
        metadata: {
          error_rate: error_rate,
          error_count: error_count,
          total_requests: total_requests,
          threshold: PresentationConfig.get("performance.error_rate_threshold", 0.05) * 100
        }
      )
    end
  end
end
