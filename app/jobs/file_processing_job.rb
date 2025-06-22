class FileProcessingJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(data_source, file_attachment, user)
    @data_source = data_source
    @file_attachment = file_attachment
    @user = user

    Rails.logger.info "Starting file processing for data source #{@data_source.id}, file: #{@file_attachment.filename}"

    begin
      # Mark data source as syncing
      @data_source.update!(status: "syncing")

      # Create extraction job record
      extraction_job = create_extraction_job

      # Process the file
      processor = FileProcessorService.new(
        data_source: @data_source,
        file: @file_attachment,
        user: @user
      )

      result = processor.process!

      # Update extraction job with results
      extraction_job.update!(
        status: "completed",
        completed_at: Time.current,
        records_processed: result[:total_records],
        processing_summary: result[:processing_summary]
      )

      # Update data source status
      @data_source.update!(
        status: "connected",
        last_sync_at: Time.current,
        next_sync_at: @data_source.calculate_next_sync
      )

      # Send success notification
      send_completion_notification(extraction_job, result)

      Rails.logger.info "File processing completed successfully for #{@file_attachment.filename}"

    rescue => e
      Rails.logger.error "File processing failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      # Mark extraction job as failed
      extraction_job&.update!(
        status: "failed",
        error_message: e.message,
        completed_at: Time.current
      )

      # Mark data source as error
      @data_source.update!(status: "error", error_message: e.message)

      # Send error notification
      send_error_notification(e)

      # Re-raise for retry mechanism
      raise e
    end
  end

  private

  def create_extraction_job
    ExtractionJob.create!(
      data_source: @data_source,
      status: "running",
      started_at: Time.current,
      job_type: "file_processing",
      config: {
        filename: @file_attachment.filename.to_s,
        file_size: @file_attachment.byte_size,
        content_type: @file_attachment.content_type
      }
    )
  end

  def send_completion_notification(extraction_job, result)
    # Create a notification record for the user
    create_notification(
      type: "file_processing_completed",
      title: "File Processing Completed",
      message: "Successfully processed #{@file_attachment.filename} with #{result[:total_records]} records",
      data: {
        data_source_id: @data_source.id,
        extraction_job_id: extraction_job.id,
        filename: @file_attachment.filename.to_s,
        total_records: result[:total_records]
      }
    )
  end

  def send_error_notification(error)
    # Create an error notification for the user
    create_notification(
      type: "file_processing_failed",
      title: "File Processing Failed",
      message: "Failed to process #{@file_attachment.filename}: #{error.message}",
      data: {
        data_source_id: @data_source.id,
        filename: @file_attachment.filename.to_s,
        error_message: error.message
      }
    )
  end

  def create_notification(type:, title:, message:, data: {})
    # For now, just log the notification
    # Later, you can implement a proper notification system
    Rails.logger.info "NOTIFICATION: #{type} - #{title}: #{message}"

    # You could create a Notification model and save it here
    # Notification.create!(
    #   user: @user,
    #   type: type,
    #   title: title,
    #   message: message,
    #   data: data,
    #   read_at: nil
    # )
  end
end
