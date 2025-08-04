# Background job to process data extraction from external sources
# Uses Solid Queue for reliable job processing with retries
class ExtractionJobProcessor < ApplicationJob
  queue_as :extraction

  # Enhanced retry configuration with circuit breaker integration
  retry_on StandardError, wait: :exponentially_longer, attempts: 3 do |job, error|
    # Log retry attempt with structured logging
    structured_logger.warn "Retrying extraction job",
      job_id: job.job_id,
      error_class: error.class.name,
      error_message: error.message,
      attempt: job.executions,
      data_source_id: job.arguments.first

    # Update circuit breaker metrics
    data_source_id = job.arguments.first
    if data_source_id
      circuit_breaker = CircuitBreakerService.for("extraction_job_#{data_source_id}")
      # Circuit breaker will be updated by the error handler in the extractor
    end
  end

  retry_on ExtractorFactory::UnsupportedSourceTypeError, attempts: 1
  retry_on CircuitBreakerService::CircuitBreakerOpenError, attempts: 5, wait: :exponentially_longer

  # Discard job if data source is deleted
  discard_on ActiveRecord::RecordNotFound

  def perform(data_source_id, extraction_job_id = nil)
    data_source = DataSource.find(data_source_id)

    # Update status to processing
    data_source.update!(status: "processing")

    # Create audit log with enhanced context
    audit_context = {
      job_id: job_id,
      extraction_job_id: extraction_job_id,
      data_source_type: data_source.source_type,
      started_at: Time.current
    }

    AuditLog.create!(
      action: "extraction_started",
      resource_type: "DataSource",
      resource_id: data_source.id,
      details: audit_context
    )

    begin
      # Create extractor with enhanced capabilities
      extractor = ExtractorFactory.create_extractor(data_source, extraction_job_id)

      # Perform data extraction with enhanced error handling and batch processing
      # The extractor now uses EnhancedErrorHandlerService internally
      extracted_data = extractor.extract_data

      # Get comprehensive extraction statistics
      extraction_stats = extractor.respond_to?(:enhanced_extraction_stats) ?
                        extractor.enhanced_extraction_stats :
                        extractor.extraction_stats

      # Update status to completed
      data_source.update!(
        status: "connected",
        last_sync_at: Time.current,
        metadata: (data_source.metadata || {}).merge(
          last_extraction_stats: extraction_stats,
          last_successful_extraction: Time.current
        )
      )

      # Create comprehensive audit log for success
      success_details = audit_context.merge(
        completed_at: Time.current,
        records_extracted: extracted_data&.size || 0,
        extraction_stats: extraction_stats,
        processing_duration: Time.current - audit_context[:started_at]
      )

      AuditLog.create!(
        action: "extraction_completed",
        resource_type: "DataSource",
        resource_id: data_source.id,
        details: success_details
      )

      # Schedule transformation if data was extracted
      if extracted_data&.any?
        # Pass extraction statistics to transformation job
        TransformationJobProcessor.perform_later(
          data_source_id,
          extraction_job_id,
          { extraction_stats: extraction_stats }
        )
      else
        structured_logger.info "No data extracted, skipping transformation",
          data_source_id: data_source_id
      end

    rescue CircuitBreakerService::CircuitBreakerOpenError => error
      # Handle circuit breaker open state
      data_source.update!(status: "circuit_breaker_open")

      error_details = audit_context.merge(
        failed_at: Time.current,
        error_message: error.message,
        error_class: error.class.name,
        error_type: "circuit_breaker_open",
        processing_duration: Time.current - audit_context[:started_at]
      )

      AuditLog.create!(
        action: "extraction_circuit_breaker_open",
        resource_type: "DataSource",
        resource_id: data_source.id,
        details: error_details
      )

      # Don't re-raise circuit breaker errors immediately - let retry mechanism handle it
      structured_logger.warn "Circuit breaker open",
        data_source_id: data_source_id,
        error_message: error.message

      # Track circuit breaker metrics
      MetricsService.increment("pipeline.circuit_breaker.open", tags: {
        source_type: data_source.source_type
      })
      raise error

    rescue => error
      # Update status to error
      data_source.update!(status: "error")

      # Create comprehensive audit log for error
      error_details = audit_context.merge(
        failed_at: Time.current,
        error_message: error.message,
        error_class: error.class.name,
        error_backtrace: error.backtrace&.first(10),
        processing_duration: Time.current - audit_context[:started_at]
      )

      AuditLog.create!(
        action: "extraction_failed",
        resource_type: "DataSource",
        resource_id: data_source.id,
        details: error_details
      )

      # Log error with context for monitoring
      structured_logger.error "Extraction failed", error,
        data_source_id: data_source_id,
        attempts: executions

      # Track failure metrics
      MetricsService.increment("pipeline.executions.failed", tags: {
        source_type: data_source.source_type,
        error_class: error.class.name
      })

      # Re-raise the error to trigger retry mechanism
      raise error
    end
  end

  private

  def can_extract?(data_source)
    return false unless data_source
    return false if data_source.status == "disconnected"
    return false unless ExtractorFactory.supported_source_type?(data_source.source_type)

    true
  end

  def create_audit_log(data_source, action, details = {})
    return unless data_source

    AuditLog.create!(
      organization: data_source.organization,
      user: nil, # System operation
      action: action,
      resource_type: "DataSource",
      resource_id: data_source.id,
      details: details.merge({
        source_type: data_source.source_type,
        source_name: data_source.name
      })
    )
  rescue => error
    # Don't fail the job if audit logging fails
    structured_logger.error "Failed to create audit log", error
  end
end
