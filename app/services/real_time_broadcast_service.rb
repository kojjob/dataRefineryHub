class RealTimeBroadcastService
  class << self
    
    # Broadcast dashboard metrics updates
    def broadcast_dashboard_update(organization)
      data = {
        type: 'dashboard_update',
        timestamp: Time.current.iso8601,
        data: calculate_dashboard_metrics(organization)
      }
      
      ActionCable.server.broadcast("dashboard_#{organization.id}", data)
    end
    
    # Broadcast extraction job status changes
    def broadcast_job_status_change(extraction_job, event_type = 'updated')
      organization = extraction_job.data_source.organization
      
      # Broadcast to dashboard channel
      dashboard_data = {
        type: 'job_status_change',
        timestamp: Time.current.iso8601,
        event_type: event_type,
        job: serialize_job_for_broadcast(extraction_job)
      }
      
      ActionCable.server.broadcast("dashboard_#{organization.id}", dashboard_data)
      
      # Broadcast to data sources channel
      data_source_data = {
        type: 'sync_status_update',
        timestamp: Time.current.iso8601,
        event_type: event_type,
        data_source_id: extraction_job.data_source_id,
        job: serialize_job_for_broadcast(extraction_job)
      }
      
      ActionCable.server.broadcast("data_sources_#{organization.id}", data_source_data)
      ActionCable.server.broadcast("data_source_#{extraction_job.data_source_id}", data_source_data)
      
      # Broadcast to specific job channel
      ActionCable.server.broadcast("extraction_job_#{extraction_job.id}", {
        type: 'job_progress_update',
        timestamp: Time.current.iso8601,
        job: serialize_job_for_broadcast(extraction_job)
      })
    end
    
    # Broadcast job progress updates
    def broadcast_job_progress(extraction_job)
      progress_data = {
        type: 'job_progress',
        timestamp: Time.current.iso8601,
        job_id: extraction_job.id,
        progress: {
          records_processed: extraction_job.records_processed,
          progress_percentage: calculate_job_progress(extraction_job),
          processing_rate: calculate_processing_rate(extraction_job),
          estimated_completion: extraction_job.estimated_completion_time&.iso8601
        }
      }
      
      # Broadcast to job-specific channel
      ActionCable.server.broadcast("extraction_job_#{extraction_job.id}", progress_data)
      
      # Also update dashboard if significant progress
      if should_update_dashboard?(extraction_job)
        broadcast_dashboard_update(extraction_job.data_source.organization)
      end
    end
    
    # Broadcast data source connection status changes
    def broadcast_data_source_status_change(data_source, status_change)
      organization = data_source.organization
      
      data = {
        type: 'data_source_status_change',
        timestamp: Time.current.iso8601,
        data_source_id: data_source.id,
        status_change: status_change,
        current_status: data_source.status,
        health: calculate_data_source_health(data_source)
      }
      
      ActionCable.server.broadcast("data_sources_#{organization.id}", data)
      ActionCable.server.broadcast("data_source_#{data_source.id}", data)
      
      # Update dashboard
      broadcast_dashboard_update(organization)
    end
    
    # Broadcast system alerts and notifications
    def broadcast_system_alert(organization, alert)
      data = {
        type: 'system_alert',
        timestamp: Time.current.iso8601,
        alert: alert
      }
      
      ActionCable.server.broadcast("dashboard_#{organization.id}", data)
    end
    
    # Broadcast usage warnings
    def broadcast_usage_warning(organization, warning)
      data = {
        type: 'usage_warning',
        timestamp: Time.current.iso8601,
        warning: warning
      }
      
      ActionCable.server.broadcast("dashboard_#{organization.id}", data)
    end
    
    # Broadcast new records processed
    def broadcast_records_processed(organization, count, source_name)
      data = {
        type: 'records_processed',
        timestamp: Time.current.iso8601,
        count: count,
        source_name: source_name,
        total_records: organization.raw_data_records.count
      }
      
      ActionCable.server.broadcast("dashboard_#{organization.id}", data)
    end
    
    private
    
    def calculate_dashboard_metrics(organization)
      {
        overview_stats: {
          total_data_sources: organization.data_sources.count,
          connected_sources: organization.data_sources.connected.count,
          active_syncs: organization.extraction_jobs.running.count,
          total_records: organization.raw_data_records.count
        },
        real_time_metrics: {
          records_last_hour: organization.raw_data_records
                                        .where('created_at >= ?', 1.hour.ago)
                                        .count,
          processing_rate: calculate_org_processing_rate(organization),
          sync_success_rate: calculate_org_success_rate(organization),
          system_health: calculate_org_health(organization)
        },
        active_jobs: organization.extraction_jobs
                                .running
                                .includes(:data_source)
                                .map { |job| serialize_job_for_broadcast(job) }
      }
    end
    
    def serialize_job_for_broadcast(job)
      {
        id: job.id,
        data_source_id: job.data_source_id,
        data_source_name: job.data_source.name,
        data_source_platform: job.data_source.platform,
        status: job.status,
        records_processed: job.records_processed || 0,
        progress_percentage: calculate_job_progress(job),
        started_at: job.started_at&.iso8601,
        completed_at: job.completed_at&.iso8601,
        duration: job.duration&.round(2),
        error_message: job.error_message,
        processing_rate: calculate_processing_rate(job)
      }
    end
    
    def calculate_job_progress(job)
      return 100 if job.completed?
      return 0 unless job.running?
      
      if job.extraction_metadata&.dig('total_records_estimate')
        total = job.extraction_metadata['total_records_estimate']
        processed = job.records_processed || 0
        [(processed.to_f / total * 100).round(1), 95].min
      else
        # Estimate based on time elapsed
        elapsed = Time.current - (job.started_at || Time.current)
        estimated_total_time = 600 # 10 minutes default
        [(elapsed / estimated_total_time * 100).round(1), 90].min
      end
    end
    
    def calculate_processing_rate(job)
      return 0 unless job.running? && job.started_at
      
      elapsed = Time.current - job.started_at
      return 0 if elapsed <= 0
      
      ((job.records_processed || 0) / elapsed).round(2)
    end
    
    def calculate_org_processing_rate(organization)
      recent_records = organization.raw_data_records
                                 .where('created_at >= ?', 1.hour.ago)
                                 .count
      (recent_records / 60.0).round(2) # records per minute
    end
    
    def calculate_org_success_rate(organization)
      recent_jobs = organization.extraction_jobs.where('created_at >= ?', 24.hours.ago)
      return 100 if recent_jobs.empty?
      
      success_count = recent_jobs.completed.count
      total_count = recent_jobs.count
      
      ((success_count.to_f / total_count) * 100).round(1)
    end
    
    def calculate_org_health(organization)
      recent_jobs = organization.extraction_jobs.where('created_at >= ?', 24.hours.ago)
      return 'unknown' if recent_jobs.empty?
      
      success_rate = recent_jobs.completed.count.to_f / recent_jobs.count
      
      case success_rate
      when 0.95..1.0 then 'excellent'
      when 0.85..0.94 then 'good'
      when 0.70..0.84 then 'fair'
      else 'poor'
      end
    end
    
    def calculate_data_source_health(data_source)
      recent_jobs = data_source.extraction_jobs.where('created_at >= ?', 7.days.ago)
      return 'unknown' if recent_jobs.empty?
      
      success_rate = recent_jobs.completed.count.to_f / recent_jobs.count
      
      case success_rate
      when 0.9..1.0 then 'excellent'
      when 0.7..0.89 then 'good'
      when 0.5..0.69 then 'fair'
      else 'poor'
      end
    end
    
    def should_update_dashboard?(job)
      # Update dashboard every 10% progress or every 2 minutes
      progress = calculate_job_progress(job)
      last_update = job.extraction_metadata&.dig('last_dashboard_update')
      
      progress_threshold = (progress % 10).zero? && progress > 0
      time_threshold = !last_update || (Time.current - Time.parse(last_update)) > 2.minutes
      
      progress_threshold || time_threshold
    end
  end
end