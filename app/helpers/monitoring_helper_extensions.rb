
# This file extends the existing monitoring helper with premium features

module MonitoringHelperExtensions
  extend ActiveSupport::Concern

  # Enhanced pipeline status with progress tracking
  def enhanced_pipeline_status_colors(pipeline)
    base_colors = pipeline_status_colors(pipeline.status)
    
    case pipeline.status
    when 'running'
      progress = pipeline.progress_percentage || 0
      if progress > 80
        base_colors.merge(
          bg: 'bg-green-50 border-green-200',
          text: 'text-green-800',
          accent: 'bg-green-500'
        )
      else
        base_colors.merge(accent: 'bg-blue-500')
      end
    when 'pending'
      base_colors.merge(accent: 'bg-yellow-500')
    when 'failed'
      base_colors.merge(accent: 'bg-red-500')
    else
      base_colors.merge(accent: 'bg-gray-500')
    end
  end

  # Premium health score calculation with detailed breakdown
  def detailed_health_breakdown(system_health)
    return {} unless system_health[:checks].present?
    
    breakdown = {
      healthy: 0,
      degraded: 0,
      unhealthy: 0,
      total: system_health[:checks].size
    }
    
    system_health[:checks].each_value do |check|
      case check[:status]
      when 'healthy'
        breakdown[:healthy] += 1
      when 'degraded'
        breakdown[:degraded] += 1
      else
        breakdown[:unhealthy] += 1
      end
    end
    
    breakdown[:health_score] = calculate_health_score(system_health)
    breakdown[:status] = health_status_label(breakdown[:health_score])
    breakdown
  end

  # Enhanced resource usage formatting
  def format_resource_usage(value, unit = '%', precision = 1)
    return '0%' if value.nil?
    
    formatted_value = value.round(precision)
    color_class = case formatted_value
                  when 0..60 then 'text-green-600'
                  when 61..80 then 'text-yellow-600'
                  else 'text-red-600'
                  end
    
    {
      value: formatted_value,
      formatted: "#{formatted_value}#{unit}",
      color_class: color_class,
      status: resource_status_level(formatted_value)
    }
  end

  # Premium alert categorization
  def categorize_alerts_premium(alerts)
    categories = {
      system: { count: 0, severity_breakdown: {} },
      pipeline: { count: 0, severity_breakdown: {} },
      data_quality: { count: 0, severity_breakdown: {} },
      security: { count: 0, severity_breakdown: {} },
      performance: { count: 0, severity_breakdown: {} }
    }
    
    alerts.each do |alert|
      category = alert.alert_type&.to_sym || :system
      next unless categories.key?(category)
      
      categories[category][:count] += 1
      severity = alert.severity
      categories[category][:severity_breakdown][severity] ||= 0
      categories[category][:severity_breakdown][severity] += 1
    end
    
    categories
  end

  # Enhanced timeline event formatting
  def format_timeline_event_premium(event)
    {
      title: event.title,
      description: truncate(event.description, length: 120),
      timestamp: event.occurred_at,
      relative_time: time_ago_in_words(event.occurred_at),
      formatted_time: event.occurred_at.strftime('%H:%M:%S'),
      event_type: event.event_type,
      category: event.event_category,
      icon: timeline_event_icon(event.event_type),
      color_scheme: timeline_color_scheme(event.event_type),
      metadata: format_event_metadata(event.metadata)
    }
  end

  # Real-time metrics formatting for charts
  def format_metrics_for_realtime_chart(metrics, limit = 20)
    return [] unless metrics.present?
    
    metrics.limit(limit).order(:recorded_at).map do |metric|
      {
        timestamp: metric.recorded_at.strftime('%H:%M'),
        cpu: metric.cpu_usage&.round(1) || 0,
        memory: metric.memory_usage&.round(1) || 0,
        storage: metric.storage_usage&.round(1) || 0,
        health_score: calculate_metric_health_score(metric),
        formatted_time: metric.recorded_at.strftime('%m/%d %H:%M')
      }
    end
  end

  # Enhanced performance metrics for dashboard
  def performance_metrics_summary(pipeline_executions)
    return {} unless pipeline_executions.present?
    
    total = pipeline_executions.count
    completed = pipeline_executions.where(status: 'completed').count
    failed = pipeline_executions.where(status: 'failed').count
    avg_duration = pipeline_executions.where.not(completed_at: nil)
                                    .average('EXTRACT(EPOCH FROM (completed_at - started_at))')
    
    {
      total_executions: total,
      success_rate: total > 0 ? ((completed.to_f / total) * 100).round(1) : 0,
      failure_rate: total > 0 ? ((failed.to_f / total) * 100).round(1) : 0,
      avg_duration_minutes: avg_duration ? (avg_duration / 60).round(1) : 0,
      performance_trend: calculate_performance_trend(pipeline_executions)
    }
  end

  # Premium log entry formatting
  def format_log_entries_premium(timeline_events, alerts, limit = 15)
    entries = []
    
    # Enhanced timeline events
    timeline_events.limit(10).each do |event|
      entries << {
        timestamp: event.occurred_at,
        level: log_level_for_event(event.event_type),
        message: "#{event.title}: #{event.description}",
        source: 'timeline',
        category: event.event_category,
        metadata: event.metadata
      }
    end
    
    # Enhanced alerts
    alerts.limit(5).each do |alert|
      entries << {
        timestamp: alert.created_at,
        level: log_level_for_severity(alert.severity),
        message: "Alert: #{alert.title} - #{alert.message}",
        source: 'alert',
        severity: alert.severity,
        alert_type: alert.alert_type
      }
    end
    
    # Sort and format
    entries.sort_by { |e| e[:timestamp] }
           .reverse
           .first(limit)
           .map { |entry| format_log_entry(entry) }
  end

  # System status dashboard summary
  def system_status_summary(system_health, current_metrics, active_pipelines, recent_alerts)
    {
      overall_status: determine_overall_status(system_health, current_metrics, recent_alerts),
      health_score: calculate_health_score(system_health),
      resource_utilization: {
        cpu: format_resource_usage(current_metrics[:cpu_usage]),
        memory: format_resource_usage(current_metrics[:memory_usage]),
        storage: format_resource_usage(current_metrics[:storage_usage])
      },
      pipeline_summary: {
        total_active: active_pipelines.count,
        running: active_pipelines.where(status: 'running').count,
        pending: active_pipelines.where(status: 'pending').count,
        health_status: pipeline_health_status(active_pipelines)
      },
      alert_summary: {
        total_active: recent_alerts.where(status: 'active').count,
        critical: recent_alerts.where(severity: 'critical', status: 'active').count,
        warning: recent_alerts.where(severity: ['high', 'medium'], status: 'active').count,
        trend: alert_trend(recent_alerts)
      }
    }
  end

  private

  def resource_status_level(value)
    case value
    when 0..60 then 'optimal'
    when 61..80 then 'elevated'
    when 81..90 then 'high'
    else 'critical'
    end
  end

  def timeline_event_icon(event_type)
    {
      'pipeline_completed' => 'fas fa-check-circle',
      'pipeline_failed' => 'fas fa-exclamation-triangle',
      'pipeline_started' => 'fas fa-play-circle',
      'data_sync_started' => 'fas fa-sync-alt',
      'data_sync_completed' => 'fas fa-check-double',
      'data_sync_failed' => 'fas fa-times-circle',
      'alert_created' => 'fas fa-bell',
      'alert_resolved' => 'fas fa-check-square',
      'user_login' => 'fas fa-sign-in-alt',
      'configuration_changed' => 'fas fa-cog',
      'error_occurred' => 'fas fa-bug'
    }[event_type] || 'fas fa-info-circle'
  end

  def timeline_color_scheme(event_type)
    success_events = %w[pipeline_completed data_sync_completed alert_resolved]
    error_events = %w[pipeline_failed data_sync_failed error_occurred]
    warning_events = %w[alert_created]
    
    if success_events.include?(event_type)
      { dot: 'bg-green-500', bg: 'bg-green-50', border: 'border-green-200' }
    elsif error_events.include?(event_type)
      { dot: 'bg-red-500', bg: 'bg-red-50', border: 'border-red-200' }
    elsif warning_events.include?(event_type)
      { dot: 'bg-yellow-500', bg: 'bg-yellow-50', border: 'border-yellow-200' }
    else
      { dot: 'bg-blue-500', bg: 'bg-blue-50', border: 'border-blue-200' }
    end
  end

  def format_event_metadata(metadata)
    return {} unless metadata.present?
    
    metadata.transform_values do |value|
      case value
      when Numeric
        number_with_delimiter(value)
      when Time, DateTime
        value.strftime('%H:%M:%S')
      else
        truncate(value.to_s, length: 50)
      end
    end
  end

  def calculate_metric_health_score(metric)
    cpu_score = [100 - metric.cpu_usage.to_f, 0].max
    memory_score = [100 - metric.memory_usage.to_f, 0].max
    storage_score = [100 - metric.storage_usage.to_f, 0].max
    
    ((cpu_score + memory_score + storage_score) / 3).round
  end

  def calculate_performance_trend(executions)
    recent = executions.where(created_at: 7.days.ago..Time.current)
    previous = executions.where(created_at: 14.days.ago..7.days.ago)
    
    return 'stable' if recent.empty? || previous.empty?
    
    recent_success_rate = recent.where(status: 'completed').count.to_f / recent.count
    previous_success_rate = previous.where(status: 'completed').count.to_f / previous.count
    
    difference = recent_success_rate - previous_success_rate
    
    case difference
    when 0.05..Float::INFINITY then 'improving'
    when -0.05..0.05 then 'stable'
    else 'declining'
    end
  end

  def log_level_for_event(event_type)
    case event_type
    when 'pipeline_failed', 'data_sync_failed', 'error_occurred'
      'ERROR'
    when 'alert_created'
      'WARN'
    else
      'INFO'
    end
  end

  def log_level_for_severity(severity)
    case severity
    when 'critical' then 'ERROR'
    when 'high', 'medium' then 'WARN'
    else 'INFO'
    end
  end

  def format_log_entry(entry)
    {
      timestamp: entry[:timestamp],
      level: entry[:level],
      message: truncate(entry[:message], length: 100),
      formatted_time: entry[:timestamp].strftime('%H:%M:%S'),
      color_class: log_level_color_class(entry[:level]),
      metadata: entry[:metadata] || {}
    }
  end

  def log_level_color_class(level)
    {
      'ERROR' => 'text-red-400',
      'WARN' => 'text-yellow-400',
      'INFO' => 'text-blue-400'
    }[level] || 'text-gray-400'
  end

  def determine_overall_status(system_health, current_metrics, recent_alerts)
    health_score = calculate_health_score(system_health)
    critical_alerts = recent_alerts.where(severity: 'critical', status: 'active').count
    
    return 'critical' if health_score < 60 || critical_alerts > 0
    return 'warning' if health_score < 80 || recent_alerts.where(status: 'active').count > 5
    'healthy'
  end

  def pipeline_health_status(pipelines)
    total = pipelines.count
    return 'unknown' if total.zero?
    
    failed = pipelines.where(status: 'failed').count
    failure_rate = (failed.to_f / total) * 100
    
    case failure_rate
    when 0..10 then 'healthy'
    when 11..25 then 'warning'
    else 'critical'
    end
  end

  def alert_trend(alerts)
    current_week = alerts.where(created_at: 7.days.ago..Time.current).count
    previous_week = alerts.where(created_at: 14.days.ago..7.days.ago).count
    
    return 'stable' if previous_week.zero?
    
    change = ((current_week - previous_week).to_f / previous_week) * 100
    
    case change
    when 20..Float::INFINITY then 'increasing'
    when -20..20 then 'stable'
    else 'decreasing'
    end
  end
end

# Include the extensions in the main helper
MonitoringHelper.include(MonitoringHelperExtensions)