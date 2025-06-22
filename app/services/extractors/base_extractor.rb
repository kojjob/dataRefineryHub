# Base class for all data source extractors
# Provides common interface and error handling for ETL pipeline
class BaseExtractor
  include ActiveSupport::Rescuable

  # Standard errors for extraction process
  class ExtractionError < StandardError; end
  class ConnectionError < ExtractionError; end
  class AuthenticationError < ExtractionError; end
  class RateLimitError < ExtractionError; end
  class DataValidationError < ExtractionError; end

  attr_reader :data_source, :extraction_job, :logger

  def initialize(data_source)
    @data_source = data_source
    @logger = Rails.logger
    @error_handler = EnhancedErrorHandlerService.new(
      context: "#{data_source.source_type}_extractor",
      circuit_breaker_config: {
        failure_threshold: 3,
        timeout_period: 120,
        exponential_backoff: true
      }
    )
    @batch_processor = BatchProcessingService.new(:extraction)
    @data_validator = DataQualityValidationService.new
  end

  # Main extraction workflow - template method pattern
  def extract_data(job_id: nil)
    @extraction_job = find_or_create_job(job_id)

    @error_handler.execute_with_protection(
      "extract_data_#{@data_source.source_type}",
      max_attempts: 3,
      strategy: :exponential
    ) do
      update_job_status(:running)
      validate_connection

      extracted_data = perform_extraction_with_batching
      validated_data = validate_data_quality(extracted_data)

      save_raw_data(validated_data)
      update_job_status(:completed)

      validated_data
    end
  rescue => error
    handle_extraction_error(error)
    raise
  end

  # Test connection without full extraction
  def test_connection
    begin
      validate_connection
      { status: :success, message: "Connection successful" }
    rescue => error
      { status: :error, message: error.message, error_type: error.class.name }
    end
  end

  # Get extraction statistics
  def extraction_stats
    {
      total_jobs: extraction_jobs.count,
      successful_jobs: extraction_jobs.completed.count,
      failed_jobs: extraction_jobs.failed.count,
      last_sync_at: data_source.last_sync_at,
      next_sync_at: data_source.next_sync_at
    }
  end

  protected

  # Abstract methods to be implemented by subclasses
  def validate_connection
    raise NotImplementedError, "Subclasses must implement validate_connection"
  end

  def perform_extraction
    raise NotImplementedError, "Subclasses must implement perform_extraction"
  end

  def normalize_data(raw_data)
    # Default implementation - can be overridden
    raw_data
  end

  # Enhanced data extraction with batching support
  def perform_extraction_with_batching
    raw_data = perform_extraction

    # Process large datasets in batches for memory efficiency
    if raw_data.respond_to?(:size) && raw_data.size > 1000
      @logger.info "Processing #{raw_data.size} records in batches"

      processed_data = @batch_processor.process_in_batches(raw_data) do |batch, batch_number|
        @logger.debug "Processing extraction batch #{batch_number} (#{batch.size} records)"
        normalize_batch_data(batch)
      end

      processed_data.flatten
    else
      normalize_data(raw_data)
    end
  end

  # Enhanced data validation with quality metrics
  def validate_data_quality(data)
    return data if data.empty?

    # Get validation rules for this data source type
    validation_context = @data_source.source_type.to_s

    # Perform comprehensive data quality validation
    validation_result = @data_validator.validate_data(
      data,
      context: validation_context
    )

    # Log validation results
    if validation_result.valid?
      @logger.info "Data validation passed: #{data.size} records validated successfully"
    else
      @logger.warn "Data validation issues found: #{validation_result.error_count} errors in #{data.size} records"
      @logger.warn "Quality score: #{validation_result.quality_score}%"

      # Log top validation errors
      validation_result.errors.first(5).each do |error|
        @logger.warn "Validation error: #{error.message} (Field: #{error.field}, Severity: #{error.severity})"
      end
    end

    # Store validation metrics for monitoring
    store_validation_metrics(validation_result)

    # Return valid records only, or all records based on configuration
    if should_filter_invalid_records?
      validation_result.valid_records
    else
      data
    end
  end

  # Batch normalization for performance
  def normalize_batch_data(batch)
    batch.map { |record| normalize_data(record) }.compact
  end

  # Data validation with business rules (legacy method for compatibility)
  def validate_data(data)
    return [] if data.blank?

    validated_records = []

    data.each do |record|
      begin
        normalized_record = normalize_data(record)
        validate_record_schema(normalized_record)
        validated_records << normalized_record
      rescue DataValidationError => e
        log_validation_error(record, e)
        # Continue processing other records
      end
    end

    validated_records
  end

  def validate_record_schema(record)
    required_fields = self.class.required_fields

    required_fields.each do |field|
      unless record.key?(field.to_s) || record.key?(field.to_sym)
        raise DataValidationError, "Missing required field: #{field}"
      end
    end

    true
  end

  # Save extracted data as raw records
  def save_raw_data(validated_data)
    return if validated_data.empty?

    raw_records = validated_data.map do |record|
      {
        data_source: data_source,
        extraction_job: extraction_job,
        raw_data: record,
        record_type: determine_record_type(record),
        external_id: extract_external_id(record),
        extracted_at: Time.current
      }
    end

    RawDataRecord.insert_all(raw_records)

    logger.info "Saved #{raw_records.count} raw records for #{data_source.name}"
  end

  # Job management
  def find_or_create_job(job_id)
    if job_id
      ExtractionJob.find(job_id)
    else
      ExtractionJob.create!(
        data_source: data_source,
        status: "queued",
        started_at: Time.current
      )
    end
  end

  def update_job_status(status, metadata: {})
    return unless extraction_job

    attributes = { status: status }

    case status.to_s
    when "running"
      attributes[:started_at] = Time.current
    when "completed"
      attributes[:completed_at] = Time.current
      data_source.update!(
        last_sync_at: Time.current,
        next_sync_at: calculate_next_sync,
        status: "connected"
      )
    when "failed"
      attributes[:completed_at] = Time.current
      attributes[:error_details] = metadata
      data_source.update!(status: "error")
    end

    attributes[:metadata] = extraction_job.metadata.merge(metadata) if metadata.present?

    extraction_job.update!(attributes)
  end

  # Error handling
  def handle_extraction_error(error)
    logger.error "Extraction failed for #{data_source.name}: #{error.message}"
    logger.error error.backtrace.join("\n") if Rails.env.development?

    error_metadata = {
      error_message: error.message,
      error_type: error.class.name,
      error_details: error_details(error)
    }

    update_job_status(:failed, metadata: error_metadata)

    # Create audit log
    AuditLog.create!(
      organization: data_source.organization,
      user: nil, # System operation
      action: "extraction_failed",
      resource_type: "DataSource",
      resource_id: data_source.id,
      details: error_metadata
    )
  end

  def log_validation_error(record, error)
    logger.warn "Data validation failed for record: #{error.message}"
    logger.debug "Invalid record: #{record.inspect}" if Rails.env.development?
  end

  # Rate limiting and retry logic
  def with_rate_limiting(&block)
    @circuit_breaker.call(&block)
  rescue CircuitBreaker::CircuitBreakerOpenError
    raise RateLimitError, "Circuit breaker is open - service temporarily unavailable"
  end

  def retry_with_backoff(max_retries: 3, base_delay: 1)
    retries = 0

    begin
      yield
    rescue RateLimitError, Net::TimeoutError => error
      retries += 1

      if retries <= max_retries
        delay = base_delay * (2 ** (retries - 1)) # Exponential backoff
        jitter = rand(0.1..0.3) * delay # Add jitter

        logger.info "Retrying in #{delay + jitter} seconds (attempt #{retries}/#{max_retries})"
        sleep(delay + jitter)
        retry
      else
        raise error
      end
    end
  end

  # Utility methods
  def determine_record_type(record)
    # Default implementation - should be overridden by subclasses
    "unknown"
  end

  def extract_external_id(record)
    # Default implementation - looks for common ID fields
    record["id"] || record[:id] || record["external_id"] || record[:external_id]
  end

  def calculate_next_sync
    case data_source.sync_frequency
    when "realtime" then 5.minutes.from_now
    when "hourly" then 1.hour.from_now
    when "daily" then 1.day.from_now
    when "weekly" then 1.week.from_now
    when "monthly" then 1.month.from_now
    else 1.hour.from_now
    end
  end

  def error_details(error)
    case error
    when AuthenticationError
      { category: "authentication", recoverable: true }
    when ConnectionError
      { category: "connection", recoverable: true }
    when RateLimitError
      { category: "rate_limit", recoverable: true }
    when DataValidationError
      { category: "data_validation", recoverable: false }
    else
      { category: "unknown", recoverable: false }
    end
  end

  def extraction_jobs
    data_source.extraction_jobs
  end

  # Class methods for extractor metadata
  class << self
    def supported_source_type
      name.underscore.sub("_extractor", "")
    end

    def required_fields
      []
    end

    def optional_fields
      []
    end

    def supports_realtime?
      false
    end

    def supports_incremental_sync?
      true
    end

    def rate_limit_per_hour
      1000 # Default conservative limit
    end
  end

  private

  # Store validation metrics for monitoring and analysis
  def store_validation_metrics(validation_result)
    return unless @extraction_job

    # Store metrics in extraction job for later analysis
    metrics_data = {
      quality_score: validation_result.quality_score,
      error_count: validation_result.error_count,
      validation_summary: validation_result.quality_report,
      timestamp: Time.current
    }

    # Update extraction job with validation metrics
    @extraction_job.update(
      metadata: (@extraction_job.metadata || {}).merge(
        validation_metrics: metrics_data
      )
    )
  rescue => error
    @logger.error "Failed to store validation metrics: #{error.message}"
  end

  # Configuration for filtering invalid records
  def should_filter_invalid_records?
    # Check data source configuration or use default
    @data_source.configuration&.dig("filter_invalid_records") || false
  end

  # Get comprehensive extraction metrics including new enhancements
  def enhanced_extraction_stats
    base_stats = extraction_stats

    # Add enhanced metrics
    base_stats.merge(
      error_handler_metrics: @error_handler&.metrics,
      batch_processing_metrics: @batch_processor&.processing_metrics,
      data_validation_stats: @data_validator&.validation_statistics
    )
  end

  # Legacy circuit breaker implementation (kept for backward compatibility)
  # Note: This is now replaced by the enhanced CircuitBreakerService
  class CircuitBreaker
    class CircuitBreakerOpenError < StandardError; end

    FAILURE_THRESHOLD = 5
    TIMEOUT_PERIOD = 60 # seconds

    def initialize
      @failure_count = 0
      @last_failure_time = nil
      @state = :closed # :closed, :open, :half_open
    end

    def call(&block)
      if circuit_open?
        raise CircuitBreakerOpenError, "Circuit breaker is open"
      end

      begin
        result = yield
        on_success
        result
      rescue => error
        on_failure
        raise error
      end
    end

    private

    def circuit_open?
      @state == :open && (Time.current - @last_failure_time) < TIMEOUT_PERIOD
    end

    def on_success
      @failure_count = 0
      @state = :closed
    end

    def on_failure
      @failure_count += 1
      @last_failure_time = Time.current

      if @failure_count >= FAILURE_THRESHOLD
        @state = :open
      end
    end
  end
end
