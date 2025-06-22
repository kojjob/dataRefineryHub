# frozen_string_literal: true

module RealTimeBroadcastable
  extend ActiveSupport::Concern

  def broadcast_job_status(status, message, additional_data = {})
    broadcast_data = {
      type: "job_status",
      job_id: @extraction_job.id,
      data_source_id: @data_source.id,
      status: status,
      message: message,
      timestamp: Time.current.iso8601
    }.merge(additional_data)

    # Broadcast to organization-specific dashboard channel
    ActionCable.server.broadcast(
      "dashboard_#{@organization.id}",
      broadcast_data
    )

    # Broadcast to job-specific channel for detailed tracking
    ActionCable.server.broadcast(
      "job_#{@extraction_job.id}",
      broadcast_data
    )

    # Broadcast to data source specific channel
    ActionCable.server.broadcast(
      "data_source_#{@data_source.id}",
      broadcast_data
    )

    Rails.logger.info "Broadcasted job status: #{status} for job #{@extraction_job.id}"
  end

  def broadcast_progress_update(stage, progress_percentage, processed_count, total_count, message)
    broadcast_data = {
      type: "progress_update",
      job_id: @extraction_job.id,
      data_source_id: @data_source.id,
      stage: stage,
      progress: {
        percentage: progress_percentage,
        processed_count: processed_count,
        total_count: total_count,
        processing_rate: @extraction_job.extraction_metadata&.dig("processing_rate"),
        estimated_completion: @extraction_job.extraction_metadata&.dig("estimated_completion")
      },
      message: message,
      timestamp: Time.current.iso8601
    }

    # Broadcast to organization dashboard
    ActionCable.server.broadcast(
      "dashboard_#{@organization.id}",
      broadcast_data
    )

    # Broadcast to job-specific channel
    ActionCable.server.broadcast(
      "job_#{@extraction_job.id}",
      broadcast_data
    )

    # Broadcast to data source channel
    ActionCable.server.broadcast(
      "data_source_#{@data_source.id}",
      broadcast_data
    )
  end

  def broadcast_error(error_type, error_message, recovery_action = nil)
    broadcast_data = {
      type: "error",
      job_id: @extraction_job.id,
      data_source_id: @data_source.id,
      error: {
        type: error_type,
        message: error_message,
        recovery_action: recovery_action
      },
      timestamp: Time.current.iso8601
    }

    # Broadcast error to all relevant channels
    ActionCable.server.broadcast(
      "dashboard_#{@organization.id}",
      broadcast_data
    )

    ActionCable.server.broadcast(
      "job_#{@extraction_job.id}",
      broadcast_data
    )

    ActionCable.server.broadcast(
      "data_source_#{@data_source.id}",
      broadcast_data
    )
  end

  def broadcast_metrics_update(metrics)
    broadcast_data = {
      type: "metrics_update",
      job_id: @extraction_job.id,
      data_source_id: @data_source.id,
      metrics: metrics,
      timestamp: Time.current.iso8601
    }

    # Broadcast metrics to dashboard
    ActionCable.server.broadcast(
      "dashboard_#{@organization.id}",
      broadcast_data
    )
  end
end