# frozen_string_literal: true

# Comprehensive input validation service to prevent security vulnerabilities
class InputValidatorService
  class ValidationError < StandardError; end
  
  ALLOWED_MIME_TYPES = %w[
    text/csv
    application/vnd.ms-excel
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
    application/json
    text/plain
  ].freeze
  
  SQL_INJECTION_PATTERNS = [
    /(\s|^)(SELECT|INSERT|UPDATE|DELETE|DROP|UNION|ALTER|CREATE|EXEC|SCRIPT)(\s|$)/i,
    /(\s|^)(OR|AND)\s+\d+\s*=\s*\d+/i,
    /(\s|^)(--)|(\/\*)|(\*\/)/,
    /(\s|^)(xp_|sp_|0x)/i,
    /(\s|^)(WAITFOR|DELAY|BENCHMARK)/i
  ].freeze
  
  XSS_PATTERNS = [
    /<script[^>]*>.*?<\/script>/mi,
    /<iframe[^>]*>.*?<\/iframe>/mi,
    /javascript:/i,
    /on\w+\s*=/i,
    /<embed[^>]*>/i,
    /<object[^>]*>/i
  ].freeze
  
  PATH_TRAVERSAL_PATTERNS = [
    /\.\./,
    /\.\.%2F/i,
    /%2E%2E/i,
    /\.\.\\/
  ].freeze
  
  class << self
    # Validate and sanitize string input
    def sanitize_string(input, options = {})
      return nil if input.nil?
      return '' if input.to_s.strip.empty?
      
      str = input.to_s.strip
      
      # Check length constraints
      max_length = options[:max_length] || 10_000
      raise ValidationError, "Input exceeds maximum length of #{max_length}" if str.length > max_length
      
      # Check for SQL injection patterns
      if options[:prevent_sql_injection] != false
        check_sql_injection(str)
      end
      
      # Check for XSS patterns
      if options[:prevent_xss] != false
        check_xss(str)
      end
      
      # Sanitize HTML if needed
      if options[:sanitize_html]
        str = sanitize_html(str, options[:allowed_tags] || [])
      end
      
      # Apply whitelist if provided
      if options[:whitelist]
        unless options[:whitelist].include?(str)
          raise ValidationError, "Input not in allowed values"
        end
      end
      
      # Apply regex pattern if provided
      if options[:pattern]
        unless str.match?(options[:pattern])
          raise ValidationError, "Input does not match required pattern"
        end
      end
      
      str
    end
    
    # Validate email format
    def validate_email(email)
      email_regex = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i
      
      unless email.to_s.match?(email_regex)
        raise ValidationError, "Invalid email format"
      end
      
      email.to_s.downcase.strip
    end
    
    # Validate URL format
    def validate_url(url, options = {})
      require 'uri'
      
      uri = URI.parse(url.to_s)
      
      # Check scheme
      allowed_schemes = options[:allowed_schemes] || %w[http https]
      unless allowed_schemes.include?(uri.scheme)
        raise ValidationError, "URL scheme not allowed"
      end
      
      # Check host
      if options[:allowed_hosts]
        unless options[:allowed_hosts].include?(uri.host)
          raise ValidationError, "URL host not allowed"
        end
      end
      
      uri.to_s
    rescue URI::InvalidURIError
      raise ValidationError, "Invalid URL format"
    end
    
    # Validate file upload
    def validate_file_upload(file, options = {})
      return nil if file.nil?
      
      # Check file size
      max_size = options[:max_size] || 50.megabytes
      if file.size > max_size
        raise ValidationError, "File size exceeds maximum of #{max_size / 1.megabyte}MB"
      end
      
      # Check MIME type
      allowed_types = options[:allowed_types] || ALLOWED_MIME_TYPES
      unless allowed_types.include?(file.content_type)
        raise ValidationError, "File type #{file.content_type} not allowed"
      end
      
      # Check filename for path traversal
      check_path_traversal(file.original_filename)
      
      # Scan file content for malicious patterns if text-based
      if file.content_type.start_with?('text/') || file.content_type == 'application/json'
        content = file.read
        file.rewind
        check_file_content(content)
      end
      
      file
    end
    
    # Validate numeric input
    def validate_number(input, options = {})
      num = case input
            when Integer, Float then input
            when String then input.to_f
            else raise ValidationError, "Invalid number format"
            end
      
      # Check range
      if options[:min] && num < options[:min]
        raise ValidationError, "Number must be at least #{options[:min]}"
      end
      
      if options[:max] && num > options[:max]
        raise ValidationError, "Number must be at most #{options[:max]}"
      end
      
      # Check if integer required
      if options[:integer_only] && num != num.to_i
        raise ValidationError, "Must be an integer"
      end
      
      options[:integer_only] ? num.to_i : num
    end
    
    # Validate date/time input
    def validate_datetime(input, options = {})
      return nil if input.nil? && options[:allow_nil]
      
      datetime = case input
                 when DateTime, Time then input
                 when String then DateTime.parse(input)
                 when Date then input.to_datetime
                 else raise ValidationError, "Invalid datetime format"
                 end
      
      # Check if in future
      if options[:future_only] && datetime <= DateTime.current
        raise ValidationError, "Date must be in the future"
      end
      
      # Check if in past
      if options[:past_only] && datetime >= DateTime.current
        raise ValidationError, "Date must be in the past"
      end
      
      # Check range
      if options[:after] && datetime <= options[:after]
        raise ValidationError, "Date must be after #{options[:after]}"
      end
      
      if options[:before] && datetime >= options[:before]
        raise ValidationError, "Date must be before #{options[:before]}"
      end
      
      datetime
    rescue ArgumentError
      raise ValidationError, "Invalid datetime format"
    end
    
    # Validate JSON input
    def validate_json(input, schema = nil)
      json = case input
             when String then JSON.parse(input)
             when Hash, Array then input
             else raise ValidationError, "Invalid JSON format"
             end
      
      # Validate against schema if provided
      if schema
        validate_json_schema(json, schema)
      end
      
      json
    rescue JSON::ParserError
      raise ValidationError, "Invalid JSON format"
    end
    
    # Validate parameters for ActiveRecord queries
    def validate_query_params(params)
      sanitized = {}
      
      # Validate sort parameters
      if params[:sort_by]
        allowed_columns = params[:allowed_sort_columns] || []
        unless allowed_columns.include?(params[:sort_by].to_s)
          raise ValidationError, "Invalid sort column"
        end
        sanitized[:sort_by] = params[:sort_by].to_s
      end
      
      # Validate sort direction
      if params[:sort_direction]
        unless %w[asc desc ASC DESC].include?(params[:sort_direction].to_s)
          raise ValidationError, "Invalid sort direction"
        end
        sanitized[:sort_direction] = params[:sort_direction].to_s.downcase
      end
      
      # Validate page number
      if params[:page]
        sanitized[:page] = validate_number(params[:page], min: 1, integer_only: true)
      end
      
      # Validate per page
      if params[:per_page]
        sanitized[:per_page] = validate_number(params[:per_page], min: 1, max: 100, integer_only: true)
      end
      
      # Validate search query
      if params[:q]
        sanitized[:q] = sanitize_string(params[:q], max_length: 200)
      end
      
      sanitized
    end
    
    # Batch validate multiple inputs
    def validate_batch(validations)
      errors = {}
      results = {}
      
      validations.each do |key, validation|
        begin
          results[key] = case validation[:type]
                        when :string
                          sanitize_string(validation[:value], validation[:options] || {})
                        when :email
                          validate_email(validation[:value])
                        when :url
                          validate_url(validation[:value], validation[:options] || {})
                        when :number
                          validate_number(validation[:value], validation[:options] || {})
                        when :datetime
                          validate_datetime(validation[:value], validation[:options] || {})
                        when :json
                          validate_json(validation[:value], validation[:schema])
                        else
                          validation[:value]
                        end
        rescue ValidationError => e
          errors[key] = e.message
        end
      end
      
      raise ValidationError, errors if errors.any?
      
      results
    end
    
    private
    
    def check_sql_injection(str)
      SQL_INJECTION_PATTERNS.each do |pattern|
        if str.match?(pattern)
          raise ValidationError, "Potential SQL injection detected"
        end
      end
    end
    
    def check_xss(str)
      XSS_PATTERNS.each do |pattern|
        if str.match?(pattern)
          raise ValidationError, "Potential XSS attack detected"
        end
      end
    end
    
    def check_path_traversal(str)
      PATH_TRAVERSAL_PATTERNS.each do |pattern|
        if str.match?(pattern)
          raise ValidationError, "Potential path traversal detected"
        end
      end
    end
    
    def check_file_content(content)
      # Check for script tags in uploaded files
      if content.match?(/<script|<iframe|javascript:/i)
        raise ValidationError, "File contains potentially malicious content"
      end
      
      # Check for SQL patterns in CSV/JSON files
      SQL_INJECTION_PATTERNS.each do |pattern|
        if content.match?(pattern)
          raise ValidationError, "File contains suspicious SQL-like content"
        end
      end
    end
    
    def sanitize_html(html, allowed_tags = [])
      require 'sanitize'
      
      if allowed_tags.empty?
        Sanitize.fragment(html)
      else
        Sanitize.fragment(html, elements: allowed_tags)
      end
    rescue LoadError
      # Fallback to basic HTML stripping if Sanitize gem not available
      html.gsub(/<[^>]*>/, '')
    end
    
    def validate_json_schema(json, schema)
      # Basic schema validation (would use json-schema gem in production)
      schema.each do |key, rules|
        value = json[key.to_s] || json[key.to_sym]
        
        # Check required fields
        if rules[:required] && value.nil?
          raise ValidationError, "Missing required field: #{key}"
        end
        
        # Check type
        if rules[:type] && value
          expected_class = case rules[:type]
                          when :string then String
                          when :number then Numeric
                          when :boolean then [TrueClass, FalseClass]
                          when :array then Array
                          when :object then Hash
                          end
          
          valid_type = expected_class.is_a?(Array) ? 
                      expected_class.any? { |c| value.is_a?(c) } : 
                      value.is_a?(expected_class)
          
          unless valid_type
            raise ValidationError, "Invalid type for field: #{key}"
          end
        end
      end
    end
  end
end
