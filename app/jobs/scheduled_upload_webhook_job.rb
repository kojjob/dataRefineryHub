class ScheduledUploadWebhookJob < ApplicationJob
  queue_as :default
  
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  
  def perform(webhook_url:, scheduled_upload_id:, log_entry_id:)
    scheduled_upload = ScheduledUpload.find(scheduled_upload_id)
    log_entry = UploadLog.find(log_entry_id)
    
    payload = {
      event: 'scheduled_upload_completed',
      timestamp: Time.current.iso8601,
      scheduled_upload: {
        id: scheduled_upload.id,
        name: scheduled_upload.name,
        data_source_id: scheduled_upload.data_source_id
      },
      execution: {
        id: log_entry.id,
        status: log_entry.status,
        started_at: log_entry.started_at&.iso8601,
        completed_at: log_entry.completed_at&.iso8601,
        files_processed: log_entry.files_processed,
        files_failed: log_entry.files_failed,
        duration_seconds: log_entry.duration&.to_i
      }
    }
    
    response = HTTParty.post(
      webhook_url,
      body: payload.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'User-Agent' => 'DataRefineryPlatform/1.0'
      },
      timeout: 30
    )
    
    if response.success?
      Rails.logger.info "Webhook notification sent successfully to #{webhook_url}"
    else
      Rails.logger.error "Webhook notification failed: #{response.code} - #{response.body}"
      raise "Webhook failed with status #{response.code}"
    end
    
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Record not found for webhook: #{e.message}"
  rescue => e
    Rails.logger.error "Webhook notification failed: #{e.message}"
    raise e
  end
end