# frozen_string_literal: true

module MonitoringHelper
  def calculate_health_score(system_health)
    return 0 unless system_health[:checks].present?

    total_checks = system_health[:checks].size
    healthy_checks = system_health[:checks].values.count { |check| check[:status] == "healthy" }
    degraded_checks = system_health[:checks].values.count { |check| check[:status] == "degraded" }

    # Calculate score: healthy = 100%, degraded = 60%, unhealthy = 0%
    score = (healthy_checks * 100 + degraded_checks * 60) / total_checks.to_f
    score.round
  end

  def calculate_uptime_percentage(system_health)
    return 100.0 unless system_health[:checks].present?

    healthy_count = system_health[:checks].values.count { |check| check[:status] == "healthy" }
    total_count = system_health[:checks].size

    return 100.0 if total_count.zero?

    ((healthy_count.to_f / total_count) * 100).round(2)
  end

  def health_status_class(score)
    if score >= 80
      "bg-green-500"
    elsif score >= 60
      "bg-yellow-500"
    else
      "bg-red-500"
    end
  end

  def health_status_text_class(score)
    if score >= 80
      "text-green-600"
    elsif score >= 60
      "text-yellow-600"
    else
      "text-red-600"
    end
  end

  def health_status_label(score)
    if score >= 80
      "Healthy"
    elsif score >= 60
      "Warning"
    else
      "Critical"
    end
  end

  def count_alerts_by_severity(alerts)
    severities = {
      "critical" => 0,
      "high" => 0,
      "medium" => 0,
      "low" => 0
    }

    alerts.each do |alert|
      severities[alert.severity] ||= 0
      severities[alert.severity] += 1
    end

    # Combine high and medium as "Warning"
    {
      "critical" => severities["critical"],
      "warning" => severities["high"] + severities["medium"],
      "info" => severities["low"]
    }
  end

  def alert_severity_color(severity)
    case severity
    when "critical"
      "bg-red-500"
    when "warning"
      "bg-yellow-500"
    when "info"
      "bg-blue-500"
    else
      "bg-gray-500"
    end
  end

  def alert_severity_text_color(severity)
    case severity
    when "critical"
      "text-red-600"
    when "warning"
      "text-yellow-600"
    when "info"
      "text-blue-600"
    else
      "text-gray-600"
    end
  end

  def resource_metrics_for_chart(metrics)
    return [] unless metrics.present?

    metrics.limit(20).map do |metric|
      {
        timestamp: metric.recorded_at.strftime("%H:%M"),
        cpu: metric.cpu_usage.round(1),
        memory: metric.memory_usage.round(1),
        storage: metric.storage_usage.round(1)
      }
    end
  end

  def generate_log_entries(timeline_events, alerts)
    entries = []

    # Add timeline events as log entries
    timeline_events.limit(10).each do |event|
      level = case event.event_type
      when "pipeline_completed", "data_sync_completed" then "INFO"
      when "pipeline_failed", "data_sync_failed", "error_occurred" then "ERROR"
      when "alert_created" then "WARN"
      else "INFO"
      end

      entries << {
        timestamp: event.occurred_at,
        level: level,
        message: "#{event.title}: #{event.description}"
      }
    end

    # Add alerts as log entries
    alerts.limit(5).each do |alert|
      level = case alert.severity
      when "critical" then "ERROR"
      when "high", "medium" then "WARN"
      else "INFO"
      end

      entries << {
        timestamp: alert.created_at,
        level: level,
        message: "Alert: #{alert.title} - #{alert.message}"
      }
    end

    # Sort by timestamp descending and return
    entries.sort_by { |e| e[:timestamp] }.reverse.first(15)
  end

  def pipeline_status_colors(status)
    case status
    when "running"
      { bg: "bg-green-100", text: "text-green-700", border: "border-green-200" }
    when "pending"
      { bg: "bg-yellow-100", text: "text-yellow-700", border: "border-yellow-200" }
    when "failed"
      { bg: "bg-red-100", text: "text-red-700", border: "border-red-200" }
    else
      { bg: "bg-gray-100", text: "text-gray-700", border: "border-gray-200" }
    end
  end

  def alert_item_class(severity)
    case severity
    when "critical"
      "alert-critical"
    when "high", "medium"
      "alert-warning"
    else
      "alert-info"
    end
  end

  def timeline_event_style(event_type)
    case event_type
    when "pipeline_completed"
      { dot: "timeline-dot-success", bg: "bg-gray-50", icon: "bg-green-500" }
    when "pipeline_failed"
      { dot: "timeline-dot-error", bg: "bg-red-50", icon: "bg-red-500" }
    when "pipeline_started"
      { dot: "timeline-dot-info", bg: "bg-blue-50", icon: "bg-blue-500" }
    when "alert_created"
      { dot: "timeline-dot-warning", bg: "bg-yellow-50", icon: "bg-yellow-500" }
    else
      { dot: "timeline-dot-info", bg: "bg-gray-50", icon: "bg-blue-500" }
    end
  end
end
