# frozen_string_literal: true

class DataSourceChannel < ApplicationCable::Channel
  def subscribed
    data_source_id = params[:data_source_id]
    
    # Verify user has access to this data source
    data_source = current_user.organization.data_sources.find_by(id: data_source_id)
    
    if data_source
      stream_from "data_source_#{data_source_id}"
      
      # Send current data source status
      transmit({
        type: "data_source_status",
        data_source_id: data_source_id,
        name: data_source.name,
        status: data_source.status,
        last_sync_at: data_source.last_sync_at&.iso8601,
        next_sync_at: data_source.next_sync_at&.iso8601,
        total_records: data_source.raw_data_records.count,
        sync_frequency: data_source.sync_frequency,
        timestamp: Time.current.iso8601
      })
      
      Rails.logger.info "DataSourceChannel: User #{current_user.id} subscribed to data source #{data_source_id}"
    else
      reject
      Rails.logger.warn "DataSourceChannel: User #{current_user.id} attempted to subscribe to unauthorized data source #{data_source_id}"
    end
  end

  def unsubscribed
    Rails.logger.info "DataSourceChannel: User #{current_user.id} unsubscribed from data source updates"
  end

  def request_sync_status(data)
    data_source_id = data["data_source_id"]
    data_source = current_user.organization.data_sources.find_by(id: data_source_id)
    
    if data_source
      # Get recent extraction jobs for this data source
      recent_jobs = data_source.extraction_jobs
                              .order(created_at: :desc)
                              .limit(5)
      
      transmit({
        type: "sync_status_update",
        data_source_id: data_source_id,
        status: data_source.status,
        recent_syncs: recent_jobs.map do |job|
          {
            id: job.id,
            status: job.status,
            records_processed: job.records_processed,
            started_at: job.started_at&.iso8601,
            completed_at: job.completed_at&.iso8601,
            progress: job.progress_percentage
          }
        end,
        timestamp: Time.current.iso8601
      })
    end
  end

  def trigger_manual_sync(data)
    data_source_id = data["data_source_id"]
    data_source = current_user.organization.data_sources.find_by(id: data_source_id)
    
    if data_source && data_source.status != "syncing"
      # Create new extraction job
      extraction_job = data_source.extraction_jobs.create!(
        status: "pending",
        config: {
          manual_trigger: true,
          triggered_by: current_user.id,
          triggered_at: Time.current.iso8601
        }
      )
      
      # Queue the job
      FileProcessingJob.perform_later(extraction_job.id)
      
      # Broadcast sync started
      ActionCable.server.broadcast("data_source_#{data_source_id}", {
        type: "sync_triggered",
        data_source_id: data_source_id,
        job_id: extraction_job.id,
        message: "Manual sync triggered",
        timestamp: Time.current.iso8601
      })
      
      Rails.logger.info "Manual sync triggered for data source #{data_source_id} by user #{current_user.id}"
    else
      transmit({
        type: "sync_error",
        data_source_id: data_source_id,
        message: "Cannot trigger sync - data source is currently syncing or unavailable",
        timestamp: Time.current.iso8601
      })
    end
  end
end