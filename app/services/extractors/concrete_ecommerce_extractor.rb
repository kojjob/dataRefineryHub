# Concrete implementation of EcommerceExtractor that uses platform adapters
# This replaces platform-specific extractors like ShopifyExtractor

# Load schemas and adapters
require_relative "ecommerce/schemas/standard_order"
require_relative "ecommerce/schemas/standard_customer"
require_relative "ecommerce/schemas/standard_product"
require_relative "ecommerce/schemas/standard_inventory"
require_relative "ecommerce/ecommerce_adapter"
require_relative "ecommerce/adapters/shopify_adapter"
require_relative "ecommerce/adapters/woocommerce_adapter"

class ConcreteEcommerceExtractor < EcommerceExtractor
  # Override abstract method to create appropriate adapter
  def create_adapter
    adapter_class = EcommerceAdapter.get_adapter_class(data_source.source_type)

    unless adapter_class
      raise AdapterNotFoundError, "No adapter found for platform: #{data_source.source_type}"
    end

    adapter_class.new(data_source)
  end

  # Platform-specific configuration
  def self.supports_realtime?
    false # Override based on adapter capabilities
  end

  def self.supports_incremental_sync?
    true
  end

  def self.required_fields
    %w[external_id platform_name created_at]
  end

  def self.rate_limit_per_hour
    1000 # Default, actual rate limit comes from adapter
  end
end
