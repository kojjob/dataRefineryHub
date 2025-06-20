# Factory for creating and managing data source extractors
# Provides unified interface for extractor instantiation and discovery
class ExtractorFactory
  class UnsupportedSourceTypeError < StandardError; end

  # Registry of available extractors
  EXTRACTORS = {
    # E-commerce platforms - use generic EcommerceExtractor with adapters
    'shopify' => 'ConcreteEcommerceExtractor',
    'woocommerce' => 'ConcreteEcommerceExtractor',
    'amazon_seller_central' => 'ConcreteEcommerceExtractor',
    
    # Other platform-specific extractors
    'quickbooks' => 'QuickbooksExtractor',
    'google_analytics' => 'GoogleAnalyticsExtractor',
    'stripe' => 'StripeExtractor',
    'mailchimp' => 'MailchimpExtractor',
    'zendesk' => 'ZendeskExtractor',
    'hubspot' => 'HubspotExtractor',
    'google_ads' => 'GoogleAdsExtractor',
    'facebook_ads' => 'FacebookAdsExtractor',
    'salesforce' => 'SalesforceExtractor',
    'custom_api' => 'CustomApiExtractor'
  }.freeze

  class << self
    # Create extractor instance for given data source
    def create_extractor(data_source)
      unless supported_source_type?(data_source.source_type)
        raise UnsupportedSourceTypeError, "Unsupported source type: #{data_source.source_type}"
      end

      extractor_class = get_extractor_class(data_source.source_type)
      extractor_class.new(data_source)
    end

    # Get all supported source types
    def supported_source_types
      EXTRACTORS.keys
    end

    # Check if source type is supported
    def supported_source_type?(source_type)
      EXTRACTORS.key?(source_type.to_s)
    end

    # Get extractor class for source type
    def get_extractor_class(source_type)
      class_name = EXTRACTORS[source_type.to_s]
      return nil unless class_name

      begin
        class_name.constantize
      rescue NameError
        # Return a placeholder class if extractor not implemented yet
        create_placeholder_extractor(source_type, class_name)
      end
    end

    # Get extractors grouped by implementation status
    def extractors_by_status
      {
        implemented: implemented_extractors,
        planned: planned_extractors
      }
    end

    # Get metadata for all extractors
    def extractor_metadata
      result = {}
      
      EXTRACTORS.each do |source_type, class_name|
        begin
          extractor_class = class_name.constantize
          result[source_type] = {
            name: class_name,
            implemented: true,
            supports_realtime: extractor_class.supports_realtime?,
            supports_incremental_sync: extractor_class.supports_incremental_sync?,
            required_fields: extractor_class.required_fields,
            rate_limit_per_hour: extractor_class.rate_limit_per_hour
          }
        rescue NameError
          result[source_type] = {
            name: class_name,
            implemented: false,
            supports_realtime: false,
            supports_incremental_sync: false,
            required_fields: [],
            rate_limit_per_hour: 0
          }
        end
      end
      
      result
    end

    # Get priority integrations (MVP launch)
    def priority_integrations
      %w[shopify quickbooks google_analytics stripe mailchimp]
    end

    # Get growth integrations (Phase 2)
    def growth_integrations
      %w[zendesk hubspot google_ads facebook_ads woocommerce amazon_seller_central]
    end

    # Get enterprise integrations (Phase 3)
    def enterprise_integrations
      %w[salesforce custom_api]
    end

    # Test connection for data source
    def test_connection(data_source)
      extractor = create_extractor(data_source)
      extractor.test_connection
    rescue UnsupportedSourceTypeError => e
      { status: :error, message: e.message, error_type: 'UnsupportedSourceType' }
    rescue => e
      { status: :error, message: e.message, error_type: e.class.name }
    end

    # Run extraction for data source
    def extract_data(data_source, job_id: nil)
      extractor = create_extractor(data_source)
      extractor.extract_data(job_id: job_id)
    rescue UnsupportedSourceTypeError => e
      Rails.logger.error "Extraction failed: #{e.message}"
      raise e
    end

    # Get extraction statistics for data source
    def extraction_stats(data_source)
      extractor = create_extractor(data_source)
      extractor.extraction_stats
    rescue UnsupportedSourceTypeError => e
      {
        total_jobs: 0,
        successful_jobs: 0,
        failed_jobs: 0,
        last_sync_at: nil,
        next_sync_at: nil,
        error: e.message
      }
    end

    private

    def implemented_extractors
      EXTRACTORS.select do |source_type, class_name|
        begin
          class_name.constantize
          true
        rescue NameError
          false
        end
      end.keys
    end

    def planned_extractors
      EXTRACTORS.reject do |source_type, class_name|
        begin
          class_name.constantize
          true
        rescue NameError
          false
        end
      end.keys
    end

    def create_placeholder_extractor(source_type, class_name)
      # Create a placeholder class that inherits from BaseExtractor
      Class.new(BaseExtractor) do
        define_method :validate_connection do
          raise NotImplementedError, "#{class_name} extractor not yet implemented"
        end

        define_method :perform_extraction do
          raise NotImplementedError, "#{class_name} extractor not yet implemented"
        end

        define_singleton_method :supported_source_type do
          source_type
        end

        define_singleton_method :name do
          class_name
        end
      end
    end
  end
end