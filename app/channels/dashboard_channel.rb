class DashboardChannel < ApplicationCable::Channel
  def subscribed
    # Subscribe to organization-specific dashboard updates
    if current_user&.organization
      stream_from "dashboard_#{current_user.organization.id}"
      
      # Send initial connection confirmation
      transmit({
        type: 'connection_established',
        timestamp: Time.current.iso8601,
        message: 'Connected to real-time dashboard updates'
      })
      
      # Send initial dashboard data
      transmit({
        type: 'initial_data',
        timestamp: Time.current.iso8601,
        data: gather_dashboard_data
      })
      
      Rails.logger.info "User #{current_user.id} subscribed to dashboard updates for organization #{current_user.organization.id}"
    else
      reject
    end
  end

  def unsubscribed
    Rails.logger.info "User #{current_user&.id} unsubscribed from dashboard updates"
  end

  def request_metrics_update
    # Client can request immediate metrics update
    transmit({
      type: 'metrics_update',
      timestamp: Time.current.iso8601,
      data: gather_dashboard_data
    })
  end

  def subscribe_to_job(data)
    # Subscribe to specific job updates
    job_id = data['job_id']
    
    if job_id.present? && current_user.organization.extraction_jobs.exists?(job_id)
      stream_from "job_#{job_id}"
      
      transmit({
        type: 'job_subscription_confirmed',
        timestamp: Time.current.iso8601,
        job_id: job_id
      })
    end
  end

  private

  def gather_dashboard_data
    organization = current_user.organization
    
    {
      overview_stats: {
        total_data_sources: organization.data_sources.count,
        connected_sources: organization.data_sources.connected.count,
        active_syncs: organization.extraction_jobs.running.count,
        total_records: organization.raw_data_records.count
      },
      recent_activity: recent_extraction_jobs(organization),
      system_health: calculate_system_health(organization),
      real_time_metrics: {
        records_last_hour: organization.raw_data_records
                                     .where('created_at >= ?', 1.hour.ago)
                                     .count,
        processing_rate: calculate_processing_rate(organization),
        sync_success_rate: calculate_success_rate(organization)
      }
    }
  end

  def recent_extraction_jobs(organization)
    organization.extraction_jobs
               .includes(:data_source)
               .order(created_at: :desc)
               .limit(5)
               .map do |job|
      {
        id: job.id,
        data_source_name: job.data_source.name,
        status: job.status,
        records_processed: job.records_processed || 0,
        started_at: job.started_at&.iso8601,
        completed_at: job.completed_at&.iso8601,
        progress: calculate_job_progress(job)
      }
    end
  end

  def calculate_system_health(organization)
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

  def calculate_processing_rate(organization)
    recent_records = organization.raw_data_records
                                .where('created_at >= ?', 1.hour.ago)
                                .count
    (recent_records / 60.0).round(2) # records per minute
  end

  def calculate_success_rate(organization)
    recent_jobs = organization.extraction_jobs.where('created_at >= ?', 24.hours.ago)
    return 100 if recent_jobs.empty?

    success_count = recent_jobs.completed.count
    total_count = recent_jobs.count

    ((success_count.to_f / total_count) * 100).round(1)
  end

  def calculate_job_progress(job)
    return 100 if job.completed?
    return 0 unless job.running?

    if job.extraction_metadata&.dig('total_records_estimate')
      total = job.extraction_metadata['total_records_estimate']
      processed = job.records_processed || 0
      [(processed.to_f / total * 100).round(1), 95].min
    else
      50 # Default for running jobs
    end
  end
end