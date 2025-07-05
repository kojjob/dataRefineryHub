# frozen_string_literal: true

class JobProgressChannel < ApplicationCable::Channel
  def subscribed
    job_id = params[:job_id]

    # Verify user has access to this job
    extraction_job = current_user.organization.extraction_jobs.find_by(id: job_id)

    if extraction_job
      stream_from "job_#{job_id}"

      # Send current job status
      transmit({
        type: "job_status",
        job_id: job_id,
        status: extraction_job.status,
        progress: extraction_job.progress_percentage || 0,
        records_processed: extraction_job.records_processed || 0,
        started_at: extraction_job.started_at&.iso8601,
        estimated_completion: extraction_job.extraction_metadata&.dig("estimated_completion"),
        timestamp: Time.current.iso8601
      })

      Rails.logger.info "JobProgressChannel: User #{current_user.id} subscribed to job #{job_id}"
    else
      reject
      Rails.logger.warn "JobProgressChannel: User #{current_user.id} attempted to subscribe to unauthorized job #{job_id}"
    end
  end

  def unsubscribed
    Rails.logger.info "JobProgressChannel: User #{current_user.id} unsubscribed from job progress"
  end

  def request_status_update(data)
    job_id = data["job_id"]
    extraction_job = current_user.organization.extraction_jobs.find_by(id: job_id)

    if extraction_job
      transmit({
        type: "status_update",
        job_id: job_id,
        status: extraction_job.status,
        progress: extraction_job.progress_percentage || 0,
        records_processed: extraction_job.records_processed || 0,
        processing_rate: extraction_job.extraction_metadata&.dig("processing_rate"),
        estimated_completion: extraction_job.extraction_metadata&.dig("estimated_completion"),
        error_message: extraction_job.error_message,
        timestamp: Time.current.iso8601
      })
    end
  end

  def cancel_job(data)
    job_id = data["job_id"]
    extraction_job = current_user.organization.extraction_jobs.find_by(id: job_id)

    if extraction_job&.running?
      # Mark job as cancelled
      extraction_job.update!(
        status: "cancelled",
        completed_at: Time.current,
        error_message: "Cancelled by user"
      )

      # Broadcast cancellation
      ActionCable.server.broadcast("job_#{job_id}", {
        type: "job_status",
        job_id: job_id,
        status: "cancelled",
        message: "Job cancelled by user",
        timestamp: Time.current.iso8601
      })

      Rails.logger.info "Job #{job_id} cancelled by user #{current_user.id}"
    end
  end
end
