# Abstract base class for e-commerce platform adapters
# Defines the interface that all platform adapters must implement
class EcommerceAdapter
  # Adapter-specific errors
  class AdapterError < StandardError; end
  class AuthenticationError < AdapterError; end
  class ConnectionError < AdapterError; end
  class RateLimitError < AdapterError; end
  class NotImplementedError < AdapterError; end

  attr_reader :data_source, :logger

  def initialize(data_source)
    @data_source = data_source
    @logger = Rails.logger
  end

  # Authentication and connection methods
  def validate_connection
    raise NotImplementedError, "Subclasses must implement validate_connection"
  end

  def test_connection
    begin
      validate_connection
      { status: :success, message: "Connection successful" }
    rescue => error
      { status: :error, message: error.message, error_type: error.class.name }
    end
  end

  # Data extraction methods - must be implemented by subclasses
  def fetch_orders(options = {})
    raise NotImplementedError, "Subclasses must implement fetch_orders"
  end

  def fetch_customers(options = {})
    raise NotImplementedError, "Subclasses must implement fetch_customers"
  end

  def fetch_products(options = {})
    raise NotImplementedError, "Subclasses must implement fetch_products"
  end

  def fetch_inventory(options = {})
    raise NotImplementedError, "Subclasses must implement fetch_inventory"
  end

  # Platform capability methods
  def supports_realtime?
    false
  end

  def supports_incremental_sync?
    true
  end

  def supports_webhooks?
    false
  end

  def rate_limit_per_hour
    1000 # Conservative default
  end

  def max_records_per_request
    250 # Conservative default
  end

  # Platform metadata
  def platform_name
    raise NotImplementedError, "Subclasses must implement platform_name"
  end

  def api_version
    "v1" # Default version
  end

  def required_config_fields
    raise NotImplementedError, "Subclasses must implement required_config_fields"
  end

  # Configuration helpers
  def configuration
    data_source.configuration || {}
  end

  def config_valid?
    missing_config_fields.empty?
  end

  def missing_config_fields
    required_config_fields - configuration.keys
  end

  # Common error handling patterns
  def handle_api_error(response)
    case response.status
    when 401
      raise AuthenticationError, "Invalid credentials for #{platform_name}"
    when 403
      raise AuthenticationError, "Access denied - check API permissions for #{platform_name}"
    when 429
      raise RateLimitError, "#{platform_name} API rate limit exceeded"
    when 404
      raise ConnectionError, "#{platform_name} resource not found"
    when 500..599
      raise ConnectionError, "#{platform_name} server error: #{response.status}"
    else
      raise AdapterError, "#{platform_name} API error: #{response.status} - #{response.body}"
    end
  end

  # Pagination helpers
  def paginate_requests(initial_url, &block)
    all_records = []
    current_url = initial_url
    page_count = 0
    max_pages = 1000 # Safety limit

    while current_url && page_count < max_pages
      logger.debug "Fetching page #{page_count + 1}: #{current_url}"

      response = yield(current_url)
      page_data = parse_response_data(response)

      all_records.concat(page_data[:records])
      current_url = page_data[:next_page_url]
      page_count += 1

      # Rate limiting pause
      sleep(rate_limit_delay) if rate_limit_delay > 0
    end

    logger.info "Fetched #{all_records.count} records across #{page_count} pages"
    all_records
  end

  # Rate limiting helpers
  def rate_limit_delay
    # Calculate delay to stay under rate limit
    requests_per_second = rate_limit_per_hour / 3600.0
    1.0 / requests_per_second
  end

  def with_rate_limiting(&block)
    # Simple rate limiting - can be enhanced with sliding window
    start_time = Time.current
    result = yield
    elapsed = Time.current - start_time

    min_delay = rate_limit_delay
    remaining_delay = min_delay - elapsed

    sleep(remaining_delay) if remaining_delay > 0

    result
  end

  # Retry logic with exponential backoff
  def retry_with_backoff(max_retries: 3, base_delay: 1, &block)
    retries = 0

    begin
      yield
    rescue RateLimitError, Net::TimeoutError => error
      retries += 1

      if retries <= max_retries
        delay = base_delay * (2 ** (retries - 1)) # Exponential backoff
        jitter = rand(0.1..0.3) * delay # Add jitter

        logger.info "#{platform_name} retry #{retries}/#{max_retries} in #{delay + jitter} seconds"
        sleep(delay + jitter)
        retry
      else
        logger.error "#{platform_name} max retries exceeded: #{error.message}"
        raise error
      end
    end
  end

  # Response parsing - must be implemented by subclasses
  def parse_response_data(response)
    raise NotImplementedError, "Subclasses must implement parse_response_data"
  end

  # URL building helpers
  def build_base_url
    raise NotImplementedError, "Subclasses must implement build_base_url"
  end

  def build_endpoint_url(endpoint, params = {})
    base_url = build_base_url
    url = "#{base_url}/#{endpoint}"

    if params.any?
      query_string = params.to_query
      url += "?#{query_string}"
    end

    url
  end

  # HTTP client helpers
  def http_client
    @http_client ||= build_http_client
  end

  def build_http_client
    require "faraday"
    require "faraday/retry"

    Faraday.new(
      url: build_base_url,
      headers: build_headers
    ) do |faraday|
      faraday.request :retry, max: 2, interval: 0.5
      faraday.response :raise_error, include_request: true
      faraday.adapter Faraday.default_adapter
    end
  end

  def build_headers
    {
      "Content-Type" => "application/json",
      "User-Agent" => "DataRefinery/#{Rails.application.config.version || '1.0'} (#{platform_name} Adapter)"
    }
  end

  # Incremental sync helpers
  def build_sync_params(options = {})
    params = {}

    # Add since parameter for incremental sync
    if options[:since] && supports_incremental_sync?
      params[:updated_at_min] = options[:since].iso8601
    end

    # Add pagination
    params[:limit] = max_records_per_request

    params
  end

  # Data normalization helpers
  def normalize_timestamp(timestamp_string)
    return nil unless timestamp_string

    begin
      Time.parse(timestamp_string).utc
    rescue ArgumentError
      logger.warn "Invalid timestamp format: #{timestamp_string}"
      nil
    end
  end

  def normalize_currency(currency_string)
    return "USD" unless currency_string
    currency_string.upcase
  end

  def normalize_decimal(decimal_string)
    return 0.0 unless decimal_string

    begin
      decimal_string.to_f
    rescue ArgumentError
      0.0
    end
  end

  def normalize_integer(integer_string)
    return 0 unless integer_string

    begin
      integer_string.to_i
    rescue ArgumentError
      0
    end
  end

  # Logging helpers
  def log_request(method, url, params = {})
    logger.debug "#{platform_name} #{method.upcase} #{url}"
    logger.debug "#{platform_name} Params: #{params.inspect}" if params.any?
  end

  def log_response(response, record_count = nil)
    logger.debug "#{platform_name} Response: #{response.status}"
    logger.info "#{platform_name} Fetched #{record_count} records" if record_count
  end

  # Error context for debugging
  def error_context
    {
      platform: platform_name,
      data_source_id: data_source.id,
      organization_id: data_source.organization_id,
      configuration_valid: config_valid?,
      missing_fields: missing_config_fields
    }
  end

  # Webhook management (for platforms that support it)
  def create_webhook(endpoint_url, events = [])
    raise NotImplementedError, "#{platform_name} adapter does not support webhooks"
  end

  def delete_webhook(webhook_id)
    raise NotImplementedError, "#{platform_name} adapter does not support webhooks"
  end

  def list_webhooks
    raise NotImplementedError, "#{platform_name} adapter does not support webhooks"
  end

  # Health check and diagnostics
  def platform_status
    {
      platform: platform_name,
      api_version: api_version,
      connection_valid: test_connection[:status] == :success,
      rate_limit_remaining: rate_limit_remaining,
      last_successful_sync: data_source.last_sync_at,
      configuration_valid: config_valid?,
      supports_realtime: supports_realtime?,
      supports_incremental: supports_incremental_sync?
    }
  end

  def rate_limit_remaining
    # Override in subclasses that provide rate limit info
    nil
  end

  # Adapter registration for factory
  class << self
    def register_adapter(platform_name, adapter_class)
      @adapters ||= {}
      @adapters[platform_name.to_s] = adapter_class
    end

    def get_adapter_class(platform_name)
      @adapters ||= {}
      @adapters[platform_name.to_s]
    end

    def supported_platforms
      @adapters ||= {}
      @adapters.keys
    end
  end
end
