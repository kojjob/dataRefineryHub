class MetricsBroadcastJob < ApplicationJob
  queue_as :default
  
  # Run this job every 30 seconds to broadcast live metrics
  def perform
    Organization.active.find_each do |organization|
      begin
        broadcast_organization_metrics(organization)
      rescue StandardError => e
        Rails.logger.error "Failed to broadcast metrics for organization #{organization.id}: #{e.message}"
      end
    end
    
    # Schedule the next run
    self.class.set(wait: 30.seconds).perform_later
  end
  
  private
  
  def broadcast_organization_metrics(organization)
    # Skip if no active WebSocket connections for this organization
    return unless has_active_connections?(organization)
    
    # Gather current metrics
    metrics = calculate_live_metrics(organization)
    
    # Broadcast to dashboard channel
    ActionCable.server.broadcast("dashboard_#{organization.id}", {
      type: 'live_metrics_update',
      timestamp: Time.current.iso8601,
      metrics: metrics
    })
    
    # Check for alerts
    alerts = check_for_alerts(organization, metrics)
    
    alerts.each do |alert|
      RealTimeBroadcastService.broadcast_system_alert(organization, alert)
    end
  end
  
  def has_active_connections?(organization)
    # Check if there are active WebSocket connections for this organization
    # This is a simplified check - in production you might want more sophisticated tracking
    ActionCable.server.connections.any? do |connection|
      connection.current_user&.organization_id == organization.id
    end
  rescue StandardError
    # Assume there are connections if we can't check
    true
  end
  
  def calculate_live_metrics(organization)
    current_time = Time.current
    
    {
      timestamp: current_time.iso8601,
      active_jobs: organization.extraction_jobs.running.count,
      queued_jobs: organization.extraction_jobs.where(status: 'queued').count,
      records_processed_last_minute: organization.raw_data_records
                                                .where('created_at >= ?', 1.minute.ago)
                                                .count,
      records_processed_last_hour: organization.raw_data_records
                                              .where('created_at >= ?', 1.hour.ago)
                                              .count,
      current_processing_rate: calculate_processing_rate(organization),
      system_health: calculate_system_health(organization),
      data_source_stats: calculate_data_source_stats(organization),
      recent_activity: get_recent_activity(organization)
    }
  end
  
  def calculate_processing_rate(organization)
    # Calculate records processed in the last 5 minutes
    recent_records = organization.raw_data_records
                                .where('created_at >= ?', 5.minutes.ago)
                                .count
    
    # Records per minute
    (recent_records / 5.0).round(2)
  end
  
  def calculate_system_health(organization)
    recent_jobs = organization.extraction_jobs.where('created_at >= ?', 1.hour.ago)
    
    return { status: 'unknown', score: 0 } if recent_jobs.empty?
    
    # Calculate health based on multiple factors
    success_rate = recent_jobs.completed.count.to_f / recent_jobs.count
    avg_duration = recent_jobs.completed.average('EXTRACT(EPOCH FROM (completed_at - started_at))')
    stuck_jobs = organization.extraction_jobs.running.where('started_at < ?', 2.hours.ago).count
    
    # Base score from success rate
    health_score = (success_rate * 70).round
    
    # Penalty for long-running jobs
    health_score -= (stuck_jobs * 10)
    
    # Bonus for fast processing
    if avg_duration && avg_duration < 300 # Less than 5 minutes average
      health_score += 10
    end
    
    health_score = [health_score, 0].max # Don't go below 0
    health_score = [health_score, 100].min # Don't go above 100
    
    status = case health_score
             when 90..100 then 'excellent'
             when 75..89 then 'good'
             when 60..74 then 'fair'
             when 40..59 then 'poor'
             else 'critical'
             end
    
    {
      status: status,
      score: health_score,
      success_rate: (success_rate * 100).round(1),
      avg_duration_seconds: avg_duration&.round(2),
      stuck_jobs_count: stuck_jobs
    }
  end
  
  def calculate_data_source_stats(organization)
    data_sources = organization.data_sources.includes(:extraction_jobs)
    
    {
      total: data_sources.count,
      connected: data_sources.connected.count,
      syncing: data_sources.joins(:extraction_jobs)
                           .where(extraction_jobs: { status: 'running' })
                           .distinct
                           .count,
      with_errors: data_sources.joins(:extraction_jobs)
                              .where(extraction_jobs: { status: 'failed' })
                              .where('extraction_jobs.created_at >= ?', 24.hours.ago)
                              .distinct
                              .count,
      by_platform: data_sources.group(:platform).count
    }
  end
  
  def get_recent_activity(organization)
    organization.extraction_jobs
               .includes(:data_source)
               .where('updated_at >= ?', 5.minutes.ago)
               .order(updated_at: :desc)
               .limit(10)
               .map do |job|
      {
        id: job.id,
        data_source_name: job.data_source.name,
        status: job.status,
        updated_at: job.updated_at.iso8601,
        records_processed: job.records_processed || 0
      }
    end
  end
  
  def check_for_alerts(organization, metrics)
    alerts = []
    
    # Check for stuck jobs
    if metrics.dig(:system_health, :stuck_jobs_count).to_i > 0
      alerts << {
        type: 'stuck_jobs',
        severity: 'warning',
        message: "#{metrics[:system_health][:stuck_jobs_count]} job(s) running for over 2 hours",
        timestamp: Time.current.iso8601
      }
    end
    
    # Check for low system health
    health_score = metrics.dig(:system_health, :score).to_i
    if health_score < 50
      alerts << {
        type: 'low_system_health',
        severity: health_score < 25 ? 'critical' : 'warning',
        message: "System health is #{metrics[:system_health][:status]} (#{health_score}%)",
        timestamp: Time.current.iso8601
      }
    end
    
    # Check for high error rate in data sources
    error_sources = metrics.dig(:data_source_stats, :with_errors).to_i
    total_sources = metrics.dig(:data_source_stats, :total).to_i
    
    if total_sources > 0 && error_sources > (total_sources * 0.3)
      alerts << {
        type: 'high_error_rate',
        severity: 'warning',
        message: "#{error_sources} of #{total_sources} data sources have recent errors",
        timestamp: Time.current.iso8601
      }
    end
    
    # Check processing rate anomalies
    current_rate = metrics[:current_processing_rate].to_f
    if current_rate > 0 && should_check_rate_anomaly?(organization)
      historical_rate = calculate_historical_processing_rate(organization)
      
      if historical_rate > 0 && current_rate < (historical_rate * 0.5)
        alerts << {
          type: 'low_processing_rate',
          severity: 'warning',
          message: "Processing rate is significantly lower than usual (#{current_rate} vs #{historical_rate} records/min)",
          timestamp: Time.current.iso8601
        }
      end
    end
    
    alerts
  end
  
  def should_check_rate_anomaly?(organization)
    # Only check rate anomalies during business hours or if there's active processing
    current_hour = Time.current.hour
    business_hours = (9..17).include?(current_hour)
    has_active_jobs = organization.extraction_jobs.running.exists?
    
    business_hours || has_active_jobs
  end
  
  def calculate_historical_processing_rate(organization)
    # Calculate average processing rate for the same time period over the last week
    current_time = Time.current
    week_ago = 1.week.ago
    
    # Get the same 5-minute window from each day in the past week
    historical_counts = (1..7).map do |days_ago|
      time_start = current_time - days_ago.days - 5.minutes
      time_end = current_time - days_ago.days
      
      organization.raw_data_records
                 .where(created_at: time_start..time_end)
                 .count
    end
    
    avg_historical = historical_counts.sum / 7.0
    (avg_historical / 5.0).round(2) # Convert to per-minute rate
  end
end