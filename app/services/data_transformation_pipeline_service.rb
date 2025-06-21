class DataTransformationPipelineService
  attr_accessor :data_source, :transformations, :user

  def initialize(data_source:, transformations: [], user:)
    @data_source = data_source
    @transformations = transformations
    @user = user
  end

  def execute
    begin
      Rails.logger.info "Starting data transformation pipeline for data source #{data_source.id}"
      
      # Get raw data
      raw_data = data_source.raw_data_records
      return { success: false, error: 'No raw data found' } if raw_data.empty?

      # Apply transformations in sequence
      transformed_data = raw_data.map(&:data)
      transformation_log = []

      transformations.each_with_index do |transformation, index|
        begin
          result = apply_transformation(transformed_data, transformation)
          transformed_data = result[:data]
          transformation_log << {
            step: index + 1,
            transformation: transformation,
            status: 'success',
            records_processed: transformed_data.length,
            message: result[:message]
          }
        rescue => e
          transformation_log << {
            step: index + 1,
            transformation: transformation,
            status: 'error',
            error: e.message
          }
          Rails.logger.error "Transformation step #{index + 1} failed: #{e.message}"
        end
      end

      # Save transformed data
      save_transformed_data(transformed_data)

      {
        success: true,
        records_processed: transformed_data.length,
        transformation_log: transformation_log,
        summary: generate_transformation_summary(transformation_log)
      }
    rescue => e
      Rails.logger.error "Data transformation pipeline failed: #{e.message}"
      { success: false, error: e.message }
    end
  end

  private

  def apply_transformation(data, transformation)
    case transformation[:type]
    when 'data_type_conversion'
      apply_data_type_conversion(data, transformation[:config])
    when 'null_handling'
      apply_null_handling(data, transformation[:config])
    when 'duplicate_detection'
      apply_duplicate_detection(data, transformation[:config])
    when 'column_mapping'
      apply_column_mapping(data, transformation[:config])
    when 'normalization'
      apply_normalization(data, transformation[:config])
    when 'calculated_fields'
      apply_calculated_fields(data, transformation[:config])
    when 'data_cleaning'
      apply_data_cleaning(data, transformation[:config])
    else
      raise "Unknown transformation type: #{transformation[:type]}"
    end
  end

  def apply_data_type_conversion(data, config)
    converted_data = data.map do |row|
      new_row = row.dup
      config[:conversions].each do |conversion|
        field = conversion[:field]
        target_type = conversion[:target_type]
        
        if new_row.key?(field) && !new_row[field].nil?
          new_row[field] = convert_value(new_row[field], target_type)
        end
      end
      new_row
    end
    
    {
      data: converted_data,
      message: "Converted #{config[:conversions].length} fields"
    }
  end

  def apply_null_handling(data, config)
    strategy = config[:strategy] # 'remove', 'fill_default', 'fill_mean', 'fill_mode'
    fields = config[:fields] || []
    
    case strategy
    when 'remove'
      filtered_data = data.reject do |row|
        fields.any? { |field| row[field].nil? || row[field].to_s.strip.empty? }
      end
      { data: filtered_data, message: "Removed #{data.length - filtered_data.length} rows with null values" }
    when 'fill_default'
      filled_data = data.map do |row|
        new_row = row.dup
        fields.each do |field|
          if new_row[field].nil? || new_row[field].to_s.strip.empty?
            new_row[field] = config[:default_values][field] || ''
          end
        end
        new_row
      end
      { data: filled_data, message: "Filled null values with defaults" }
    else
      { data: data, message: "No null handling applied" }
    end
  end

  def apply_duplicate_detection(data, config)
    key_fields = config[:key_fields] || []
    strategy = config[:strategy] || 'remove' # 'remove', 'mark', 'keep_first', 'keep_last'
    
    if key_fields.empty?
      # Use all fields for duplicate detection
      unique_data = data.uniq
    else
      # Use specific fields for duplicate detection
      seen = Set.new
      unique_data = data.select do |row|
        key = key_fields.map { |field| row[field] }.join('|')
        !seen.include?(key) && seen.add(key)
      end
    end
    
    {
      data: unique_data,
      message: "Removed #{data.length - unique_data.length} duplicate records"
    }
  end

  def apply_column_mapping(data, config)
    mappings = config[:mappings] || {}
    
    mapped_data = data.map do |row|
      new_row = {}
      row.each do |key, value|
        new_key = mappings[key] || key
        new_row[new_key] = value
      end
      new_row
    end
    
    {
      data: mapped_data,
      message: "Applied #{mappings.length} column mappings"
    }
  end

  def apply_normalization(data, config)
    fields = config[:fields] || []
    method = config[:method] || 'trim' # 'trim', 'lowercase', 'uppercase', 'title_case'
    
    normalized_data = data.map do |row|
      new_row = row.dup
      fields.each do |field|
        if new_row[field].is_a?(String)
          case method
          when 'trim'
            new_row[field] = new_row[field].strip
          when 'lowercase'
            new_row[field] = new_row[field].downcase
          when 'uppercase'
            new_row[field] = new_row[field].upcase
          when 'title_case'
            new_row[field] = new_row[field].titleize
          end
        end
      end
      new_row
    end
    
    {
      data: normalized_data,
      message: "Normalized #{fields.length} fields using #{method}"
    }
  end

  def apply_calculated_fields(data, config)
    calculations = config[:calculations] || []
    
    enhanced_data = data.map do |row|
      new_row = row.dup
      calculations.each do |calc|
        field_name = calc[:field_name]
        expression = calc[:expression]
        
        begin
          # Simple expression evaluation (can be enhanced with a proper expression parser)
          new_row[field_name] = evaluate_expression(expression, row)
        rescue => e
          Rails.logger.warn "Failed to calculate field #{field_name}: #{e.message}"
          new_row[field_name] = nil
        end
      end
      new_row
    end
    
    {
      data: enhanced_data,
      message: "Added #{calculations.length} calculated fields"
    }
  end

  def apply_data_cleaning(data, config)
    rules = config[:rules] || []
    
    cleaned_data = data.map do |row|
      new_row = row.dup
      rules.each do |rule|
        field = rule[:field]
        action = rule[:action] # 'remove_special_chars', 'fix_encoding', 'standardize_format'
        
        if new_row[field].is_a?(String)
          case action
          when 'remove_special_chars'
            new_row[field] = new_row[field].gsub(/[^\w\s]/, '')
          when 'fix_encoding'
            new_row[field] = new_row[field].encode('UTF-8', invalid: :replace, undef: :replace)
          when 'standardize_format'
            # Apply specific formatting rules based on field type
            new_row[field] = standardize_field_format(new_row[field], rule[:format_type])
          end
        end
      end
      new_row
    end
    
    {
      data: cleaned_data,
      message: "Applied #{rules.length} data cleaning rules"
    }
  end

  def convert_value(value, target_type)
    case target_type
    when 'integer'
      value.to_i
    when 'float'
      value.to_f
    when 'boolean'
      ['true', '1', 'yes', 'y'].include?(value.to_s.downcase)
    when 'date'
      Date.parse(value.to_s) rescue nil
    when 'datetime'
      DateTime.parse(value.to_s) rescue nil
    when 'string'
      value.to_s
    else
      value
    end
  end

  def evaluate_expression(expression, row)
    # Simple expression evaluator - can be enhanced with a proper parser
    # For now, support basic arithmetic and field references
    
    # Replace field references with actual values
    processed_expression = expression.dup
    row.each do |field, value|
      if value.is_a?(Numeric)
        processed_expression.gsub!("{{#{field}}}", value.to_s)
      end
    end
    
    # Evaluate simple arithmetic expressions
    begin
      eval(processed_expression) if processed_expression.match?(/^[\d\s\+\-\*\/\(\)\.]+$/)
    rescue
      nil
    end
  end

  def standardize_field_format(value, format_type)
    case format_type
    when 'phone'
      # Remove all non-digits and format as phone number
      digits = value.gsub(/\D/, '')
      if digits.length == 10
        "(#{digits[0..2]}) #{digits[3..5]}-#{digits[6..9]}"
      else
        value
      end
    when 'email'
      value.downcase.strip
    when 'currency'
      # Remove currency symbols and format as decimal
      value.gsub(/[^\d\.]/, '').to_f
    else
      value
    end
  end

  def save_transformed_data(data)
    # Clear existing processed data
    data_source.processed_data_records.destroy_all
    
    # Save new processed data
    data.each_with_index do |row_data, index|
      data_source.processed_data_records.create!(
        data: row_data,
        row_number: index + 1,
        created_by: user
      )
    end
  end

  def generate_transformation_summary(transformation_log)
    successful_steps = transformation_log.count { |step| step[:status] == 'success' }
    failed_steps = transformation_log.count { |step| step[:status] == 'error' }
    
    {
      total_steps: transformation_log.length,
      successful_steps: successful_steps,
      failed_steps: failed_steps,
      success_rate: (successful_steps.to_f / transformation_log.length * 100).round(2)
    }
  end
end