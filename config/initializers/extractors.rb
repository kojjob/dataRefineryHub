# Register all available data extractors
# This mapping is used by the ExtractorFactory to instantiate the correct extractor

Rails.application.config.after_initialize do
  # Define the mapping of source types to extractor classes
  Rails.application.config.extractors = {
    # E-commerce platforms
    "shopify" => "ShopifyExtractor",
    "woocommerce" => "WooCommerceExtractor",
    "magento" => "MagentoExtractor",

    # Databases
    "postgresql" => "PostgresqlExtractor",
    "mysql" => "DatabaseExtractor",
    "sqlserver" => "DatabaseExtractor",
    "mongodb" => "MongoDbExtractor",

    # File formats
    "csv" => "CsvExtractor",
    "excel" => "ExcelExtractor",
    "json" => "JsonExtractor",
    "xml" => "XmlExtractor",

    # Cloud storage
    "aws_s3" => "CloudStorageExtractor",
    "google_cloud_storage" => "CloudStorageExtractor",
    "azure_blob" => "CloudStorageExtractor",

    # APIs
    "api" => "ApiExtractor",
    "rest_api" => "ApiExtractor",
    "graphql" => "GraphqlExtractor",
    "webhook" => "WebhookExtractor",

    # Google services
    "google_sheets" => "GoogleSheetsExtractor",
    "google_analytics" => "GoogleAnalyticsExtractor",

    # CRM/Marketing platforms
    "salesforce" => "SalesforceExtractor",
    "hubspot" => "HubspotExtractor",
    "mailchimp" => "MailchimpExtractor",

    # Payment platforms
    "stripe" => "StripeExtractor",
    "paypal" => "PaypalExtractor",
    "square" => "SquareExtractor",

    # Social media
    "facebook_ads" => "FacebookAdsExtractor",
    "google_ads" => "GoogleAdsExtractor",
    "instagram" => "InstagramExtractor",

    # Customer support
    "zendesk" => "ZendeskExtractor",
    "intercom" => "IntercomExtractor",
    "freshdesk" => "FreshdeskExtractor"
  }.freeze

  # Helper method to get extractor class
  class << Rails.application
    def get_extractor_class(source_type)
      extractor_name = config.extractors[source_type]
      return nil unless extractor_name

      begin
        extractor_name.constantize
      rescue NameError => e
        Rails.logger.error "Extractor class not found: #{extractor_name} for source type: #{source_type}"
        nil
      end
    end

    # Get list of supported source types
    def supported_source_types
      config.extractors.keys.sort
    end

    # Get extractors by category
    def extractors_by_category
      {
        "E-commerce" => %w[shopify woocommerce magento],
        "Databases" => %w[postgresql mysql sqlserver mongodb],
        "Files" => %w[csv excel json xml],
        "Cloud Storage" => %w[aws_s3 google_cloud_storage azure_blob],
        "APIs" => %w[api rest_api graphql webhook],
        "Analytics" => %w[google_analytics google_sheets],
        "CRM & Marketing" => %w[salesforce hubspot mailchimp],
        "Payments" => %w[stripe paypal square],
        "Advertising" => %w[facebook_ads google_ads],
        "Customer Support" => %w[zendesk intercom freshdesk]
      }
    end

    # Check if a source type is supported
    def source_type_supported?(source_type)
      config.extractors.key?(source_type)
    end
  end
end
