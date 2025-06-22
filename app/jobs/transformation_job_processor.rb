# Background job to transform raw extracted data into business entities
# Processes raw data records and creates normalized business models
class TransformationJobProcessor < ApplicationJob
  queue_as :transformation

  # Enhanced retry configuration with circuit breaker integration
  retry_on StandardError, wait: :exponentially_longer, attempts: 3 do |job, error|
    # Log retry attempt with enhanced context
    Rails.logger.warn "Retrying transformation job #{job.job_id}: #{error.class.name} - #{error.message}"

    # Update circuit breaker metrics for transformation
    data_source_id = job.arguments.first
    if data_source_id
      circuit_breaker = CircuitBreakerService.for("transformation_job_#{data_source_id}")
      # Circuit breaker will be updated by the error handler
    end
  end

  retry_on CircuitBreakerService::CircuitBreakerOpenError, attempts: 5, wait: :exponentially_longer

  # Discard job if data source is deleted
  discard_on ActiveRecord::RecordNotFound

  def perform(data_source_id, extraction_job_id = nil, extraction_context = {})
    data_source = DataSource.find(data_source_id)

    # Initialize enhanced services for transformation
    error_handler = EnhancedErrorHandlerService.new(
      circuit_breaker_config: {
        failure_threshold: 3,
        success_threshold: 2,
        timeout: 300, # 5 minutes for transformation
        service_name: "transformation_job_#{data_source_id}"
      }
    )

    batch_processor = BatchProcessingService.new(
      transformation_batch_size: 500,
      validation_batch_size: 200
    )

    data_validator = DataQualityValidationService.new

    # Execute transformation with enhanced error handling
    error_handler.execute_with_protection do
      perform_transformation_with_batching(
        data_source,
        extraction_job_id,
        extraction_context,
        batch_processor,
        data_validator
      )
    end
  end

  def perform_transformation_with_batching(data_source, extraction_job_id, extraction_context, batch_processor, data_validator)
    # Get unprocessed raw data records with enhanced querying
    raw_records_query = RawDataRecord.where(
      data_source: data_source,
      processed: false
    )

    # Add extraction job filter if provided
    if extraction_job_id
      raw_records_query = raw_records_query.where(extraction_job_id: extraction_job_id)
    end

    total_records = raw_records_query.count
    return if total_records.zero?

    Rails.logger.info "Starting transformation for #{total_records} records from data source #{data_source.id}"

    # Create transformation job record with enhanced context
    transformation_job = TransformationJob.create!(
      data_source: data_source,
      extraction_job_id: extraction_job_id,
      status: "processing",
      started_at: Time.current,
      total_records: total_records,
      metadata: {
        extraction_context: extraction_context,
        batch_processing_enabled: true,
        data_validation_enabled: true
      }
    )

    begin
      # Process records in batches for better performance and memory management
      transformation_stats = {
        transformed_count: 0,
        failed_count: 0,
        validation_errors: 0,
        batches_processed: 0
      }

      # Use batch processor for efficient processing
      batch_processor.process_in_batches(raw_records_query, batch_size: 500) do |batch, batch_number|
        Rails.logger.debug "Processing transformation batch #{batch_number} (#{batch.size} records)"

        batch_stats = process_transformation_batch(
          batch,
          data_source,
          transformation_job,
          data_validator
        )

        # Aggregate statistics
        transformation_stats[:transformed_count] += batch_stats[:transformed_count]
        transformation_stats[:failed_count] += batch_stats[:failed_count]
        transformation_stats[:validation_errors] += batch_stats[:validation_errors]
        transformation_stats[:batches_processed] += 1

        # Update job progress
        progress_percentage = (transformation_stats[:transformed_count] + transformation_stats[:failed_count]).to_f / total_records * 100
        transformation_job.update!(
          records_processed: transformation_stats[:transformed_count],
          records_failed: transformation_stats[:failed_count],
          progress_percentage: progress_percentage.round(2)
        )
      end

      # Update transformation job with final results
      transformation_job.update!(
        status: "completed",
        completed_at: Time.current,
        records_processed: transformation_stats[:transformed_count],
        records_failed: transformation_stats[:failed_count],
        progress_percentage: 100.0,
        metadata: transformation_job.metadata.merge(
          final_stats: transformation_stats,
          processing_duration: Time.current - transformation_job.started_at
        )
      )

      # Create comprehensive audit log
      AuditLog.create!(
        action: "transformation_completed",
        resource_type: "DataSource",
        resource_id: data_source.id,
        details: {
          transformation_job_id: transformation_job.id,
          extraction_job_id: extraction_job_id,
          records_processed: transformation_stats[:transformed_count],
          records_failed: transformation_stats[:failed_count],
          validation_errors: transformation_stats[:validation_errors],
          batches_processed: transformation_stats[:batches_processed],
          processing_duration: Time.current - transformation_job.started_at,
          success_rate: (transformation_stats[:transformed_count].to_f / total_records * 100).round(2)
        }
      )

      Rails.logger.info "Transformation completed for data source #{data_source.id}: #{transformation_stats[:transformed_count]} records processed, #{transformation_stats[:failed_count]} failed"

    rescue CircuitBreakerService::CircuitBreakerOpenError => error
      # Handle circuit breaker open state
      transformation_job.update!(
        status: "circuit_breaker_open",
        completed_at: Time.current,
        error_message: error.message
      )

      AuditLog.create!(
        action: "transformation_circuit_breaker_open",
        resource_type: "DataSource",
        resource_id: data_source.id,
        details: {
          transformation_job_id: transformation_job.id,
          error_message: error.message,
          error_class: error.class.name
        }
      )

      Rails.logger.warn "Circuit breaker open for transformation of data source #{data_source.id}: #{error.message}"
      raise error

    rescue => error
      # Update transformation job status
      transformation_job.update!(
        status: "failed",
        completed_at: Time.current,
        error_message: error.message
      )

      # Create audit log for error
      AuditLog.create!(
        action: "transformation_failed",
        resource_type: "DataSource",
        resource_id: data_source.id,
        details: {
          transformation_job_id: transformation_job.id,
          extraction_job_id: extraction_job_id,
          error_message: error.message,
          error_class: error.class.name,
          error_backtrace: error.backtrace&.first(10)
        }
      )

      Rails.logger.error "Transformation failed for data source #{data_source.id}: #{error.class.name} - #{error.message}"

      # Re-raise the error to trigger retry mechanism
      raise error
    end
  end

  def process_transformation_batch(batch, data_source, transformation_job, data_validator)
    batch_stats = {
      transformed_count: 0,
      failed_count: 0,
      validation_errors: 0
    }

    batch.each do |raw_record|
      begin
        # Create transformer for this record type
        transformer = TransformerFactory.create_transformer(raw_record.record_type)
        transformed_data = transformer.transform(raw_record.data)

        # Validate transformed data quality
        validation_result = data_validator.validate_record(
          transformed_data,
          context: "#{data_source.source_type}_#{raw_record.record_type}"
        )

        if validation_result.valid?
          # Create processed record
          ProcessedDataRecord.create!(
            raw_data_record: raw_record,
            data_source: data_source,
            record_type: raw_record.record_type,
            data: transformed_data,
            transformation_job: transformation_job,
            quality_score: validation_result.quality_score
          )

          # Mark raw record as processed
          raw_record.update!(processed: true, processed_at: Time.current)
          batch_stats[:transformed_count] += 1
        else
          # Log validation errors but still mark as processed
          Rails.logger.warn "Data validation failed for record #{raw_record.id}: #{validation_result.errors.map(&:message).join(', ')}"

          # Create processed record with validation errors
          ProcessedDataRecord.create!(
            raw_data_record: raw_record,
            data_source: data_source,
            record_type: raw_record.record_type,
            data: transformed_data,
            transformation_job: transformation_job,
            quality_score: validation_result.quality_score,
            validation_errors: validation_result.errors.map(&:to_h)
          )

          raw_record.update!(processed: true, processed_at: Time.current)
          batch_stats[:validation_errors] += 1
          batch_stats[:transformed_count] += 1 # Still count as transformed
        end

      rescue => error
        Rails.logger.error "Failed to transform record #{raw_record.id}: #{error.message}"

        # Mark record as failed but processed
        raw_record.update!(
          processed: true,
          processed_at: Time.current,
          processing_error: error.message
        )

        batch_stats[:failed_count] += 1
      end
    end

    batch_stats
  end

  private

  def transform_records_by_type(raw_records)
    results = {}

    # Group records by type for batch processing
    records_by_type = raw_records.group_by(&:record_type)

    records_by_type.each do |record_type, records|
      Rails.logger.info "Transforming #{records.count} #{record_type} records"

      case record_type
      when "orders"
        results["orders"] = transform_orders(records)
      when "customers"
        results["customers"] = transform_customers(records)
      when "products"
        results["products"] = transform_products(records)
      when "inventory_levels"
        results["inventory_levels"] = transform_inventory(records)
      else
        Rails.logger.warn "Unknown record type: #{record_type}"
        results[record_type] = 0
      end
    end

    results
  end

  def transform_orders(raw_records)
    # Note: We would create ProcessedOrder models here when implemented
    # For now, just log the transformation
    Rails.logger.info "Would transform #{raw_records.count} order records into ProcessedOrder models"

    # TODO: Implement when ProcessedOrder model is created
    # ProcessedOrder.create_from_raw_records(raw_records)

    raw_records.count
  end

  def transform_customers(raw_records)
    # Note: We would create ProcessedCustomer models here when implemented
    Rails.logger.info "Would transform #{raw_records.count} customer records into ProcessedCustomer models"

    # TODO: Implement when ProcessedCustomer model is created
    # ProcessedCustomer.create_from_raw_records(raw_records)

    raw_records.count
  end

  def transform_products(raw_records)
    # Note: We would create ProcessedProduct models here when implemented
    Rails.logger.info "Would transform #{raw_records.count} product records into ProcessedProduct models"

    # TODO: Implement when ProcessedProduct model is created
    # ProcessedProduct.create_from_raw_records(raw_records)

    raw_records.count
  end

  def transform_inventory(raw_records)
    # Note: We would create ProcessedInventory models here when implemented
    Rails.logger.info "Would transform #{raw_records.count} inventory records into ProcessedInventory models"

    # TODO: Implement when ProcessedInventory model is created
    # ProcessedInventory.create_from_raw_records(raw_records)

    raw_records.count
  end

  def create_transformation_job(data_source, record_count)
    TransformationJob.create!(
      data_source: data_source,
      status: :running,
      started_at: Time.current,
      metadata: {
        total_records: record_count,
        started_by: "system"
      }
    )
  end

  def update_transformation_job_success(job, results)
    job.update!(
      status: :completed,
      completed_at: Time.current,
      succeeded_at: Time.current,
      metadata: job.metadata.merge({
        transformation_results: results,
        total_transformed: results.values.sum,
        completed_by: "system"
      })
    )
  end

  def update_transformation_job_failure(job, error)
    job.update!(
      status: :failed,
      failed_at: Time.current,
      error_message: error.message,
      metadata: job.metadata.merge({
        error_type: error.class.name,
        failed_by: "system"
      })
    )
  end

  def mark_records_as_processed(raw_records)
    raw_records.update_all(
      processed_at: Time.current,
      updated_at: Time.current
    )
  end

  def create_audit_log(data_source, action, details = {})
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
    Rails.logger.error "Failed to create audit log: #{error.message}"
  end
end
