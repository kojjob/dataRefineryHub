class DataQualityValidationJob < ApplicationJob
  queue_as :default

  def perform(data_source)
    Rails.logger.info "Starting data quality validation for #{data_source.name}"

    # Load raw data records for validation
    records = data_source.raw_data_records.limit(10000).includes(:data_source)

    if records.empty?
      create_empty_report(data_source)
      return
    end

    # Initialize validation service
    validator = DataQualityValidationService.new

    # Convert records to validation format
    validation_data = records.map do |record|
      parse_record_data(record)
    end

    # Run validation
    validation_result = validator.validate_data(
      validation_data,
      context: data_source.source_type
    )

    # Create quality report
    create_quality_report(data_source, validation_result, records.count)

    Rails.logger.info "Data quality validation completed for #{data_source.name}"
  rescue => e
    Rails.logger.error "Data quality validation failed for #{data_source.name}: #{e.message}"
    create_error_report(data_source, e.message)
  end

  private

  def parse_record_data(record)
    # Parse the JSON data from raw_data_record
    data = record.data.is_a?(String) ? JSON.parse(record.data) : record.data

    # Ensure we have a hash
    data = {} unless data.is_a?(Hash)

    # Add metadata
    data.merge({
      "record_id" => record.id,
      "external_id" => record.external_id,
      "record_type" => record.record_type,
      "created_at" => record.created_at,
      "updated_at" => record.updated_at
    })
  rescue JSON::ParserError => e
    Rails.logger.warn "Failed to parse record data for record #{record.id}: #{e.message}"
    {
      "record_id" => record.id,
      "external_id" => record.external_id,
      "record_type" => record.record_type,
      "created_at" => record.created_at,
      "updated_at" => record.updated_at,
      "parse_error" => true,
      "original_data" => record.data.to_s.truncate(1000)
    }
  end

  def create_quality_report(data_source, validation_result, total_records)
    # Calculate dimension scores
    dimension_scores = calculate_dimension_scores(validation_result)

    # Calculate overall score
    overall_score = calculate_overall_score(dimension_scores)

    # Extract issues and recommendations
    issues = extract_issues(validation_result)
    recommendations = generate_recommendations(issues, data_source)

    # Create the report
    data_source.data_quality_reports.create!(
      overall_score: overall_score,
      completeness_score: dimension_scores[:completeness],
      accuracy_score: dimension_scores[:accuracy],
      consistency_score: dimension_scores[:consistency],
      validity_score: dimension_scores[:validity],
      timeliness_score: dimension_scores[:timeliness],
      issues_count: issues.length,
      total_records: total_records,
      valid_records: validation_result.valid_records.length,
      run_at: Time.current,
      report_data: {
        issues: issues,
        recommendations: recommendations,
        validation_errors: validation_result.errors.map(&:to_h),
        quality_metrics: validation_result.quality_metrics.summary,
        validation_summary: validation_result.summary
      }
    )
  end

  def create_empty_report(data_source)
    data_source.data_quality_reports.create!(
      overall_score: 0,
      completeness_score: 0,
      accuracy_score: 0,
      consistency_score: 0,
      validity_score: 0,
      timeliness_score: 0,
      issues_count: 0,
      total_records: 0,
      valid_records: 0,
      run_at: Time.current,
      report_data: {
        issues: [],
        recommendations: [
          {
            title: "Add Data Records",
            description: "No data records found. Import data to begin quality analysis.",
            priority: "high",
            impact: "high"
          }
        ],
        validation_errors: [],
        quality_metrics: {},
        validation_summary: { error: "No data available for validation" }
      }
    )
  end

  def create_error_report(data_source, error_message)
    data_source.data_quality_reports.create!(
      overall_score: 0,
      completeness_score: 0,
      accuracy_score: 0,
      consistency_score: 0,
      validity_score: 0,
      timeliness_score: 0,
      issues_count: 1,
      total_records: 0,
      valid_records: 0,
      run_at: Time.current,
      report_data: {
        issues: [
          {
            type: "validation_error",
            message: "Quality validation failed: #{error_message}",
            severity: "critical"
          }
        ],
        recommendations: [
          {
            title: "Fix Validation Error",
            description: "Resolve the validation error to enable quality analysis.",
            priority: "critical",
            impact: "high"
          }
        ],
        validation_errors: [],
        quality_metrics: {},
        validation_summary: { error: error_message }
      }
    )
  end

  def calculate_dimension_scores(validation_result)
    metrics = validation_result.quality_metrics

    {
      completeness: calculate_completeness_score(validation_result),
      accuracy: calculate_accuracy_score(validation_result),
      consistency: calculate_consistency_score(validation_result),
      validity: calculate_validity_score(validation_result),
      timeliness: calculate_timeliness_score(validation_result)
    }
  end

  def calculate_completeness_score(validation_result)
    return 100.0 if validation_result.valid_records.empty?

    total_fields = 0
    complete_fields = 0

    validation_result.valid_records.each do |record|
      record_fields = record.keys.reject { |k| k.to_s.starts_with?("record_") }
      total_fields += record_fields.length
      complete_fields += record_fields.count { |field| record[field].present? }
    end

    return 100.0 if total_fields == 0
    (complete_fields.to_f / total_fields * 100).round(2)
  end

  def calculate_accuracy_score(validation_result)
    # Count format and data type errors
    accuracy_errors = validation_result.errors.select do |error|
      [ :format, :data_type, :business_rules ].include?(error.rule_type)
    end

    total_validations = validation_result.valid_records.length + validation_result.errors.length
    return 100.0 if total_validations == 0

    accuracy_rate = (total_validations - accuracy_errors.length).to_f / total_validations
    (accuracy_rate * 100).round(2)
  end

  def calculate_consistency_score(validation_result)
    # Analyze data format consistency
    return 100.0 if validation_result.valid_records.empty?

    # Check format consistency for common fields
    field_formats = {}
    validation_result.valid_records.each do |record|
      record.each do |field, value|
        next if value.nil?
        field_formats[field] ||= []
        field_formats[field] << classify_value_type(value)
      end
    end

    consistency_scores = field_formats.map do |field, types|
      unique_types = types.uniq.length
      unique_types == 1 ? 100.0 : [ 100.0 - (unique_types - 1) * 20, 0 ].max
    end

    return 100.0 if consistency_scores.empty?
    (consistency_scores.sum / consistency_scores.length).round(2)
  end

  def calculate_validity_score(validation_result)
    # Count validation rule violations
    validity_errors = validation_result.errors.select do |error|
      [ :presence, :format, :range, :data_type ].include?(error.rule_type)
    end

    total_records = validation_result.valid_records.length + validation_result.errors.map(&:record_id).uniq.length
    return 100.0 if total_records == 0

    validity_rate = (total_records - validity_errors.length).to_f / total_records
    (validity_rate * 100).round(2)
  end

  def calculate_timeliness_score(validation_result)
    return 100.0 if validation_result.valid_records.empty?

    now = Time.current
    timeliness_scores = validation_result.valid_records.map do |record|
      created_at = record["created_at"]
      next 50.0 unless created_at.is_a?(Time) || created_at.is_a?(DateTime) || created_at.is_a?(Date)

      age_days = (now - created_at.to_time) / 1.day

      case age_days
      when 0..1 then 100.0
      when 1..7 then 90.0
      when 7..30 then 75.0
      when 30..90 then 50.0
      else 25.0
      end
    end.compact

    return 100.0 if timeliness_scores.empty?
    (timeliness_scores.sum / timeliness_scores.length).round(2)
  end

  def calculate_overall_score(dimension_scores)
    # Weighted average of dimension scores
    weights = {
      completeness: 0.25,
      accuracy: 0.25,
      validity: 0.20,
      consistency: 0.15,
      timeliness: 0.15
    }

    weighted_sum = dimension_scores.sum { |dimension, score| weights[dimension] * score }
    weighted_sum.round(2)
  end

  def classify_value_type(value)
    case value
    when Integer then "integer"
    when Float then "float"
    when TrueClass, FalseClass then "boolean"
    when Date then "date"
    when Time, DateTime then "datetime"
    when String
      return "email" if value.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
      return "url" if value.match?(/\Ahttps?:\/\//)
      return "phone" if value.match?(/\A[\+]?[1-9][\d\s\-\(\)]{7,14}\z/)
      return "numeric_string" if value.match?(/\A\d+\.?\d*\z/)
      "string"
    else "unknown"
    end
  end

  def extract_issues(validation_result)
    issues = []

    # Group errors by type
    error_groups = validation_result.errors.group_by(&:rule_type)

    error_groups.each do |rule_type, errors|
      severity = case rule_type
      when :presence then "high"
      when :data_type, :format then "medium"
      else "low"
      end

      issues << {
        type: rule_type.to_s,
        message: "#{errors.length} #{rule_type.to_s.humanize.downcase} validation errors found",
        severity: severity,
        count: errors.length,
        details: errors.first(5).map(&:message)
      }
    end

    issues
  end

  def generate_recommendations(issues, data_source)
    recommendations = []

    issues.each do |issue|
      case issue[:type]
      when "presence"
        recommendations << {
          title: "Fix Missing Data",
          description: "#{issue[:count]} records have missing required fields. Review data collection process.",
          priority: "high",
          impact: "high",
          action: "data_collection_review"
        }
      when "format"
        recommendations << {
          title: "Standardize Data Formats",
          description: "#{issue[:count]} records have format issues. Implement data validation rules.",
          priority: "medium",
          impact: "medium",
          action: "format_validation"
        }
      when "data_type"
        recommendations << {
          title: "Fix Data Types",
          description: "#{issue[:count]} records have incorrect data types. Update data parsing logic.",
          priority: "medium",
          impact: "high",
          action: "type_conversion"
        }
      end
    end

    # Add general recommendations if no specific issues
    if recommendations.empty?
      recommendations << {
        title: "Maintain Data Quality",
        description: "Data quality is good. Continue monitoring and regular validation.",
        priority: "low",
        impact: "medium",
        action: "monitoring"
      }
    end

    recommendations
  end
end
