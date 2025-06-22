# Shopify platform adapter for e-commerce data extraction
# Handles Shopify-specific API calls, authentication, and data formatting
class ShopifyAdapter < EcommerceAdapter
  SHOPIFY_API_VERSION = "2024-01"
  SHOPIFY_RATE_LIMIT_PER_HOUR = 2000 # Shopify Plus: 2000/hour, Basic: 1000/hour

  # Register this adapter
  EcommerceAdapter.register_adapter("shopify", self)

  def platform_name
    "shopify"
  end

  def api_version
    SHOPIFY_API_VERSION
  end

  def required_config_fields
    %w[shop_domain access_token]
  end

  def supports_realtime?
    true # Shopify supports webhooks
  end

  def supports_webhooks?
    true
  end

  def rate_limit_per_hour
    SHOPIFY_RATE_LIMIT_PER_HOUR
  end

  def max_records_per_request
    250 # Shopify's maximum
  end

  # Authentication and connection
  def validate_connection
    unless config_valid?
      raise AuthenticationError, "Missing required Shopify configuration: #{missing_config_fields.join(', ')}"
    end

    with_rate_limiting do
      response = http_client.get("/admin/api/shop.json")

      unless response.success?
        handle_api_error(response)
      end

      shop_info = JSON.parse(response.body)["shop"]
      logger.info "Successfully connected to Shopify store: #{shop_info['name']}"
    end
  end

  # Data extraction methods
  def fetch_orders(options = {})
    logger.info "Fetching orders from Shopify"

    all_orders = paginate_requests(build_orders_url(options)) do |url|
      with_rate_limiting do
        response = http_client.get(url)
        handle_api_error(response) unless response.success?
        response
      end
    end

    logger.info "Fetched #{all_orders.count} orders from Shopify"
    all_orders
  end

  def fetch_customers(options = {})
    logger.info "Fetching customers from Shopify"

    all_customers = paginate_requests(build_customers_url(options)) do |url|
      with_rate_limiting do
        response = http_client.get(url)
        handle_api_error(response) unless response.success?
        response
      end
    end

    logger.info "Fetched #{all_customers.count} customers from Shopify"
    all_customers
  end

  def fetch_products(options = {})
    logger.info "Fetching products from Shopify"

    all_products = paginate_requests(build_products_url(options)) do |url|
      with_rate_limiting do
        response = http_client.get(url)
        handle_api_error(response) unless response.success?
        response
      end
    end

    logger.info "Fetched #{all_products.count} products from Shopify"
    all_products
  end

  def fetch_inventory(options = {})
    logger.info "Fetching inventory from Shopify"

    # First get all locations
    locations = fetch_locations
    all_inventory = []

    locations.each do |location|
      location_inventory = paginate_requests(build_inventory_url(location["id"], options)) do |url|
        with_rate_limiting do
          response = http_client.get(url)
          handle_api_error(response) unless response.success?
          response
        end
      end

      # Add location context to each inventory item
      location_inventory.each do |inventory_item|
        inventory_item["location_data"] = location
      end

      all_inventory.concat(location_inventory)
    end

    logger.info "Fetched #{all_inventory.count} inventory levels from Shopify"
    all_inventory
  end

  # Response parsing
  def parse_response_data(response)
    data = JSON.parse(response.body)

    # Determine the data key based on the endpoint
    records = case
    when data.key?("orders")
      data["orders"]
    when data.key?("customers")
      data["customers"]
    when data.key?("products")
      data["products"]
    when data.key?("inventory_levels")
      data["inventory_levels"]
    when data.key?("locations")
      data["locations"]
    else
      []
    end

    # Extract pagination info from Link header
    next_page_url = extract_next_page_url(response.headers)

    {
      records: records,
      next_page_url: next_page_url
    }
  end

  # HTTP client configuration
  def build_base_url
    "https://#{shop_domain}"
  end

  def build_headers
    super.merge({
      "X-Shopify-Access-Token" => access_token
    })
  end

  # Webhook management
  def create_webhook(endpoint_url, events = [ "orders/create", "orders/updated", "customers/create" ])
    webhook_data = {
      webhook: {
        topic: events.first, # Shopify creates one webhook per topic
        address: endpoint_url,
        format: "json"
      }
    }

    response = http_client.post("/admin/api/webhooks.json", webhook_data.to_json)
    handle_api_error(response) unless response.success?

    JSON.parse(response.body)["webhook"]
  end

  def delete_webhook(webhook_id)
    response = http_client.delete("/admin/api/webhooks/#{webhook_id}.json")
    handle_api_error(response) unless response.success?
    true
  end

  def list_webhooks
    response = http_client.get("/admin/api/webhooks.json")
    handle_api_error(response) unless response.success?

    JSON.parse(response.body)["webhooks"]
  end

  private

  def shop_domain
    configuration["shop_domain"]
  end

  def access_token
    configuration["access_token"]
  end

  def fetch_locations
    response = retry_with_backoff do
      with_rate_limiting do
        http_client.get("/admin/api/#{SHOPIFY_API_VERSION}/locations.json")
      end
    end

    handle_api_error(response) unless response.success?
    JSON.parse(response.body)["locations"] || []
  end

  # URL builders
  def build_orders_url(options = {})
    params = build_sync_params(options).merge({
      status: "any",
      fields: order_fields.join(",")
    })

    build_endpoint_url("admin/api/#{SHOPIFY_API_VERSION}/orders.json", params)
  end

  def build_customers_url(options = {})
    params = build_sync_params(options).merge({
      fields: customer_fields.join(",")
    })

    build_endpoint_url("admin/api/#{SHOPIFY_API_VERSION}/customers.json", params)
  end

  def build_products_url(options = {})
    params = build_sync_params(options).merge({
      fields: product_fields.join(",")
    })

    build_endpoint_url("admin/api/#{SHOPIFY_API_VERSION}/products.json", params)
  end

  def build_inventory_url(location_id, options = {})
    params = {
      location_ids: location_id,
      limit: max_records_per_request
    }

    build_endpoint_url("admin/api/#{SHOPIFY_API_VERSION}/inventory_levels.json", params)
  end

  # Field specifications for optimized API calls
  def order_fields
    %w[
      id order_number name email financial_status fulfillment_status
      total_price subtotal_price total_tax total_discounts currency
      customer created_at updated_at processed_at cancelled_at
      line_items billing_address shipping_address tags source_name
      referring_site landing_site gateway checkout_id location_id
    ]
  end

  def customer_fields
    %w[
      id email first_name last_name phone accepts_marketing
      marketing_opt_in_level orders_count total_spent currency state
      verified_email tax_exempt tags default_address addresses
      created_at updated_at last_order_id last_order_name note
    ]
  end

  def product_fields
    %w[
      id title body_html handle product_type vendor status published_scope
      tags variants options images created_at updated_at published_at
      template_suffix
    ]
  end

  # Pagination helpers
  def extract_next_page_url(headers)
    link_header = headers["Link"]
    return nil unless link_header

    # Parse Link header for next page
    links = {}
    link_header.split(",").each do |link|
      if link =~ /<([^>]+)>; rel="([^"]+)"/
        url = $1
        rel = $2
        links[rel] = url
      end
    end

    links["next"]
  end

  # Rate limit tracking
  def rate_limit_remaining
    # Shopify provides rate limit info in response headers
    # This would be populated after an API call
    @last_rate_limit_remaining
  end

  def track_rate_limit(response)
    # Shopify uses X-Shopify-Shop-Api-Call-Limit header
    call_limit_header = response.headers["X-Shopify-Shop-Api-Call-Limit"]

    if call_limit_header
      current, max = call_limit_header.split("/")
      @last_rate_limit_remaining = max.to_i - current.to_i
    end
  end

  # Enhanced error handling for Shopify-specific errors
  def handle_api_error(response)
    # Track rate limits before handling error
    track_rate_limit(response)

    case response.status
    when 401
      raise AuthenticationError, "Invalid Shopify credentials"
    when 402
      raise AuthenticationError, "Shopify store has been suspended"
    when 403
      raise AuthenticationError, "Access denied - check API permissions"
    when 404
      raise ConnectionError, "Shopify store not found"
    when 422
      error_details = JSON.parse(response.body) rescue {}
      raise AdapterError, "Shopify validation error: #{error_details}"
    when 429
      # Enhanced rate limit error with retry info
      retry_after = response.headers["Retry-After"]
      message = "Shopify API rate limit exceeded"
      message += " - retry after #{retry_after} seconds" if retry_after
      raise RateLimitError, message
    when 500..599
      raise ConnectionError, "Shopify server error: #{response.status}"
    else
      super
    end
  end

  # Shopify-specific data transformations
  def extract_shop_info
    @shop_info ||= begin
      response = http_client.get("/admin/api/#{SHOPIFY_API_VERSION}/shop.json")
      handle_api_error(response) unless response.success?
      JSON.parse(response.body)["shop"]
    end
  end

  def shop_currency
    extract_shop_info["currency"]
  end

  def shop_timezone
    extract_shop_info["iana_timezone"]
  end

  def shop_country
    extract_shop_info["country_code"]
  end
end
