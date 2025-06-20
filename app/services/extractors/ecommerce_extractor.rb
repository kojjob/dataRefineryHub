# Abstract base class for e-commerce platform extractors
# Provides unified interface and shared business logic for all e-commerce platforms
class EcommerceExtractor < BaseExtractor
  
  # E-commerce specific errors
  class InvalidPlatformError < ExtractionError; end
  class AdapterNotFoundError < ExtractionError; end
  class SchemaValidationError < DataValidationError; end

  # Standard e-commerce record types
  ECOMMERCE_RECORD_TYPES = %w[orders customers products inventory].freeze

  attr_reader :adapter

  def initialize(data_source)
    super(data_source)
    @adapter = create_adapter
    
    unless @adapter
      raise AdapterNotFoundError, "No adapter found for platform: #{data_source.source_type}"
    end
  end

  # Override base extractor methods with e-commerce specific logic
  def validate_connection
    adapter.validate_connection
  end

  def perform_extraction
    logger.info "Starting e-commerce data extraction for #{data_source.name} (#{data_source.source_type})"
    
    all_standardized_data = []
    
    ECOMMERCE_RECORD_TYPES.each do |record_type|
      next unless should_extract_record_type?(record_type)
      
      logger.info "Extracting #{record_type} from #{data_source.source_type}"
      
      raw_records = extract_record_type_with_adapter(record_type)
      standardized_records = standardize_records(record_type, raw_records)
      
      logger.info "Extracted and standardized #{standardized_records.count} #{record_type} records"
      
      all_standardized_data.concat(standardized_records)
    end
    
    logger.info "Completed e-commerce extraction: #{all_standardized_data.count} total records"
    all_standardized_data
  end

  def normalize_data(raw_record)
    record_type = raw_record[:record_type]
    platform_data = raw_record[:data]
    
    case record_type
    when 'orders'
      StandardOrder.from_platform_data(data_source.source_type, platform_data).to_hash
    when 'customers'
      StandardCustomer.from_platform_data(data_source.source_type, platform_data).to_hash
    when 'products'
      StandardProduct.from_platform_data(data_source.source_type, platform_data).to_hash
    when 'inventory'
      StandardInventory.from_platform_data(data_source.source_type, platform_data).to_hash
    else
      raise SchemaValidationError, "Unknown e-commerce record type: #{record_type}"
    end
  end

  def determine_record_type(record)
    record[:record_type] || 'unknown'
  end

  def extract_external_id(record)
    case record[:record_type]
    when 'orders', 'customers', 'products'
      record.dig(:normalized_data, 'external_id') || record.dig(:data, 'id')&.to_s
    when 'inventory'
      record.dig(:normalized_data, 'external_id') || 
        "#{record.dig(:data, 'inventory_item_id')}_#{record.dig(:data, 'location_id')}"
    else
      super
    end
  end

  # E-commerce specific methods
  def supports_realtime?
    adapter.supports_realtime?
  end

  def supports_incremental_sync?
    adapter.supports_incremental_sync?
  end

  def get_platform_rate_limit
    adapter.rate_limit_per_hour
  end

  # Customer analytics methods
  def calculate_customer_metrics(customer_data)
    customer_data.map do |customer_record|
      customer = StandardCustomer.new(customer_record[:normalized_data])
      
      {
        external_id: customer.external_id,
        lifetime_value: customer.calculate_lifetime_value,
        average_order_value: customer.calculate_average_order_value,
        segment: customer.customer_segment,
        high_value: customer.high_value_customer?,
        recent: customer.recent_customer?
      }
    end
  end

  # Product analytics methods
  def calculate_product_metrics(product_data)
    product_data.map do |product_record|
      product = StandardProduct.new(product_record[:normalized_data])
      
      {
        external_id: product.external_id,
        variant_count: product.variant_count,
        in_stock: product.in_stock?,
        on_sale: product.on_sale?,
        discount_percentage: product.discount_percentage,
        total_inventory: product.total_inventory
      }
    end
  end

  # Inventory analytics methods
  def calculate_inventory_metrics(inventory_data)
    inventory_items = inventory_data.map do |inventory_record|
      StandardInventory.new(inventory_record[:normalized_data])
    end
    
    {
      total_value: StandardInventory.calculate_total_inventory_value(inventory_items),
      low_stock_count: StandardInventory.low_stock_items(inventory_items).count,
      out_of_stock_count: StandardInventory.out_of_stock_items(inventory_items).count,
      reorder_recommendations: StandardInventory.calculate_reorder_recommendations(inventory_items),
      by_location: StandardInventory.group_by_location(inventory_items).transform_values(&:count)
    }
  end

  # Data quality and validation
  def validate_standardized_data(standardized_records)
    validation_results = {
      valid_count: 0,
      invalid_count: 0,
      errors: []
    }
    
    standardized_records.each_with_index do |record, index|
      begin
        schema_class = get_schema_class(record[:record_type])
        instance = schema_class.new(record[:normalized_data])
        
        if instance.valid?
          validation_results[:valid_count] += 1
        else
          validation_results[:invalid_count] += 1
          validation_results[:errors] << {
            index: index,
            record_type: record[:record_type],
            external_id: record[:normalized_data]['external_id'],
            errors: instance.errors.full_messages
          }
        end
      rescue => error
        validation_results[:invalid_count] += 1
        validation_results[:errors] << {
          index: index,
          record_type: record[:record_type],
          error: error.message
        }
      end
    end
    
    logger.info "Data validation: #{validation_results[:valid_count]} valid, #{validation_results[:invalid_count]} invalid"
    
    if validation_results[:invalid_count] > 0
      logger.warn "Validation errors found: #{validation_results[:errors].first(5)}"
    end
    
    validation_results
  end

  # Cross-platform customer deduplication
  def deduplicate_customers(customer_records)
    # Group customers by email (primary deduplication key)
    email_groups = customer_records.group_by do |record|
      record[:normalized_data]['email']&.downcase
    end
    
    deduplicated = []
    duplicates_found = 0
    
    email_groups.each do |email, records|
      if records.length == 1
        deduplicated << records.first
      else
        # Multiple records for same email - merge them
        merged_record = merge_customer_records(records)
        deduplicated << merged_record
        duplicates_found += records.length - 1
      end
    end
    
    logger.info "Customer deduplication: #{duplicates_found} duplicates merged"
    deduplicated
  end

  # Business intelligence helpers
  def generate_extraction_summary(all_data)
    summary = {
      platform: data_source.source_type,
      extraction_time: Time.current,
      total_records: all_data.count,
      by_type: {}
    }
    
    ECOMMERCE_RECORD_TYPES.each do |type|
      type_records = all_data.select { |r| r[:record_type] == type }
      summary[:by_type][type] = {
        count: type_records.count,
        sample_ids: type_records.first(3).map { |r| r[:normalized_data]['external_id'] }
      }
    end
    
    summary
  end

  protected

  # Abstract method - must be implemented by concrete extractors
  def create_adapter
    raise NotImplementedError, "Subclasses must implement create_adapter"
  end

  private

  def extract_record_type_with_adapter(record_type)
    case record_type
    when 'orders'
      adapter.fetch_orders(build_sync_options)
    when 'customers'
      adapter.fetch_customers(build_sync_options)
    when 'products'
      adapter.fetch_products(build_sync_options)
    when 'inventory'
      adapter.fetch_inventory(build_sync_options)
    else
      raise ArgumentError, "Unknown record type: #{record_type}"
    end
  end

  def standardize_records(record_type, raw_records)
    raw_records.map do |raw_record|
      begin
        # Add record type metadata
        record_with_type = raw_record.merge(record_type: record_type)
        
        # Standardize using schema
        normalized_data = normalize_data(record_with_type)
        
        {
          record_type: record_type,
          raw_data: raw_record,
          normalized_data: normalized_data,
          extracted_at: Time.current
        }
      rescue => error
        logger.error "Failed to standardize #{record_type} record: #{error.message}"
        logger.debug "Raw record: #{raw_record.inspect}" if Rails.env.development?
        
        # Return error record for debugging
        {
          record_type: record_type,
          raw_data: raw_record,
          normalized_data: nil,
          extraction_error: error.message,
          extracted_at: Time.current
        }
      end
    end.compact
  end

  def should_extract_record_type?(record_type)
    # Can be overridden by subclasses to skip certain record types
    true
  end

  def build_sync_options
    options = {}
    
    # Add incremental sync support
    if supports_incremental_sync? && data_source.last_sync_at
      options[:since] = data_source.last_sync_at
    end
    
    # Add organization context
    options[:organization_id] = data_source.organization_id
    
    options
  end

  def get_schema_class(record_type)
    case record_type
    when 'orders' then StandardOrder
    when 'customers' then StandardCustomer
    when 'products' then StandardProduct
    when 'inventory' then StandardInventory
    else
      raise SchemaValidationError, "Unknown schema for record type: #{record_type}"
    end
  end

  def merge_customer_records(records)
    # Take the most recent record as base
    base_record = records.max_by { |r| Date.parse(r[:normalized_data]['updated_at']) rescue Date.new(1900) }
    
    # Merge data from other records
    merged_data = base_record[:normalized_data].dup
    
    records.each do |record|
      customer_data = record[:normalized_data]
      
      # Aggregate numeric fields
      merged_data['orders_count'] = records.sum { |r| r[:normalized_data]['orders_count'] || 0 }
      merged_data['total_spent'] = records.sum { |r| r[:normalized_data]['total_spent'] || 0.0 }
      
      # Take most complete data for missing fields
      %w[phone first_name last_name default_address].each do |field|
        merged_data[field] ||= customer_data[field] if customer_data[field].present?
      end
      
      # Merge tags
      if customer_data['tags'].present?
        existing_tags = merged_data['tags']&.split(',')&.map(&:strip) || []
        new_tags = customer_data['tags'].split(',').map(&:strip)
        merged_data['tags'] = (existing_tags + new_tags).uniq.join(', ')
      end
    end
    
    # Mark as deduplicated
    merged_data['platform_data'] ||= {}
    merged_data['platform_data']['deduplicated_from'] = records.map { |r| r[:normalized_data]['external_id'] }
    
    base_record.merge(normalized_data: merged_data)
  end

  # Class-level configuration
  class << self
    def supported_platforms
      %w[shopify woocommerce amazon]
    end

    def required_fields
      %w[external_id platform_name created_at]
    end

    def supports_realtime?
      false # Override in subclasses
    end

    def supports_incremental_sync?
      true
    end
  end
end