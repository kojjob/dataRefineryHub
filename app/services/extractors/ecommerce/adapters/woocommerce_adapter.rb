# WooCommerce platform adapter for e-commerce data extraction
# Handles WooCommerce REST API calls, authentication, and data formatting
class WoocommerceAdapter < EcommerceAdapter
  WOOCOMMERCE_API_VERSION = "wc/v3"
  WOOCOMMERCE_RATE_LIMIT_PER_HOUR = 3600 # 1 request per second by default

  # Register this adapter
  EcommerceAdapter.register_adapter("woocommerce", self)

  def platform_name
    "woocommerce"
  end

  def api_version
    WOOCOMMERCE_API_VERSION
  end

  def required_config_fields
    %w[store_url consumer_key consumer_secret]
  end

  def supports_realtime?
    true # WooCommerce supports webhooks
  end

  def supports_webhooks?
    true
  end

  def rate_limit_per_hour
    WOOCOMMERCE_RATE_LIMIT_PER_HOUR
  end

  def max_records_per_request
    100 # WooCommerce default maximum
  end

  # Authentication and connection
  def validate_connection
    unless config_valid?
      raise AuthenticationError, "Missing required WooCommerce configuration: #{missing_config_fields.join(', ')}"
    end

    with_rate_limiting do
      response = http_client.get("/wp-json/wc/v3/system_status")

      unless response.success?
        handle_api_error(response)
      end

      system_info = JSON.parse(response.body)
      logger.info "Successfully connected to WooCommerce store: #{system_info['environment']['site_url']}"
    end
  end

  # Data extraction methods
  def fetch_orders(options = {})
    logger.info "Fetching orders from WooCommerce"

    all_orders = paginate_requests(build_orders_url(options)) do |url|
      with_rate_limiting do
        response = http_client.get(url)
        handle_api_error(response) unless response.success?
        response
      end
    end

    logger.info "Fetched #{all_orders.count} orders from WooCommerce"
    all_orders
  end

  def fetch_customers(options = {})
    logger.info "Fetching customers from WooCommerce"

    all_customers = paginate_requests(build_customers_url(options)) do |url|
      with_rate_limiting do
        response = http_client.get(url)
        handle_api_error(response) unless response.success?
        response
      end
    end

    logger.info "Fetched #{all_customers.count} customers from WooCommerce"
    all_customers
  end

  def fetch_products(options = {})
    logger.info "Fetching products from WooCommerce"

    all_products = paginate_requests(build_products_url(options)) do |url|
      with_rate_limiting do
        response = http_client.get(url)
        handle_api_error(response) unless response.success?
        response
      end
    end

    logger.info "Fetched #{all_products.count} products from WooCommerce"
    all_products
  end

  def fetch_inventory(options = {})
    logger.info "Fetching inventory from WooCommerce"

    # WooCommerce doesn't have separate inventory endpoint
    # Inventory data comes from products, so we fetch products with stock info
    all_products = fetch_products(options.merge(stock_status: "any"))

    # Filter to only products that have inventory tracking
    inventory_items = all_products.select do |product|
      product["manage_stock"] == true
    end

    logger.info "Fetched #{inventory_items.count} inventory levels from WooCommerce"
    inventory_items
  end

  # Response parsing
  def parse_response_data(response)
    data = JSON.parse(response.body)

    # WooCommerce returns arrays directly for most endpoints
    records = data.is_a?(Array) ? data : [ data ]

    # Extract pagination info from headers
    next_page_url = extract_next_page_url(response.headers, response.env&.url)

    {
      records: records,
      next_page_url: next_page_url
    }
  end

  # HTTP client configuration
  def build_base_url
    store_url.chomp("/")
  end

  def build_headers
    super.merge({
      "Authorization" => build_auth_header
    })
  end

  # Webhook management
  def create_webhook(endpoint_url, events = [ "order.created", "order.updated", "customer.created" ])
    webhook_data = {
      name: "Data Refinery Platform",
      status: "active",
      topic: events.first, # WooCommerce creates one webhook per topic
      delivery_url: endpoint_url,
      secret: generate_webhook_secret
    }

    response = http_client.post("/wp-json/wc/v3/webhooks", webhook_data.to_json)
    handle_api_error(response) unless response.success?

    JSON.parse(response.body)
  end

  def delete_webhook(webhook_id)
    response = http_client.delete("/wp-json/wc/v3/webhooks/#{webhook_id}")
    handle_api_error(response) unless response.success?
    true
  end

  def list_webhooks
    response = http_client.get("/wp-json/wc/v3/webhooks")
    handle_api_error(response) unless response.success?

    JSON.parse(response.body)
  end

  private

  def store_url
    configuration["store_url"]
  end

  def consumer_key
    configuration["consumer_key"]
  end

  def consumer_secret
    configuration["consumer_secret"]
  end

  def build_auth_header
    # WooCommerce uses HTTP Basic Auth with consumer key/secret
    credentials = Base64.strict_encode64("#{consumer_key}:#{consumer_secret}")
    "Basic #{credentials}"
  end

  # URL builders
  def build_orders_url(options = {})
    params = build_sync_params(options).merge({
      status: "any",
      orderby: "date",
      order: "desc"
    })

    build_endpoint_url("wp-json/wc/v3/orders", params)
  end

  def build_customers_url(options = {})
    params = build_sync_params(options).merge({
      orderby: "registered_date",
      order: "desc"
    })

    build_endpoint_url("wp-json/wc/v3/customers", params)
  end

  def build_products_url(options = {})
    params = build_sync_params(options).merge({
      status: "any",
      orderby: "date",
      order: "desc"
    })

    # Add stock status filter if specified
    if options[:stock_status]
      params[:stock_status] = options[:stock_status]
    end

    build_endpoint_url("wp-json/wc/v3/products", params)
  end

  # Pagination helpers - WooCommerce uses different pagination than Shopify
  def extract_next_page_url(headers, current_url)
    total_pages = headers["X-WP-TotalPages"]&.to_i
    current_page = extract_current_page(current_url)

    return nil unless total_pages && current_page && current_page < total_pages

    # Build next page URL
    uri = URI.parse(current_url)
    params = Rack::Utils.parse_query(uri.query)
    params["page"] = (current_page + 1).to_s

    uri.query = params.to_query
    uri.to_s
  end

  def extract_current_page(url)
    return 1 unless url

    uri = URI.parse(url)
    params = Rack::Utils.parse_query(uri.query)
    (params["page"] || "1").to_i
  end

  # Override sync params for WooCommerce format
  def build_sync_params(options = {})
    params = {
      per_page: max_records_per_request,
      page: 1
    }

    # Add modified_after parameter for incremental sync
    if options[:since] && supports_incremental_sync?
      params[:modified_after] = options[:since].iso8601
    end

    params
  end

  # Enhanced error handling for WooCommerce-specific errors
  def handle_api_error(response)
    case response.status
    when 401
      raise AuthenticationError, "Invalid WooCommerce credentials"
    when 403
      raise AuthenticationError, "Access denied - check WooCommerce API permissions"
    when 404
      raise ConnectionError, "WooCommerce endpoint not found - check store URL and API version"
    when 422
      error_details = JSON.parse(response.body)["data"] rescue {}
      raise AdapterError, "WooCommerce validation error: #{error_details}"
    when 429
      retry_after = response.headers["Retry-After"]
      message = "WooCommerce API rate limit exceeded"
      message += " - retry after #{retry_after} seconds" if retry_after
      raise RateLimitError, message
    when 500..599
      raise ConnectionError, "WooCommerce server error: #{response.status}"
    else
      super
    end
  end

  # WooCommerce-specific data transformations
  def extract_store_info
    @store_info ||= begin
      response = http_client.get("/wp-json/wc/v3/system_status")
      handle_api_error(response) unless response.success?
      JSON.parse(response.body)
    end
  end

  def store_currency
    extract_store_info.dig("settings", "currency", "value") || "USD"
  end

  def store_timezone
    extract_store_info.dig("settings", "timezone", "value") || "UTC"
  end

  def store_country
    extract_store_info.dig("settings", "wc_address_country", "value")
  end

  def wordpress_version
    extract_store_info.dig("environment", "wp_version")
  end

  def woocommerce_version
    extract_store_info.dig("environment", "wc_version")
  end

  # Webhook helpers
  def generate_webhook_secret
    SecureRandom.hex(32)
  end

  def verify_webhook_signature(payload, signature, secret)
    expected_signature = Base64.strict_encode64(
      OpenSSL::HMAC.digest(OpenSSL::Digest.new("sha256"), secret, payload)
    )

    ActiveSupport::SecurityUtils.secure_compare(signature, expected_signature)
  end

  # Rate limit tracking for WooCommerce
  def rate_limit_remaining
    # WooCommerce doesn't provide rate limit headers by default
    # This would need to be implemented based on store configuration
    @last_rate_limit_remaining
  end

  def track_rate_limit(response)
    # Custom rate limit tracking if store provides headers
    # Most WooCommerce stores don't provide this information
    @last_rate_limit_remaining = nil
  end

  # WooCommerce-specific field mapping
  def normalize_order_status(wc_status)
    case wc_status
    when "pending" then "pending"
    when "processing" then "processing"
    when "on-hold" then "on_hold"
    when "completed" then "fulfilled"
    when "cancelled" then "cancelled"
    when "refunded" then "refunded"
    when "failed" then "failed"
    else wc_status
    end
  end

  def normalize_customer_role(wc_role)
    case wc_role
    when "customer" then "customer"
    when "subscriber" then "subscriber"
    when "shop_manager" then "admin"
    else "customer"
    end
  end

  def normalize_product_status(wc_status)
    case wc_status
    when "publish" then "active"
    when "draft" then "draft"
    when "pending" then "pending"
    when "private" then "archived"
    else wc_status
    end
  end
end
