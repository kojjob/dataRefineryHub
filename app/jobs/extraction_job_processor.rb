# Background job to process data extraction from external sources
# Uses Solid Queue for reliable job processing with retries
class ExtractionJobProcessor < ApplicationJob
  queue_as :extraction
  
  # Retry configuration
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  retry_on ExtractorFactory::UnsupportedSourceTypeError, attempts: 1
  
  # Discard job if data source is deleted
  discard_on ActiveRecord::RecordNotFound

  def perform(data_source_id, job_id = nil)
    data_source = DataSource.find(data_source_id)
    
    # Check if data source is in a valid state for extraction
    unless can_extract?(data_source)
      Rails.logger.warn "Skipping extraction for #{data_source.name} - invalid state: #{data_source.status}"
      return
    end

    # Update data source status
    data_source.update!(status: :syncing)

    # Create audit log for extraction start
    create_audit_log(data_source, 'extraction_started')

    # Perform the extraction
    Rails.logger.info "Starting extraction job for #{data_source.name} (#{data_source.source_type})"
    
    extracted_data = ExtractorFactory.extract_data(data_source, job_id: job_id)
    
    Rails.logger.info "Extraction completed for #{data_source.name}: #{extracted_data.count} records"

    # Schedule transformation job if data was extracted
    if extracted_data.present?
      TransformationJobProcessor.perform_later(data_source_id)
    end

    # Create audit log for successful extraction
    create_audit_log(data_source, 'extraction_completed', {
      records_extracted: extracted_data.count,
      job_id: job_id
    })

  rescue => error
    # Log the error
    Rails.logger.error "Extraction failed for #{data_source.name}: #{error.message}"
    Rails.logger.error error.backtrace.join("\n") if Rails.env.development?

    # Update data source status
    data_source.update!(status: :error) if data_source

    # Create audit log for failed extraction
    create_audit_log(data_source, 'extraction_failed', {
      error_message: error.message,
      error_type: error.class.name,
      job_id: job_id
    }) if data_source

    # Re-raise to trigger retry logic
    raise error
  end

  private

  def can_extract?(data_source)
    return false unless data_source
    return false if data_source.status == 'disconnected'
    return false unless ExtractorFactory.supported_source_type?(data_source.source_type)
    
    true
  end

  def create_audit_log(data_source, action, details = {})
    return unless data_source

    AuditLog.create!(
      organization: data_source.organization,
      user: nil, # System operation
      action: action,
      resource_type: 'DataSource',
      resource_id: data_source.id,
      details: details.merge({
        source_type: data_source.source_type,
        source_name: data_source.name
      })
    )
  rescue => error
    # Don't fail the job if audit logging fails
    Rails.logger.error "Failed to create audit log: #{error.message}"
  end
end