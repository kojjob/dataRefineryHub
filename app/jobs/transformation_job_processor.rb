# Background job to transform raw extracted data into business entities
# Processes raw data records and creates normalized business models
class TransformationJobProcessor < ApplicationJob
  queue_as :transformation
  
  # Retry configuration
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  
  # Discard job if data source is deleted
  discard_on ActiveRecord::RecordNotFound

  def perform(data_source_id)
    data_source = DataSource.find(data_source_id)
    
    Rails.logger.info "Starting transformation job for #{data_source.name}"

    # Get unprocessed raw data records
    unprocessed_records = data_source.raw_data_records
                                    .where(processed_at: nil)
                                    .includes(:extraction_job)
    
    if unprocessed_records.empty?
      Rails.logger.info "No unprocessed records found for #{data_source.name}"
      return
    end

    # Create transformation job record
    transformation_job = create_transformation_job(data_source, unprocessed_records.count)

    begin
      # Transform records by type
      transformation_results = transform_records_by_type(unprocessed_records)
      
      # Update transformation job with results
      update_transformation_job_success(transformation_job, transformation_results)
      
      # Mark raw records as processed
      mark_records_as_processed(unprocessed_records)
      
      Rails.logger.info "Transformation completed for #{data_source.name}: #{transformation_results.values.sum} records transformed"

      # Create audit log
      create_audit_log(data_source, 'transformation_completed', transformation_results)

    rescue => error
      # Update transformation job with error
      update_transformation_job_failure(transformation_job, error)
      
      Rails.logger.error "Transformation failed for #{data_source.name}: #{error.message}"
      
      # Create audit log
      create_audit_log(data_source, 'transformation_failed', {
        error_message: error.message,
        error_type: error.class.name
      })
      
      raise error
    end
  end

  private

  def transform_records_by_type(raw_records)
    results = {}
    
    # Group records by type for batch processing
    records_by_type = raw_records.group_by(&:record_type)
    
    records_by_type.each do |record_type, records|
      Rails.logger.info "Transforming #{records.count} #{record_type} records"
      
      case record_type
      when 'orders'
        results['orders'] = transform_orders(records)
      when 'customers'
        results['customers'] = transform_customers(records)
      when 'products'
        results['products'] = transform_products(records)
      when 'inventory_levels'
        results['inventory_levels'] = transform_inventory(records)
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
        started_by: 'system'
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
        completed_by: 'system'
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
        failed_by: 'system'
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