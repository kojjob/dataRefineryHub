class DataSourcesChannel < ApplicationCable::Channel
  def subscribed
    if current_user&.organization
      # Subscribe to organization-wide data source updates
      stream_from "data_sources_#{current_user.organization.id}"
      
      # Also subscribe to specific data source if provided
      if params[:data_source_id].present?
        data_source = current_user.organization.data_sources.find_by(id: params[:data_source_id])
        if data_source
          stream_from "data_source_#{data_source.id}"
          
          # Send initial data source status
          transmit({
            type: 'data_source_status',
            timestamp: Time.current.iso8601,
            data_source: serialize_data_source(data_source)
          })
        end
      end
      
      transmit({
        type: 'connection_established',
        timestamp: Time.current.iso8601,
        message: 'Connected to data sources updates'
      })
      
      Rails.logger.info "User #{current_user.id} subscribed to data sources updates"
    else
      reject
    end
  end

  def unsubscribed
    Rails.logger.info "User #{current_user&.id} unsubscribed from data sources updates"
  end

  def request_status_update(data)
    data_source_id = data['data_source_id']
    
    if data_source_id.present?
      data_source = current_user.organization.data_sources.find_by(id: data_source_id)
      
      if data_source
        transmit({
          type: 'status_update',
          timestamp: Time.current.iso8601,
          data_source: serialize_data_source(data_source)
        })
      end
    end
  end

  def subscribe_to_sync(data)
    job_id = data['job_id']
    
    if job_id.present?
      job = current_user.organization.extraction_jobs.find_by(id: job_id)
      
      if job
        stream_from "extraction_job_#{job_id}"
        
        transmit({
          type: 'sync_subscription_confirmed',
          timestamp: Time.current.iso8601,
          job_id: job_id,
          current_status: serialize_extraction_job(job)
        })
      end
    end
  end

  private

  def serialize_data_source(data_source)
    {
      id: data_source.id,
      name: data_source.name,
      platform: data_source.platform,
      status: data_source.status,
      last_sync_at: data_source.extraction_jobs.completed.maximum(:completed_at)&.iso8601,
      total_records: data_source.raw_data_records.count,
      sync_health: calculate_sync_health(data_source),
      current_jobs: data_source.extraction_jobs.running.map { |job| serialize_extraction_job(job) },
      recent_jobs: data_source.extraction_jobs
                             .order(created_at: :desc)
                             .limit(3)
                             .map { |job| serialize_extraction_job(job) }
    }
  end

  def serialize_extraction_job(job)
    {
      id: job.id,
      status: job.status,
      records_processed: job.records_processed || 0,
      progress_percentage: calculate_job_progress(job),
      started_at: job.started_at&.iso8601,
      completed_at: job.completed_at&.iso8601,
      error_message: job.error_message,
      duration: job.duration&.round(2)
    }
  end

  def calculate_sync_health(data_source)
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

  def calculate_job_progress(job)
    return 100 if job.completed?
    return 0 unless job.running?

    if job.extraction_metadata&.dig('total_records_estimate')
      total = job.extraction_metadata['total_records_estimate']
      processed = job.records_processed || 0
      [(processed.to_f / total * 100).round(1), 95].min
    else
      50
    end
  end
end