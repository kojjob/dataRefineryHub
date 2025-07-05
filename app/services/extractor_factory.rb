# Factory class for creating appropriate extractor instances based on data source type
class ExtractorFactory
  class UnsupportedSourceTypeError < StandardError; end

  class << self
    # Create an extractor instance for the given data source
    def create_extractor(data_source)
      raise ArgumentError, "Data source is required" unless data_source

      source_type = data_source.source_type
      raise UnsupportedSourceTypeError, "Source type is required" if source_type.blank?

      extractor_class = Rails.application.get_extractor_class(source_type)

      unless extractor_class
        raise UnsupportedSourceTypeError, "Unsupported source type: #{source_type}"
      end

      # Instantiate the extractor with the data source
      extractor_class.new(data_source)
    rescue => e
      Rails.logger.error "Failed to create extractor for source type #{source_type}: #{e.message}"
      raise
    end

    # Get extractor class without instantiating
    def get_extractor_class(source_type)
      Rails.application.get_extractor_class(source_type)
    end

    # Check if a source type is supported
    def supported?(source_type)
      Rails.application.source_type_supported?(source_type)
    end

    # Get all supported source types
    def supported_source_types
      Rails.application.supported_source_types
    end

    # Get extractors grouped by category
    def extractors_by_category
      Rails.application.extractors_by_category
    end

    # Get extractor capabilities for a source type
    def get_capabilities(source_type)
      extractor_class = get_extractor_class(source_type)
      return nil unless extractor_class

      {
        supports_realtime: extractor_class.supports_realtime?,
        supports_incremental_sync: extractor_class.supports_incremental_sync?,
        rate_limit_per_hour: extractor_class.rate_limit_per_hour,
        required_fields: extractor_class.required_fields,
        optional_fields: extractor_class.optional_fields
      }
    rescue => e
      Rails.logger.error "Failed to get capabilities for #{source_type}: #{e.message}"
      nil
    end

    # Validate data source configuration for a given source type
    def validate_configuration(source_type, configuration)
      extractor_class = get_extractor_class(source_type)
      return { valid: false, errors: [ "Unknown source type: #{source_type}" ] } unless extractor_class

      errors = []

      # Check required fields
      required_fields = extractor_class.required_fields
      required_fields.each do |field|
        if configuration[field].blank?
          errors << "Missing required field: #{field}"
        end
      end

      # Validate field types if extractor provides validation
      if extractor_class.respond_to?(:validate_field_types)
        field_errors = extractor_class.validate_field_types(configuration)
        errors.concat(field_errors) if field_errors.any?
      end

      {
        valid: errors.empty?,
        errors: errors,
        warnings: get_configuration_warnings(source_type, configuration)
      }
    end

    private

    def get_configuration_warnings(source_type, configuration)
      warnings = []

      # Source-specific warnings
      case source_type
      when "shopify"
        if configuration["api_version"] && configuration["api_version"] < "2023-01"
          warnings << "Using outdated API version. Consider upgrading to the latest version."
        end
      when "postgresql", "mysql"
        if configuration["ssl_mode"].blank? || configuration["ssl_mode"] == "disable"
          warnings << "SSL is not enabled. Consider enabling SSL for secure connections."
        end
      when "csv"
        if configuration["encoding"].blank?
          warnings << "No encoding specified. UTF-8 will be assumed."
        end
      end

      warnings
    end
  end
end
