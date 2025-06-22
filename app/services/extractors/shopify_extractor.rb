# Shopify data extractor for e-commerce analytics
# Extracts orders, customers, products, and inventory data from Shopify stores
class ShopifyExtractor < BaseExtractor
  SHOPIFY_API_VERSION = "2024-01"

  # Record types we extract from Shopify
  RECORD_TYPES = %w[orders customers products inventory_levels].freeze

  # Required configuration fields
  REQUIRED_CONFIG_FIELDS = %w[shop_domain access_token].freeze

  def validate_connection
    unless config_valid?
      raise AuthenticationError, "Missing required Shopify configuration: #{missing_config_fields.join(', ')}"
    end

    with_rate_limiting do
      response = shopify_client.get("/admin/api/shop.json")

      unless response.success?
        handle_api_error(response)
      end

      logger.info "Successfully connected to Shopify store: #{shop_info['name']}"
    end
  end

  def perform_extraction
    logger.info "Starting Shopify data extraction for #{data_source.name}"

    all_data = []

    RECORD_TYPES.each do |record_type|
      logger.info "Extracting #{record_type} from Shopify"

      records = extract_record_type(record_type)
      logger.info "Extracted #{records.count} #{record_type} records"

      all_data.concat(records)
    end

    logger.info "Completed Shopify extraction: #{all_data.count} total records"
    all_data
  end

  def normalize_data(raw_record)
    case raw_record[:record_type]
    when "orders"
      normalize_order(raw_record[:data])
    when "customers"
      normalize_customer(raw_record[:data])
    when "products"
      normalize_product(raw_record[:data])
    when "inventory_levels"
      normalize_inventory(raw_record[:data])
    else
      raw_record[:data]
    end
  end

  def determine_record_type(record)
    record[:record_type] || "unknown"
  end

  def extract_external_id(record)
    case record[:record_type]
    when "orders"
      record.dig(:data, "id") || record.dig(:data, :id)
    when "customers"
      record.dig(:data, "id") || record.dig(:data, :id)
    when "products"
      record.dig(:data, "id") || record.dig(:data, :id)
    when "inventory_levels"
      "#{record.dig(:data, 'inventory_item_id')}_#{record.dig(:data, 'location_id')}"
    else
      super
    end
  end

  # Class configuration
  class << self
    def required_fields
      %w[id created_at updated_at]
    end

    def supports_realtime?
      true # Shopify supports webhooks
    end

    def rate_limit_per_hour
      2000 # Shopify Plus: 2000/hour, Basic: 1000/hour
    end
  end

  private

  def config_valid?
    missing_config_fields.empty?
  end

  def missing_config_fields
    REQUIRED_CONFIG_FIELDS - data_source.configuration.keys
  end

  def extract_record_type(record_type)
    case record_type
    when "orders"
      extract_orders
    when "customers"
      extract_customers
    when "products"
      extract_products
    when "inventory_levels"
      extract_inventory_levels
    else
      []
    end
  end

  def extract_orders
    orders = []
    page_info = nil

    loop do
      response = retry_with_backoff do
        with_rate_limiting do
          url = build_orders_url(page_info)
          shopify_client.get(url)
        end
      end

      handle_api_error(response) unless response.success?

      data = JSON.parse(response.body)
      batch_orders = data["orders"] || []

      # Add record type metadata
      batch_orders.each do |order|
        orders << {
          record_type: "orders",
          data: order,
          extracted_at: Time.current
        }
      end

      # Handle pagination
      page_info = extract_page_info(response.headers)
      break unless page_info&.dig("next")
    end

    orders
  end

  def extract_customers
    customers = []
    page_info = nil

    loop do
      response = retry_with_backoff do
        with_rate_limiting do
          url = build_customers_url(page_info)
          shopify_client.get(url)
        end
      end

      handle_api_error(response) unless response.success?

      data = JSON.parse(response.body)
      batch_customers = data["customers"] || []

      batch_customers.each do |customer|
        customers << {
          record_type: "customers",
          data: customer,
          extracted_at: Time.current
        }
      end

      page_info = extract_page_info(response.headers)
      break unless page_info&.dig("next")
    end

    customers
  end

  def extract_products
    products = []
    page_info = nil

    loop do
      response = retry_with_backoff do
        with_rate_limiting do
          url = build_products_url(page_info)
          shopify_client.get(url)
        end
      end

      handle_api_error(response) unless response.success?

      data = JSON.parse(response.body)
      batch_products = data["products"] || []

      batch_products.each do |product|
        products << {
          record_type: "products",
          data: product,
          extracted_at: Time.current
        }
      end

      page_info = extract_page_info(response.headers)
      break unless page_info&.dig("next")
    end

    products
  end

  def extract_inventory_levels
    inventory_levels = []

    # First get all locations
    locations_response = retry_with_backoff do
      with_rate_limiting do
        shopify_client.get("/admin/api/#{SHOPIFY_API_VERSION}/locations.json")
      end
    end

    handle_api_error(locations_response) unless locations_response.success?

    locations_data = JSON.parse(locations_response.body)
    location_ids = (locations_data["locations"] || []).map { |loc| loc["id"] }

    # Get inventory levels for each location
    location_ids.each do |location_id|
      page_info = nil

      loop do
        response = retry_with_backoff do
          with_rate_limiting do
            url = build_inventory_url(location_id, page_info)
            shopify_client.get(url)
          end
        end

        handle_api_error(response) unless response.success?

        data = JSON.parse(response.body)
        batch_inventory = data["inventory_levels"] || []

        batch_inventory.each do |inventory|
          inventory_levels << {
            record_type: "inventory_levels",
            data: inventory.merge("location_id" => location_id),
            extracted_at: Time.current
          }
        end

        page_info = extract_page_info(response.headers)
        break unless page_info&.dig("next")
      end
    end

    inventory_levels
  end

  # Data normalization methods
  def normalize_order(order_data)
    {
      external_id: order_data["id"],
      order_number: order_data["order_number"] || order_data["name"],
      email: order_data["email"],
      total_price: order_data["total_price"]&.to_f,
      subtotal_price: order_data["subtotal_price"]&.to_f,
      total_tax: order_data["total_tax"]&.to_f,
      total_discounts: order_data["total_discounts"]&.to_f,
      currency: order_data["currency"],
      financial_status: order_data["financial_status"],
      fulfillment_status: order_data["fulfillment_status"],
      customer_id: order_data["customer"]&.dig("id"),
      line_items_count: order_data["line_items"]&.length || 0,
      line_items: normalize_line_items(order_data["line_items"] || []),
      billing_address: normalize_address(order_data["billing_address"]),
      shipping_address: normalize_address(order_data["shipping_address"]),
      created_at: order_data["created_at"],
      updated_at: order_data["updated_at"],
      processed_at: order_data["processed_at"],
      cancelled_at: order_data["cancelled_at"],
      tags: order_data["tags"],
      source_name: order_data["source_name"],
      referring_site: order_data["referring_site"],
      landing_site: order_data["landing_site"]
    }
  end

  def normalize_customer(customer_data)
    {
      external_id: customer_data["id"],
      email: customer_data["email"],
      first_name: customer_data["first_name"],
      last_name: customer_data["last_name"],
      phone: customer_data["phone"],
      accepts_marketing: customer_data["accepts_marketing"],
      marketing_opt_in_level: customer_data["marketing_opt_in_level"],
      orders_count: customer_data["orders_count"] || 0,
      total_spent: customer_data["total_spent"]&.to_f || 0.0,
      currency: customer_data["currency"],
      state: customer_data["state"],
      verified_email: customer_data["verified_email"],
      tax_exempt: customer_data["tax_exempt"],
      tags: customer_data["tags"],
      default_address: normalize_address(customer_data["default_address"]),
      created_at: customer_data["created_at"],
      updated_at: customer_data["updated_at"],
      last_order_id: customer_data["last_order_id"],
      last_order_name: customer_data["last_order_name"]
    }
  end

  def normalize_product(product_data)
    {
      external_id: product_data["id"],
      title: product_data["title"],
      handle: product_data["handle"],
      product_type: product_data["product_type"],
      vendor: product_data["vendor"],
      status: product_data["status"],
      published_scope: product_data["published_scope"],
      tags: product_data["tags"],
      variants_count: product_data["variants"]&.length || 0,
      variants: normalize_variants(product_data["variants"] || []),
      options: product_data["options"] || [],
      images: normalize_images(product_data["images"] || []),
      created_at: product_data["created_at"],
      updated_at: product_data["updated_at"],
      published_at: product_data["published_at"]
    }
  end

  def normalize_inventory(inventory_data)
    {
      inventory_item_id: inventory_data["inventory_item_id"],
      location_id: inventory_data["location_id"],
      available: inventory_data["available"],
      updated_at: inventory_data["updated_at"]
    }
  end

  def normalize_line_items(line_items)
    line_items.map do |item|
      {
        id: item["id"],
        product_id: item["product_id"],
        variant_id: item["variant_id"],
        title: item["title"],
        quantity: item["quantity"],
        price: item["price"]&.to_f,
        total_discount: item["total_discount"]&.to_f,
        sku: item["sku"],
        vendor: item["vendor"],
        fulfillment_status: item["fulfillment_status"]
      }
    end
  end

  def normalize_variants(variants)
    variants.map do |variant|
      {
        id: variant["id"],
        title: variant["title"],
        option1: variant["option1"],
        option2: variant["option2"],
        option3: variant["option3"],
        sku: variant["sku"],
        price: variant["price"]&.to_f,
        compare_at_price: variant["compare_at_price"]&.to_f,
        inventory_quantity: variant["inventory_quantity"],
        inventory_management: variant["inventory_management"],
        inventory_policy: variant["inventory_policy"],
        fulfillment_service: variant["fulfillment_service"],
        created_at: variant["created_at"],
        updated_at: variant["updated_at"]
      }
    end
  end

  def normalize_images(images)
    images.map do |image|
      {
        id: image["id"],
        src: image["src"],
        alt: image["alt"],
        position: image["position"],
        created_at: image["created_at"],
        updated_at: image["updated_at"]
      }
    end
  end

  def normalize_address(address)
    return nil unless address

    {
      first_name: address["first_name"],
      last_name: address["last_name"],
      company: address["company"],
      address1: address["address1"],
      address2: address["address2"],
      city: address["city"],
      province: address["province"],
      country: address["country"],
      zip: address["zip"],
      phone: address["phone"],
      province_code: address["province_code"],
      country_code: address["country_code"]
    }
  end

  # URL builders
  def build_orders_url(page_info = nil)
    base_url = "/admin/api/#{SHOPIFY_API_VERSION}/orders.json"
    params = {
      status: "any",
      limit: 250,
      fields: order_fields.join(",")
    }

    # Add incremental sync support
    if data_source.last_sync_at && supports_incremental_sync?
      params[:updated_at_min] = data_source.last_sync_at.iso8601
    end

    if page_info&.dig("next")
      params[:page_info] = page_info["next"]
    end

    "#{base_url}?#{params.to_query}"
  end

  def build_customers_url(page_info = nil)
    base_url = "/admin/api/#{SHOPIFY_API_VERSION}/customers.json"
    params = {
      limit: 250,
      fields: customer_fields.join(",")
    }

    if data_source.last_sync_at && supports_incremental_sync?
      params[:updated_at_min] = data_source.last_sync_at.iso8601
    end

    if page_info&.dig("next")
      params[:page_info] = page_info["next"]
    end

    "#{base_url}?#{params.to_query}"
  end

  def build_products_url(page_info = nil)
    base_url = "/admin/api/#{SHOPIFY_API_VERSION}/products.json"
    params = {
      limit: 250,
      fields: product_fields.join(",")
    }

    if data_source.last_sync_at && supports_incremental_sync?
      params[:updated_at_min] = data_source.last_sync_at.iso8601
    end

    if page_info&.dig("next")
      params[:page_info] = page_info["next"]
    end

    "#{base_url}?#{params.to_query}"
  end

  def build_inventory_url(location_id, page_info = nil)
    base_url = "/admin/api/#{SHOPIFY_API_VERSION}/inventory_levels.json"
    params = {
      location_ids: location_id,
      limit: 250
    }

    if page_info&.dig("next")
      params[:page_info] = page_info["next"]
    end

    "#{base_url}?#{params.to_query}"
  end

  # Field specifications for API calls
  def order_fields
    %w[
      id order_number name email financial_status fulfillment_status
      total_price subtotal_price total_tax total_discounts currency
      customer created_at updated_at processed_at cancelled_at
      line_items billing_address shipping_address tags source_name
      referring_site landing_site
    ]
  end

  def customer_fields
    %w[
      id email first_name last_name phone accepts_marketing
      marketing_opt_in_level orders_count total_spent currency state
      verified_email tax_exempt tags default_address created_at updated_at
      last_order_id last_order_name
    ]
  end

  def product_fields
    %w[
      id title handle product_type vendor status published_scope
      tags variants options images created_at updated_at published_at
    ]
  end

  # HTTP client and error handling
  def shopify_client
    @shopify_client ||= begin
      require "faraday"
      require "faraday/retry"

      Faraday.new(
        url: "https://#{shop_domain}",
        headers: {
          "X-Shopify-Access-Token" => access_token,
          "Content-Type" => "application/json",
          "User-Agent" => "DataRefinery/1.0"
        }
      ) do |faraday|
        faraday.request :retry, max: 2, interval: 0.5
        faraday.response :raise_error
      end
    end
  end

  def shop_domain
    data_source.configuration["shop_domain"]
  end

  def access_token
    data_source.configuration["access_token"]
  end

  def shop_info
    @shop_info ||= begin
      response = shopify_client.get("/admin/api/#{SHOPIFY_API_VERSION}/shop.json")
      JSON.parse(response.body)["shop"]
    end
  end

  def extract_page_info(headers)
    link_header = headers["Link"]
    return nil unless link_header

    links = {}
    link_header.split(",").each do |link|
      if link =~ /<([^>]+)>; rel="([^"]+)"/
        url = $1
        rel = $2
        page_info = URI.decode_www_form(URI.parse(url).query).to_h["page_info"]
        links[rel] = page_info if page_info
      end
    end

    links
  end

  def handle_api_error(response)
    case response.status
    when 401
      raise AuthenticationError, "Invalid Shopify credentials"
    when 402
      raise AuthenticationError, "Shopify store has been suspended"
    when 403
      raise AuthenticationError, "Access denied - check API permissions"
    when 429
      raise RateLimitError, "Shopify API rate limit exceeded"
    when 404
      raise ConnectionError, "Shopify store not found"
    when 500..599
      raise ConnectionError, "Shopify server error: #{response.status}"
    else
      raise ExtractionError, "Shopify API error: #{response.status} - #{response.body}"
    end
  end

  def supports_incremental_sync?
    self.class.supports_incremental_sync?
  end
end
