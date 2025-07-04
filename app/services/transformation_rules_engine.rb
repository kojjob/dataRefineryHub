# TransformationRulesEngine
# Advanced rule-based transformation engine for ETL/ELT pipelines
class TransformationRulesEngine
  include Singleton
  
  RULE_TYPES = %w[
    field_mapping rename_field type_conversion 
    calculated_field filter aggregate join 
    pivot unpivot lookup validation
    data_quality custom_function
  ].freeze
  
  def initialize
    @logger = Rails.logger
    @rule_registry = {}
    @function_library = {}
    @validators = {}
    
    register_built_in_rules
    register_built_in_functions
  end
  
  def apply_transformations(data, transformation_rules, context = {})
    result = data
    applied_rules = []
    
    transformation_rules.each do |rule|
      @logger.debug "Applying transformation rule: #{rule[:type]}"
      
      begin
        result = apply_single_rule(result, rule, context)
        applied_rules << rule.merge(status: 'success')
      rescue => e
        @logger.error "Transformation rule failed: #{e.message}"
        
        if rule[:on_error] == 'skip'
          applied_rules << rule.merge(status: 'skipped', error: e.message)
          next
        else
          raise TransformationError, "Rule '#{rule[:name]}' failed: #{e.message}"
        end
      end
    end
    
    {
      data: result,
      applied_rules: applied_rules,
      row_count: result.is_a?(Array) ? result.size : 1
    }
  end
  
  def validate_rule(rule)
    validator = @validators[rule[:type]]
    return { valid: false, error: "Unknown rule type: #{rule[:type]}" } unless validator
    
    validator.call(rule)
  end
  
  def register_custom_function(name, &block)
    @function_library[name.to_s] = block
  end
  
  def get_available_functions
    @function_library.keys
  end
  
  private
  
  def apply_single_rule(data, rule, context)
    handler = @rule_registry[rule[:type]]
    raise ArgumentError, "Unknown rule type: #{rule[:type]}" unless handler
    
    handler.call(data, rule, context)
  end
  
  def register_built_in_rules
    # Field Mapping
    @rule_registry['field_mapping'] = ->(data, rule, context) {
      mapping = rule[:mapping] || {}
      
      data.map do |record|
        new_record = {}
        
        mapping.each do |source_field, target_field|
          value = get_nested_value(record, source_field)
          set_nested_value(new_record, target_field, value)
        end
        
        # Include unmapped fields if configured
        if rule[:include_unmapped]
          record.each do |key, value|
            new_record[key] = value unless mapping.key?(key)
          end
        end
        
        new_record
      end
    }
    
    # Rename Field
    @rule_registry['rename_field'] = ->(data, rule, context) {
      from_field = rule[:from]
      to_field = rule[:to]
      
      data.map do |record|
        new_record = record.dup
        
        if new_record.key?(from_field)
          new_record[to_field] = new_record.delete(from_field)
        end
        
        new_record
      end
    }
    
    # Type Conversion
    @rule_registry['type_conversion'] = ->(data, rule, context) {
      field = rule[:field]
      target_type = rule[:target_type]
      format = rule[:format]
      
      data.map do |record|
        new_record = record.dup
        
        if new_record.key?(field)
          new_record[field] = convert_type(new_record[field], target_type, format)
        end
        
        new_record
      end
    }
    
    # Calculated Field
    @rule_registry['calculated_field'] = ->(data, rule, context) {
      field_name = rule[:field_name]
      expression = rule[:expression]
      
      data.map do |record|
        new_record = record.dup
        new_record[field_name] = evaluate_expression(expression, record, context)
        new_record
      end
    }
    
    # Filter
    @rule_registry['filter'] = ->(data, rule, context) {
      condition = rule[:condition]
      
      data.select do |record|
        evaluate_condition(condition, record, context)
      end
    }
    
    # Aggregate
    @rule_registry['aggregate'] = ->(data, rule, context) {
      group_by = Array(rule[:group_by])
      aggregations = rule[:aggregations] || []
      
      # Group data
      grouped = data.group_by { |record| 
        group_by.map { |field| record[field] }
      }
      
      # Apply aggregations
      grouped.map do |group_key, group_records|
        result = {}
        
        # Add group by fields
        group_by.each_with_index do |field, index|
          result[field] = group_key[index]
        end
        
        # Apply aggregation functions
        aggregations.each do |agg|
          field = agg[:field]
          function = agg[:function]
          alias_name = agg[:alias] || "#{function}_#{field}"
          
          result[alias_name] = apply_aggregation(group_records, field, function)
        end
        
        result
      end
    }
    
    # Join
    @rule_registry['join'] = ->(data, rule, context) {
      right_data = rule[:right_data] || context[:lookup_data]&.[](rule[:lookup_name])
      join_type = rule[:join_type] || 'inner'
      left_key = rule[:left_key]
      right_key = rule[:right_key]
      
      raise ArgumentError, "Right data not provided for join" unless right_data
      
      # Create lookup hash for performance
      right_lookup = right_data.group_by { |r| r[right_key] }
      
      case join_type
      when 'inner'
        data.flat_map do |left_record|
          matches = right_lookup[left_record[left_key]] || []
          matches.map { |right_record| left_record.merge(right_record) }
        end.compact
      when 'left'
        data.map do |left_record|
          matches = right_lookup[left_record[left_key]] || []
          if matches.empty?
            left_record
          else
            matches.map { |right_record| left_record.merge(right_record) }
          end
        end.flatten
      when 'right'
        # Convert to left join by swapping
        right_data.map do |right_record|
          matches = data.select { |l| l[left_key] == right_record[right_key] }
          if matches.empty?
            right_record
          else
            matches.map { |left_record| left_record.merge(right_record) }
          end
        end.flatten
      else
        raise ArgumentError, "Unsupported join type: #{join_type}"
      end
    }
    
    # Pivot
    @rule_registry['pivot'] = ->(data, rule, context) {
      index_columns = Array(rule[:index])
      pivot_column = rule[:pivot_column]
      value_column = rule[:value_column]
      aggregation = rule[:aggregation] || 'first'
      
      # Group by index columns
      grouped = data.group_by { |record|
        index_columns.map { |col| record[col] }
      }
      
      grouped.map do |group_key, group_records|
        result = {}
        
        # Set index columns
        index_columns.each_with_index do |col, idx|
          result[col] = group_key[idx]
        end
        
        # Pivot values
        pivot_groups = group_records.group_by { |r| r[pivot_column] }
        
        pivot_groups.each do |pivot_value, pivot_records|
          values = pivot_records.map { |r| r[value_column] }
          result[pivot_value.to_s] = apply_aggregation_to_values(values, aggregation)
        end
        
        result
      end
    }
    
    # Unpivot
    @rule_registry['unpivot'] = ->(data, rule, context) {
      id_columns = Array(rule[:id_columns])
      value_columns = Array(rule[:value_columns])
      variable_name = rule[:variable_name] || 'variable'
      value_name = rule[:value_name] || 'value'
      
      data.flat_map do |record|
        value_columns.map do |col|
          new_record = {}
          
          # Copy ID columns
          id_columns.each { |id_col| new_record[id_col] = record[id_col] }
          
          # Add variable and value
          new_record[variable_name] = col
          new_record[value_name] = record[col]
          
          new_record
        end
      end
    }
    
    # Lookup
    @rule_registry['lookup'] = ->(data, rule, context) {
      lookup_data = rule[:lookup_data] || context[:lookup_data]&.[](rule[:lookup_name])
      lookup_key = rule[:lookup_key]
      data_key = rule[:data_key]
      fields_to_add = rule[:fields] || :all
      
      raise ArgumentError, "Lookup data not provided" unless lookup_data
      
      # Create lookup hash
      lookup_hash = lookup_data.index_by { |r| r[lookup_key] }
      
      data.map do |record|
        lookup_value = record[data_key]
        lookup_record = lookup_hash[lookup_value]
        
        if lookup_record
          fields = fields_to_add == :all ? lookup_record.keys : Array(fields_to_add)
          
          new_record = record.dup
          fields.each do |field|
            new_record["#{rule[:prefix]}#{field}"] = lookup_record[field] if lookup_record.key?(field)
          end
          
          new_record
        else
          record
        end
      end
    }
    
    # Validation
    @rule_registry['validation'] = ->(data, rule, context) {
      validations = rule[:validations] || []
      error_handling = rule[:error_handling] || 'exclude'
      
      validated_data = []
      errors = []
      
      data.each_with_index do |record, index|
        validation_errors = []
        
        validations.each do |validation|
          field = validation[:field]
          validation_type = validation[:type]
          
          unless validate_field(record[field], validation)
            validation_errors << {
              field: field,
              type: validation_type,
              value: record[field],
              message: validation[:message] || "Validation failed"
            }
          end
        end
        
        if validation_errors.empty?
          validated_data << record
        else
          case error_handling
          when 'exclude'
            # Skip invalid records
            errors << { index: index, record: record, errors: validation_errors }
          when 'include_with_errors'
            record['_validation_errors'] = validation_errors
            validated_data << record
          when 'fail'
            raise ValidationError, "Record #{index} failed validation: #{validation_errors}"
          end
        end
      end
      
      # Store errors in context for reporting
      context[:validation_errors] = errors if errors.any?
      
      validated_data
    }
    
    # Data Quality
    @rule_registry['data_quality'] = ->(data, rule, context) {
      checks = rule[:checks] || []
      
      data.map do |record|
        quality_score = 0
        quality_issues = []
        
        checks.each do |check|
          field = check[:field]
          check_type = check[:type]
          
          if perform_quality_check(record[field], check)
            quality_score += check[:weight] || 1
          else
            quality_issues << {
              field: field,
              type: check_type,
              severity: check[:severity] || 'warning'
            }
          end
        end
        
        record.merge(
          '_quality_score' => quality_score,
          '_quality_issues' => quality_issues
        )
      end
    }
    
    # Custom Function
    @rule_registry['custom_function'] = ->(data, rule, context) {
      function_name = rule[:function]
      function = @function_library[function_name]
      
      raise ArgumentError, "Unknown function: #{function_name}" unless function
      
      function.call(data, rule[:params] || {}, context)
    }
  end
  
  def register_built_in_functions
    # String functions
    @function_library['upper'] = ->(value) { value.to_s.upcase }
    @function_library['lower'] = ->(value) { value.to_s.downcase }
    @function_library['trim'] = ->(value) { value.to_s.strip }
    @function_library['substring'] = ->(value, start, length = nil) { 
      length ? value.to_s[start, length] : value.to_s[start..-1]
    }
    @function_library['replace'] = ->(value, search, replace) { 
      value.to_s.gsub(search, replace)
    }
    @function_library['concat'] = ->(*values) { values.join('') }
    
    # Numeric functions
    @function_library['abs'] = ->(value) { value.to_f.abs }
    @function_library['round'] = ->(value, decimals = 0) { value.to_f.round(decimals) }
    @function_library['ceil'] = ->(value) { value.to_f.ceil }
    @function_library['floor'] = ->(value) { value.to_f.floor }
    
    # Date functions
    @function_library['now'] = ->() { Time.current }
    @function_library['today'] = ->() { Date.current }
    @function_library['date_add'] = ->(date, amount, unit = 'days') {
      date = parse_date(date)
      case unit
      when 'days' then date + amount.days
      when 'months' then date + amount.months
      when 'years' then date + amount.years
      else date
      end
    }
    @function_library['date_diff'] = ->(date1, date2, unit = 'days') {
      d1 = parse_date(date1)
      d2 = parse_date(date2)
      
      case unit
      when 'days' then (d1 - d2).to_i
      when 'months' then ((d1 - d2) / 30).to_i
      when 'years' then ((d1 - d2) / 365).to_i
      else (d1 - d2).to_i
      end
    }
    
    # Logical functions
    @function_library['if'] = ->(condition, true_value, false_value) {
      condition ? true_value : false_value
    }
    @function_library['coalesce'] = ->(*values) {
      values.find { |v| !v.nil? && v != '' }
    }
    @function_library['case'] = ->(value, cases, default = nil) {
      cases[value] || default
    }
    
    # Array functions
    @function_library['array_length'] = ->(array) { Array(array).length }
    @function_library['array_contains'] = ->(array, value) { Array(array).include?(value) }
    @function_library['array_join'] = ->(array, separator = ',') { Array(array).join(separator) }
    
    # Hash/Object functions
    @function_library['json_extract'] = ->(json, path) {
      data = json.is_a?(String) ? JSON.parse(json) : json
      path.split('.').reduce(data) { |obj, key| obj[key] if obj }
    }
  end
  
  def get_nested_value(hash, path)
    path.split('.').reduce(hash) { |obj, key| obj[key] if obj }
  end
  
  def set_nested_value(hash, path, value)
    keys = path.split('.')
    last_key = keys.pop
    
    target = keys.reduce(hash) { |obj, key| obj[key] ||= {} }
    target[last_key] = value
  end
  
  def convert_type(value, target_type, format = nil)
    return nil if value.nil?
    
    case target_type
    when 'string'
      value.to_s
    when 'integer'
      value.to_i
    when 'float'
      value.to_f
    when 'boolean'
      ActiveModel::Type::Boolean.new.cast(value)
    when 'date'
      parse_date(value, format)
    when 'datetime'
      parse_datetime(value, format)
    when 'json'
      value.is_a?(String) ? JSON.parse(value) : value
    else
      value
    end
  rescue => e
    @logger.warn "Type conversion failed: #{e.message}"
    nil
  end
  
  def parse_date(value, format = nil)
    return value if value.is_a?(Date)
    return value.to_date if value.is_a?(Time) || value.is_a?(DateTime)
    
    if format
      Date.strptime(value.to_s, format)
    else
      Date.parse(value.to_s)
    end
  end
  
  def parse_datetime(value, format = nil)
    return value if value.is_a?(DateTime)
    return value.to_datetime if value.is_a?(Time) || value.is_a?(Date)
    
    if format
      DateTime.strptime(value.to_s, format)
    else
      DateTime.parse(value.to_s)
    end
  end
  
  def evaluate_expression(expression, record, context)
    # Simple expression evaluator
    # In production, use a proper expression parser
    
    # Replace field references
    expr = expression.gsub(/\{(\w+)\}/) { |match| record[$1].to_s }
    
    # Replace function calls
    expr.gsub!(/(\w+)\((.*?)\)/) do |match|
      function_name = $1
      args = $2.split(',').map(&:strip).map { |arg|
        # Handle string literals
        if arg.start_with?('"') && arg.end_with?('"')
          arg[1..-2]
        elsif arg =~ /^\d+$/
          arg.to_i
        elsif arg =~ /^\d+\.\d+$/
          arg.to_f
        else
          # Field reference
          record[arg]
        end
      }
      
      if function = @function_library[function_name]
        function.call(*args)
      else
        match
      end
    end
    
    # Evaluate simple arithmetic
    begin
      eval(expr)
    rescue => e
      @logger.warn "Expression evaluation failed: #{e.message}"
      nil
    end
  end
  
  def evaluate_condition(condition, record, context)
    case condition
    when Hash
      operator = condition[:operator] || 'and'
      conditions = condition[:conditions] || []
      
      case operator
      when 'and'
        conditions.all? { |c| evaluate_single_condition(c, record, context) }
      when 'or'
        conditions.any? { |c| evaluate_single_condition(c, record, context) }
      when 'not'
        !evaluate_single_condition(conditions.first, record, context)
      else
        evaluate_single_condition(condition, record, context)
      end
    else
      evaluate_single_condition(condition, record, context)
    end
  end
  
  def evaluate_single_condition(condition, record, context)
    field = condition[:field]
    operator = condition[:operator]
    value = condition[:value]
    field_value = record[field]
    
    case operator
    when '=', '=='
      field_value == value
    when '!='
      field_value != value
    when '>'
      field_value > value
    when '>='
      field_value >= value
    when '<'
      field_value < value
    when '<='
      field_value <= value
    when 'in'
      Array(value).include?(field_value)
    when 'not_in'
      !Array(value).include?(field_value)
    when 'contains'
      field_value.to_s.include?(value.to_s)
    when 'starts_with'
      field_value.to_s.start_with?(value.to_s)
    when 'ends_with'
      field_value.to_s.end_with?(value.to_s)
    when 'matches'
      field_value.to_s.match?(Regexp.new(value))
    when 'is_null'
      field_value.nil?
    when 'is_not_null'
      !field_value.nil?
    when 'is_empty'
      field_value.nil? || field_value == ''
    when 'is_not_empty'
      !field_value.nil? && field_value != ''
    else
      true
    end
  end
  
  def apply_aggregation(records, field, function)
    values = records.map { |r| r[field] }.compact
    
    case function
    when 'count'
      records.size
    when 'count_distinct'
      values.uniq.size
    when 'sum'
      values.sum(&:to_f)
    when 'avg', 'average'
      values.empty? ? nil : values.sum(&:to_f) / values.size
    when 'min'
      values.min
    when 'max'
      values.max
    when 'first'
      records.first&.[](field)
    when 'last'
      records.last&.[](field)
    when 'concat'
      values.join(', ')
    when 'collect'
      values
    else
      nil
    end
  end
  
  def apply_aggregation_to_values(values, function)
    case function
    when 'first'
      values.first
    when 'last'
      values.last
    when 'sum'
      values.sum(&:to_f)
    when 'avg', 'average'
      values.empty? ? nil : values.sum(&:to_f) / values.size
    when 'min'
      values.min
    when 'max'
      values.max
    when 'count'
      values.size
    when 'collect'
      values
    else
      values.first
    end
  end
  
  def validate_field(value, validation)
    case validation[:type]
    when 'required'
      !value.nil? && value != ''
    when 'type'
      validate_type(value, validation[:expected_type])
    when 'pattern'
      value.to_s.match?(Regexp.new(validation[:pattern]))
    when 'range'
      value >= validation[:min] && value <= validation[:max]
    when 'length'
      length = value.to_s.length
      (!validation[:min] || length >= validation[:min]) &&
        (!validation[:max] || length <= validation[:max])
    when 'values'
      validation[:allowed_values].include?(value)
    when 'unique'
      # This would need to track seen values
      true
    else
      true
    end
  end
  
  def validate_type(value, expected_type)
    case expected_type
    when 'string'
      value.is_a?(String)
    when 'integer'
      value.is_a?(Integer) || value.to_s =~ /^\d+$/
    when 'float'
      value.is_a?(Numeric)
    when 'boolean'
      [true, false, 'true', 'false', 1, 0].include?(value)
    when 'date'
      value.is_a?(Date) || Date.parse(value.to_s) rescue false
    when 'datetime'
      value.is_a?(DateTime) || value.is_a?(Time) || DateTime.parse(value.to_s) rescue false
    else
      true
    end
  end
  
  def perform_quality_check(value, check)
    case check[:type]
    when 'not_null'
      !value.nil?
    when 'not_empty'
      !value.nil? && value != ''
    when 'format'
      value.to_s.match?(Regexp.new(check[:pattern]))
    when 'completeness'
      !value.nil? && value != '' && value != check[:null_value]
    when 'consistency'
      # Would need to check against other records
      true
    when 'accuracy'
      # Would need external validation
      true
    else
      true
    end
  end
  
  class TransformationError < StandardError; end
  class ValidationError < StandardError; end
end