class ScheduledUploadJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(scheduled_upload_id)
    scheduled_upload = ScheduledUpload.find(scheduled_upload_id)

    Rails.logger.info "Executing scheduled upload: #{scheduled_upload.name} (ID: #{scheduled_upload_id})"

    result = scheduled_upload.execute!

    if result[:success]
      Rails.logger.info "Scheduled upload completed successfully: #{scheduled_upload.name}"
    else
      Rails.logger.error "Scheduled upload failed: #{scheduled_upload.name} - #{result[:error]}"
    end

    result
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "Scheduled upload not found: #{scheduled_upload_id}"
  rescue => e
    Rails.logger.error "Scheduled upload job failed: #{e.message}"
    raise e
  end
end
