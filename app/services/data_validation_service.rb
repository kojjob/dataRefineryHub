class DataValidationService
  attr_accessor :data_source, :validation_rules, :user

  def initialize(data_source:, validation_rules: [], user:)
    @data_source = data_source
    @validation_rules = validation_rules
    @user = user
  end

  def validate
    begin
      Rails.logger.info "Starting data validation for data source #{data_source.id}"
      
      # Get data to validate (use processed data if available, otherwise raw data)
      data_records = data_source.processed_data_records.any? ? 
                    data_source.processed_data_records : 
                    data_source.raw_data_records
      
      return { success: false, error: 'No data found to validate' } if data_records.empty?

      validation_results = []
      total_errors = 0
      total_warnings = 0

      # Apply each validation rule
      validation_rules.each_with_index do |rule, index|
        begin
          result = apply_validation_rule(data_records, rule)
          validation_results << result
          total_errors += result[:error_count]
          total_warnings += result[:warning_count]
        rescue => e
          validation_results << {
            rule_name: rule[:name] || "Rule #{index + 1}",
            rule_type: rule[:type],
            status: 'failed',
            error: e.message,
            error_count: 0,
            warning_count: 0
          }
          Rails.logger.error "Validation rule #{index + 1} failed: #{e.message}"
        end
      end

      # Save validation results
      save_validation_results(validation_results)

      {
        success: true,
        total_records: data_records.count,
        total_errors: total_errors,
        total_warnings: total_warnings,
        validation_results: validation_results,
        summary: generate_validation_summary(validation_results, data_records.count)
      }
    rescue => e
      Rails.logger.error "Data validation failed: #{e.message}"
      { success: false, error: e.message }
    end
  end

  private

  def apply_validation_rule(data_records, rule)
    case rule[:type]
    when 'required_fields'
      validate_required_fields(data_records, rule[:config])
    when 'format_validation'
      validate_format(data_records, rule[:config])
    when 'range_validation'
      validate_range(data_records, rule[:config])
    when 'uniqueness_validation'
      validate_uniqueness(data_records, rule[:config])
    when 'custom_regex'
      validate_custom_regex(data_records, rule[:config])
    when 'data_type_validation'
      validate_data_types(data_records, rule[:config])
    when 'cross_field_validation'
      validate_cross_fields(data_records, rule[:config])
    when 'business_rule_validation'
      validate_business_rules(data_records, rule[:config])
    else
      raise "Unknown validation rule type: #{rule[:type]}"
    end
  end

  def validate_required_fields(data_records, config)
    required_fields = config[:fields] || []
    errors = []
    warnings = []

    data_records.each_with_index do |record, index|
      row_data = record.data
      required_fields.each do |field|
        if row_data[field].nil? || row_data[field].to_s.strip.empty?
          errors << {
            row: index + 1,
            field: field,
            message: "Required field '#{field}' is missing or empty",
            value: row_data[field]
          }
        end
      end
    end

    {
      rule_name: config[:name] || 'Required Fields Validation',
      rule_type: 'required_fields',
      status: errors.empty? ? 'passed' : 'failed',
      error_count: errors.length,
      warning_count: warnings.length,
      errors: errors,
      warnings: warnings
    }
  end

  def validate_format(data_records, config)
    field = config[:field]
    format_type = config[:format_type] # 'email', 'phone', 'url', 'date', 'custom'
    pattern = config[:pattern]
    errors = []
    warnings = []

    regex = case format_type
            when 'email'
              /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i
            when 'phone'
              /\A[\+]?[1-9]?[0-9]{7,15}\z/
            when 'url'
              /\Ahttps?:\/\/[^\s]+\z/
            when 'date'
              /\A\d{4}-\d{2}-\d{2}\z/
            when 'custom'
              Regexp.new(pattern) if pattern.present?
            else
              nil
            end

    return { error: 'Invalid format configuration' } unless regex

    data_records.each_with_index do |record, index|
      row_data = record.data
      value = row_data[field]
      
      if value.present? && !value.to_s.match?(regex)
        errors << {
          row: index + 1,
          field: field,
          message: "Field '#{field}' does not match expected #{format_type} format",
          value: value
        }
      end
    end

    {
      rule_name: config[:name] || "#{format_type.humanize} Format Validation",
      rule_type: 'format_validation',
      status: errors.empty? ? 'passed' : 'failed',
      error_count: errors.length,
      warning_count: warnings.length,
      errors: errors,
      warnings: warnings
    }
  end

  def validate_range(data_records, config)
    field = config[:field]
    min_value = config[:min_value]
    max_value = config[:max_value]
    errors = []
    warnings = []

    data_records.each_with_index do |record, index|
      row_data = record.data
      value = row_data[field]
      
      next if value.nil? || value.to_s.strip.empty?
      
      numeric_value = value.to_f
      
      if min_value.present? && numeric_value < min_value
        errors << {
          row: index + 1,
          field: field,
          message: "Field '#{field}' value #{numeric_value} is below minimum #{min_value}",
          value: value
        }
      end
      
      if max_value.present? && numeric_value > max_value
        errors << {
          row: index + 1,
          field: field,
          message: "Field '#{field}' value #{numeric_value} is above maximum #{max_value}",
          value: value
        }
      end
    end

    {
      rule_name: config[:name] || 'Range Validation',
      rule_type: 'range_validation',
      status: errors.empty? ? 'passed' : 'failed',
      error_count: errors.length,
      warning_count: warnings.length,
      errors: errors,
      warnings: warnings
    }
  end

  def validate_uniqueness(data_records, config)
    fields = config[:fields] || []
    errors = []
    warnings = []
    seen_values = Set.new

    data_records.each_with_index do |record, index|
      row_data = record.data
      
      # Create a composite key from the specified fields
      key_values = fields.map { |field| row_data[field] }
      composite_key = key_values.join('|')
      
      if seen_values.include?(composite_key)
        errors << {
          row: index + 1,
          fields: fields,
          message: "Duplicate values found for fields: #{fields.join(', ')}",
          values: key_values
        }
      else
        seen_values.add(composite_key)
      end
    end

    {
      rule_name: config[:name] || 'Uniqueness Validation',
      rule_type: 'uniqueness_validation',
      status: errors.empty? ? 'passed' : 'failed',
      error_count: errors.length,
      warning_count: warnings.length,
      errors: errors,
      warnings: warnings
    }
  end

  def validate_custom_regex(data_records, config)
    field = config[:field]
    pattern = config[:pattern]
    message = config[:message] || "Field does not match required pattern"
    errors = []
    warnings = []

    begin
      regex = Regexp.new(pattern)
    rescue RegexpError => e
      return {
        rule_name: config[:name] || 'Custom Regex Validation',
        rule_type: 'custom_regex',
        status: 'failed',
        error: "Invalid regex pattern: #{e.message}",
        error_count: 0,
        warning_count: 0
      }
    end

    data_records.each_with_index do |record, index|
      row_data = record.data
      value = row_data[field]
      
      if value.present? && !value.to_s.match?(regex)
        errors << {
          row: index + 1,
          field: field,
          message: message,
          value: value
        }
      end
    end

    {
      rule_name: config[:name] || 'Custom Regex Validation',
      rule_type: 'custom_regex',
      status: errors.empty? ? 'passed' : 'failed',
      error_count: errors.length,
      warning_count: warnings.length,
      errors: errors,
      warnings: warnings
    }
  end

  def validate_data_types(data_records, config)
    field_types = config[:field_types] || {}
    errors = []
    warnings = []

    data_records.each_with_index do |record, index|
      row_data = record.data
      
      field_types.each do |field, expected_type|
        value = row_data[field]
        next if value.nil? || value.to_s.strip.empty?
        
        unless value_matches_type?(value, expected_type)
          errors << {
            row: index + 1,
            field: field,
            message: "Field '#{field}' value '#{value}' is not a valid #{expected_type}",
            value: value,
            expected_type: expected_type
          }
        end
      end
    end

    {
      rule_name: config[:name] || 'Data Type Validation',
      rule_type: 'data_type_validation',
      status: errors.empty? ? 'passed' : 'failed',
      error_count: errors.length,
      warning_count: warnings.length,
      errors: errors,
      warnings: warnings
    }
  end

  def validate_cross_fields(data_records, config)
    # Validate relationships between fields
    rules = config[:rules] || []
    errors = []
    warnings = []

    data_records.each_with_index do |record, index|
      row_data = record.data
      
      rules.each do |rule|
        field1 = rule[:field1]
        field2 = rule[:field2]
        operator = rule[:operator] # 'greater_than', 'less_than', 'equal', 'not_equal'
        
        value1 = row_data[field1]
        value2 = row_data[field2]
        
        next if value1.nil? || value2.nil?
        
        unless values_satisfy_condition?(value1, value2, operator)
          errors << {
            row: index + 1,
            fields: [field1, field2],
            message: "Cross-field validation failed: #{field1} #{operator.humanize} #{field2}",
            values: { field1 => value1, field2 => value2 }
          }
        end
      end
    end

    {
      rule_name: config[:name] || 'Cross-Field Validation',
      rule_type: 'cross_field_validation',
      status: errors.empty? ? 'passed' : 'failed',
      error_count: errors.length,
      warning_count: warnings.length,
      errors: errors,
      warnings: warnings
    }
  end

  def validate_business_rules(data_records, config)
    # Custom business logic validation
    rules = config[:rules] || []
    errors = []
    warnings = []

    data_records.each_with_index do |record, index|
      row_data = record.data
      
      rules.each do |rule|
        begin
          unless evaluate_business_rule(row_data, rule)
            errors << {
              row: index + 1,
              rule: rule[:name] || 'Business Rule',
              message: rule[:error_message] || 'Business rule validation failed',
              data: row_data
            }
          end
        rescue => e
          warnings << {
            row: index + 1,
            rule: rule[:name] || 'Business Rule',
            message: "Business rule evaluation error: #{e.message}",
            data: row_data
          }
        end
      end
    end

    {
      rule_name: config[:name] || 'Business Rules Validation',
      rule_type: 'business_rule_validation',
      status: errors.empty? ? 'passed' : 'failed',
      error_count: errors.length,
      warning_count: warnings.length,
      errors: errors,
      warnings: warnings
    }
  end

  def value_matches_type?(value, expected_type)
    case expected_type
    when 'integer'
      value.to_s.match?(/\A-?\d+\z/)
    when 'float', 'decimal'
      value.to_s.match?(/\A-?\d*\.?\d+\z/)
    when 'boolean'
      ['true', 'false', '1', '0', 'yes', 'no'].include?(value.to_s.downcase)
    when 'date'
      begin
        Date.parse(value.to_s)
        true
      rescue
        false
      end
    when 'datetime'
      begin
        DateTime.parse(value.to_s)
        true
      rescue
        false
      end
    when 'string'
      true # Any value can be a string
    else
      false
    end
  end

  def values_satisfy_condition?(value1, value2, operator)
    # Convert to comparable types if possible
    if value1.to_s.match?(/\A-?\d*\.?\d+\z/) && value2.to_s.match?(/\A-?\d*\.?\d+\z/)
      value1 = value1.to_f
      value2 = value2.to_f
    end

    case operator
    when 'greater_than'
      value1 > value2
    when 'less_than'
      value1 < value2
    when 'greater_than_or_equal'
      value1 >= value2
    when 'less_than_or_equal'
      value1 <= value2
    when 'equal'
      value1 == value2
    when 'not_equal'
      value1 != value2
    else
      false
    end
  end

  def evaluate_business_rule(row_data, rule)
    # Simple business rule evaluation
    # This can be enhanced with a proper expression parser
    condition = rule[:condition]
    
    # Replace field references with actual values
    processed_condition = condition.dup
    row_data.each do |field, value|
      processed_condition.gsub!("{{#{field}}}", "'#{value}'")
    end
    
    # For safety, only allow simple comparisons
    if processed_condition.match?(/^[\w\s'"\d\.<>=!]+$/)
      begin
        eval(processed_condition)
      rescue
        false
      end
    else
      false
    end
  end

  def save_validation_results(validation_results)
    # Save validation results to the database
    # This could be a separate ValidationResult model
    data_source.update(
      last_validation_at: Time.current,
      validation_results: {
        timestamp: Time.current.iso8601,
        results: validation_results
      }
    )
  end

  def generate_validation_summary(validation_results, total_records)
    passed_rules = validation_results.count { |result| result[:status] == 'passed' }
    failed_rules = validation_results.count { |result| result[:status] == 'failed' }
    
    {
      total_rules: validation_results.length,
      passed_rules: passed_rules,
      failed_rules: failed_rules,
      total_records: total_records,
      success_rate: (passed_rules.to_f / validation_results.length * 100).round(2)
    }
  end
end