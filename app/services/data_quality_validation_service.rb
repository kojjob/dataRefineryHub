# Data Quality Validation Service for ETL Pipeline
# Provides comprehensive data validation with configurable rules and quality metrics
class DataQualityValidationService
  # Validation rule types
  VALIDATION_TYPES = {
    presence: :validate_presence,
    format: :validate_format,
    range: :validate_range,
    uniqueness: :validate_uniqueness,
    referential_integrity: :validate_referential_integrity,
    data_type: :validate_data_type,
    business_rules: :validate_business_rules,
    statistical: :validate_statistical_anomalies
  }.freeze

  # Data quality dimensions
  QUALITY_DIMENSIONS = [
    :completeness,    # No missing values
    :accuracy,        # Correct values
    :consistency,     # Consistent across sources
    :validity,        # Conforms to defined format
    :uniqueness,      # No duplicates where expected
    :timeliness,      # Data is current
    :integrity        # Referential integrity maintained
  ].freeze

  attr_reader :validation_rules, :quality_metrics, :validation_results

  def initialize(validation_config = {})
    # Load configuration from centralized manager
    dq_config = EtlConfigurationManager.data_quality_config
    
    @config = {
      # Validation rule configurations from centralized config
      presence_validation: dq_config[:validation_rules][:presence][:enabled],
      format_validation: dq_config[:validation_rules][:format][:enabled],
      range_validation: dq_config[:validation_rules][:range][:enabled],
      uniqueness_validation: dq_config[:validation_rules][:uniqueness][:enabled],
      referential_integrity: dq_config[:validation_rules][:referential_integrity][:enabled],
      data_type_validation: dq_config[:validation_rules][:data_type][:enabled],
      business_rules_validation: dq_config[:validation_rules][:business_rules][:enabled],
      statistical_validation: dq_config[:validation_rules][:statistical][:enabled],
      
      # Quality thresholds from centralized config
      completeness_threshold: dq_config[:quality_thresholds][:completeness],
      accuracy_threshold: dq_config[:quality_thresholds][:accuracy],
      consistency_threshold: dq_config[:quality_thresholds][:consistency],
      validity_threshold: dq_config[:quality_thresholds][:validity],
      uniqueness_threshold: dq_config[:quality_thresholds][:uniqueness],
      timeliness_threshold: dq_config[:quality_thresholds][:timeliness],
      integrity_threshold: dq_config[:quality_thresholds][:integrity],
      
      # Processing options from centralized config
      batch_validation: true,
      parallel_validation: false,
      fail_fast: false,
      detailed_reporting: dq_config[:reporting][:detailed_errors]
    }.merge(validation_config)
    
    @validation_rules = load_validation_rules(validation_config)
    @quality_metrics = QualityMetrics.new
    @validation_results = []
    @logger = Rails.logger
    @batch_processor = BatchProcessingService.new(:validation)
  end

  # Validate data with comprehensive quality checks
  def validate_data(data, context: 'unknown', rules: nil)
    return ValidationResult.new(true, [], @quality_metrics) if data.empty?

    @logger.info "Starting data quality validation for #{context}: #{data.size} records"
    start_time = Time.current

    # Use specified rules or default rules for context
    active_rules = rules || @validation_rules[context.to_sym] || @validation_rules[:default]
    
    # Reset validation state
    @validation_results.clear
    @quality_metrics.reset!

    # Process data in batches for performance
    validation_errors = []
    valid_records = []
    
    @batch_processor.process_in_batches(data) do |batch, batch_number|
      batch_results = validate_batch(batch, active_rules, context, batch_number)
      
      validation_errors.concat(batch_results[:errors])
      valid_records.concat(batch_results[:valid_records])
      
      # Update quality metrics
      @quality_metrics.update_from_batch(batch_results[:metrics])
    end

    # Calculate overall quality score
    quality_score = calculate_quality_score(data.size, validation_errors.size)
    
    # Generate quality report
    quality_report = generate_quality_report(data.size, validation_errors, quality_score)
    
    duration = Time.current - start_time
    @logger.info "Data validation completed in #{duration.round(2)}s. Quality score: #{quality_score}%"

    ValidationResult.new(
      validation_errors.empty?,
      validation_errors,
      @quality_metrics,
      quality_score,
      quality_report,
      valid_records
    )
  end

  # Validate single record
  def validate_record(record, rules, context = 'single_record')
    errors = []
    
    rules.each do |rule|
      begin
        validation_method = VALIDATION_TYPES[rule[:type]]
        next unless validation_method
        
        result = send(validation_method, record, rule)
        errors << result unless result.nil?
        
      rescue => error
        @logger.error "Validation rule failed: #{rule[:name]} - #{error.message}"
        errors << ValidationError.new(
          field: rule[:field],
          rule: rule[:name],
          message: "Validation rule error: #{error.message}",
          severity: :critical,
          record_id: extract_record_id(record)
        )
      end
    end
    
    errors.compact
  end

  # Add custom validation rule
  def add_validation_rule(context, rule)
    @validation_rules[context.to_sym] ||= []
    @validation_rules[context.to_sym] << rule
  end

  # Get validation statistics
  def validation_statistics
    {
      total_validations: @validation_results.size,
      quality_metrics: @quality_metrics.summary,
      batch_processing_metrics: @batch_processor.processing_metrics,
      common_errors: analyze_common_errors,
      quality_trends: analyze_quality_trends
    }
  end

  private

  def validate_batch(batch, rules, context, batch_number)
    errors = []
    valid_records = []
    batch_metrics = BatchQualityMetrics.new
    
    batch.each_with_index do |record, index|
      record_errors = validate_record(record, rules, context)
      
      if record_errors.empty?
        valid_records << record
        batch_metrics.record_valid
      else
        errors.concat(record_errors)
        batch_metrics.record_invalid(record_errors.size)
      end
      
      # Update quality dimension metrics
      update_quality_dimensions(record, record_errors, batch_metrics)
    end
    
    {
      errors: errors,
      valid_records: valid_records,
      metrics: batch_metrics
    }
  end

  def update_quality_dimensions(record, errors, metrics)
    # Completeness: Check for missing required fields
    missing_fields = count_missing_fields(record)
    metrics.update_completeness(missing_fields == 0)
    
    # Accuracy: Based on validation errors
    accuracy_errors = errors.select { |e| e.dimension == :accuracy }
    metrics.update_accuracy(accuracy_errors.empty?)
    
    # Validity: Format and type validation errors
    validity_errors = errors.select { |e| [:format, :data_type].include?(e.rule_type) }
    metrics.update_validity(validity_errors.empty?)
    
    # Add other dimension updates as needed
  end

  # Validation methods for different rule types
  def validate_presence(record, rule)
    field_value = extract_field_value(record, rule[:field])
    
    if field_value.nil? || (field_value.respond_to?(:empty?) && field_value.empty?)
      ValidationError.new(
        field: rule[:field],
        rule: rule[:name],
        message: rule[:message] || "#{rule[:field]} is required",
        severity: rule[:severity] || :error,
        dimension: :completeness,
        rule_type: :presence,
        record_id: extract_record_id(record)
      )
    end
  end

  def validate_format(record, rule)
    field_value = extract_field_value(record, rule[:field])
    return nil if field_value.nil? # Skip format validation for nil values
    
    pattern = rule[:pattern]
    unless field_value.to_s.match?(pattern)
      ValidationError.new(
        field: rule[:field],
        rule: rule[:name],
        message: rule[:message] || "#{rule[:field]} format is invalid",
        severity: rule[:severity] || :error,
        dimension: :validity,
        rule_type: :format,
        record_id: extract_record_id(record),
        expected: pattern.source,
        actual: field_value
      )
    end
  end

  def validate_range(record, rule)
    field_value = extract_field_value(record, rule[:field])
    return nil if field_value.nil?
    
    min_val = rule[:min]
    max_val = rule[:max]
    
    if (min_val && field_value < min_val) || (max_val && field_value > max_val)
      ValidationError.new(
        field: rule[:field],
        rule: rule[:name],
        message: rule[:message] || "#{rule[:field]} is outside valid range",
        severity: rule[:severity] || :error,
        dimension: :validity,
        rule_type: :range,
        record_id: extract_record_id(record),
        expected: "#{min_val} - #{max_val}",
        actual: field_value
      )
    end
  end

  def validate_data_type(record, rule)
    field_value = extract_field_value(record, rule[:field])
    return nil if field_value.nil?
    
    expected_type = rule[:expected_type]
    
    case expected_type
    when :integer
      valid = field_value.is_a?(Integer) || (field_value.is_a?(String) && field_value.match?(/^\d+$/))
    when :float
      valid = field_value.is_a?(Numeric) || (field_value.is_a?(String) && field_value.match?(/^\d*\.?\d+$/))
    when :boolean
      valid = [true, false, 'true', 'false', '1', '0'].include?(field_value)
    when :date
      valid = field_value.is_a?(Date) || (field_value.is_a?(String) && Date.parse(field_value) rescue false)
    when :email
      valid = field_value.is_a?(String) && field_value.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
    else
      valid = field_value.is_a?(expected_type)
    end
    
    unless valid
      ValidationError.new(
        field: rule[:field],
        rule: rule[:name],
        message: rule[:message] || "#{rule[:field]} has invalid data type",
        severity: rule[:severity] || :error,
        dimension: :validity,
        rule_type: :data_type,
        record_id: extract_record_id(record),
        expected: expected_type,
        actual: field_value.class
      )
    end
  end

  def validate_business_rules(record, rule)
    # Custom business rule validation
    business_rule = rule[:rule_proc] || rule[:rule_lambda]
    return nil unless business_rule
    
    begin
      result = business_rule.call(record)
      unless result
        ValidationError.new(
          field: rule[:field],
          rule: rule[:name],
          message: rule[:message] || "Business rule validation failed",
          severity: rule[:severity] || :warning,
          dimension: :accuracy,
          rule_type: :business_rules,
          record_id: extract_record_id(record)
        )
      end
    rescue => error
      ValidationError.new(
        field: rule[:field],
        rule: rule[:name],
        message: "Business rule error: #{error.message}",
        severity: :critical,
        dimension: :accuracy,
        rule_type: :business_rules,
        record_id: extract_record_id(record)
      )
    end
  end

  def validate_statistical_anomalies(record, rule)
    # Statistical anomaly detection (simplified)
    field_value = extract_field_value(record, rule[:field])
    return nil unless field_value.is_a?(Numeric)
    
    # This would typically use historical data for comparison
    # For now, we'll use simple threshold-based detection
    threshold = rule[:anomaly_threshold] || 3 # Standard deviations
    
    # Placeholder for statistical analysis
    # In practice, you'd compare against historical mean/std dev
    
    nil # No anomaly detected in this simplified version
  end

  def extract_field_value(record, field_path)
    # Support nested field access (e.g., 'user.email')
    field_path.to_s.split('.').reduce(record) do |obj, field|
      case obj
      when Hash
        obj[field] || obj[field.to_sym]
      when ActiveRecord::Base
        obj.send(field) if obj.respond_to?(field)
      else
        obj.respond_to?(field) ? obj.send(field) : nil
      end
    end
  rescue
    nil
  end

  def extract_record_id(record)
    case record
    when Hash
      record[:id] || record['id']
    when ActiveRecord::Base
      record.id
    else
      record.respond_to?(:id) ? record.id : nil
    end
  end

  def count_missing_fields(record)
    # Count fields that are nil or empty
    case record
    when Hash
      record.values.count { |v| v.nil? || (v.respond_to?(:empty?) && v.empty?) }
    when ActiveRecord::Base
      record.attributes.values.count { |v| v.nil? || (v.respond_to?(:empty?) && v.empty?) }
    else
      0
    end
  end

  def calculate_quality_score(total_records, error_count)
    return 100.0 if total_records == 0
    
    valid_records = total_records - error_count
    (valid_records.to_f / total_records * 100).round(2)
  end

  def generate_quality_report(total_records, errors, quality_score)
    error_summary = errors.group_by(&:rule_type).transform_values(&:count)
    severity_summary = errors.group_by(&:severity).transform_values(&:count)
    dimension_summary = errors.group_by(&:dimension).transform_values(&:count)
    
    {
      total_records: total_records,
      valid_records: total_records - errors.size,
      invalid_records: errors.size,
      quality_score: quality_score,
      error_summary: error_summary,
      severity_summary: severity_summary,
      dimension_summary: dimension_summary,
      recommendations: generate_recommendations(errors)
    }
  end

  def generate_recommendations(errors)
    recommendations = []
    
    error_counts = errors.group_by(&:rule_type).transform_values(&:count)
    
    error_counts.each do |rule_type, count|
      case rule_type
      when :presence
        recommendations << "Consider implementing data collection improvements to reduce missing values (#{count} occurrences)"
      when :format
        recommendations << "Review data input validation to prevent format errors (#{count} occurrences)"
      when :data_type
        recommendations << "Implement stronger type checking in data ingestion (#{count} occurrences)"
      when :business_rules
        recommendations << "Review business rule implementations and data sources (#{count} occurrences)"
      end
    end
    
    recommendations
  end

  def analyze_common_errors
    # Analyze patterns in validation errors
    @validation_results.flat_map(&:errors)
                      .group_by { |e| "#{e.field}:#{e.rule_type}" }
                      .transform_values(&:count)
                      .sort_by { |_, count| -count }
                      .first(10)
                      .to_h
  end

  def analyze_quality_trends
    # Placeholder for quality trend analysis
    # Would typically track quality scores over time
    {
      current_session: @quality_metrics.summary,
      trend: 'stable' # Would be calculated from historical data
    }
  end

  def load_validation_rules(config)
    # Load validation rules from configuration
    default_rules = {
      default: [
        {
          name: 'required_id',
          type: :presence,
          field: :id,
          severity: :error,
          message: 'Record ID is required'
        }
      ],
      extraction: [
        {
          name: 'valid_timestamp',
          type: :data_type,
          field: :created_at,
          expected_type: :date,
          severity: :warning
        }
      ],
      transformation: [
        {
          name: 'email_format',
          type: :format,
          field: :email,
          pattern: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i,
          severity: :error
        }
      ]
    }
    
    default_rules.deep_merge(config)
  end

  # Supporting classes
  class ValidationError
    attr_reader :field, :rule, :message, :severity, :dimension, :rule_type, 
                :record_id, :expected, :actual, :timestamp

    def initialize(field:, rule:, message:, severity: :error, dimension: :validity, 
                   rule_type: :unknown, record_id: nil, expected: nil, actual: nil)
      @field = field
      @rule = rule
      @message = message
      @severity = severity
      @dimension = dimension
      @rule_type = rule_type
      @record_id = record_id
      @expected = expected
      @actual = actual
      @timestamp = Time.current
    end

    def to_h
      {
        field: @field,
        rule: @rule,
        message: @message,
        severity: @severity,
        dimension: @dimension,
        rule_type: @rule_type,
        record_id: @record_id,
        expected: @expected,
        actual: @actual,
        timestamp: @timestamp
      }
    end
  end

  class ValidationResult
    attr_reader :valid, :errors, :quality_metrics, :quality_score, 
                :quality_report, :valid_records

    def initialize(valid, errors, quality_metrics, quality_score = nil, 
                   quality_report = nil, valid_records = [])
      @valid = valid
      @errors = errors
      @quality_metrics = quality_metrics
      @quality_score = quality_score
      @quality_report = quality_report
      @valid_records = valid_records
    end

    def valid?
      @valid
    end

    def error_count
      @errors.size
    end

    def summary
      {
        valid: @valid,
        error_count: error_count,
        quality_score: @quality_score,
        quality_report: @quality_report
      }
    end
  end

  class QualityMetrics
    attr_reader :completeness_score, :accuracy_score, :validity_score, 
                :total_records, :valid_records

    def initialize
      reset!
    end

    def reset!
      @completeness_score = 0.0
      @accuracy_score = 0.0
      @validity_score = 0.0
      @total_records = 0
      @valid_records = 0
      @dimension_scores = Hash.new(0.0)
    end

    def update_from_batch(batch_metrics)
      @total_records += batch_metrics.total_records
      @valid_records += batch_metrics.valid_records
      
      # Update dimension scores (weighted average)
      QUALITY_DIMENSIONS.each do |dimension|
        current_weight = @total_records - batch_metrics.total_records
        new_weight = batch_metrics.total_records
        total_weight = @total_records
        
        if total_weight > 0
          @dimension_scores[dimension] = (
            (@dimension_scores[dimension] * current_weight) + 
            (batch_metrics.dimension_score(dimension) * new_weight)
          ) / total_weight
        end
      end
    end

    def summary
      {
        total_records: @total_records,
        valid_records: @valid_records,
        overall_quality_score: overall_quality_score,
        dimension_scores: @dimension_scores,
        completeness_score: @dimension_scores[:completeness],
        accuracy_score: @dimension_scores[:accuracy],
        validity_score: @dimension_scores[:validity]
      }
    end

    private

    def overall_quality_score
      return 0.0 if @total_records == 0
      (@valid_records.to_f / @total_records * 100).round(2)
    end
  end

  class BatchQualityMetrics
    attr_reader :total_records, :valid_records, :invalid_records

    def initialize
      @total_records = 0
      @valid_records = 0
      @invalid_records = 0
      @dimension_counts = Hash.new { |h, k| h[k] = { valid: 0, invalid: 0 } }
    end

    def record_valid
      @total_records += 1
      @valid_records += 1
    end

    def record_invalid(error_count = 1)
      @total_records += 1
      @invalid_records += 1
    end

    def update_completeness(is_complete)
      @dimension_counts[:completeness][is_complete ? :valid : :invalid] += 1
    end

    def update_accuracy(is_accurate)
      @dimension_counts[:accuracy][is_accurate ? :valid : :invalid] += 1
    end

    def update_validity(is_valid)
      @dimension_counts[:validity][is_valid ? :valid : :invalid] += 1
    end

    def dimension_score(dimension)
      counts = @dimension_counts[dimension]
      total = counts[:valid] + counts[:invalid]
      return 100.0 if total == 0
      (counts[:valid].to_f / total * 100).round(2)
    end
  end
end