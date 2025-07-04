# ApiExtractor
# Generic REST API extractor with pagination, authentication, and rate limiting
class ApiExtractor < BaseExtractor
  include HTTParty
  
  AUTHENTICATION_TYPES = %w[api_key bearer oauth2 basic custom_header].freeze
  
  def initialize(data_source)
    super
    @base_uri = data_source.connection_details['base_url']
    @auth_type = data_source.connection_details['auth_type']
    @rate_limiter = RateLimiter.new(
      max_requests: data_source.connection_details['rate_limit'] || 100,
      window: data_source.connection_details['rate_limit_window'] || 60
    )
  end
  
  protected
  
  def validate_connection
    response = make_request(
      endpoint: data_source.connection_details['health_check_endpoint'] || '/',
      method: :get
    )
    
    unless response.success?
      raise ConnectionError, "API connection failed: #{response.code} - #{response.message}"
    end
  end
  
  def fetch_data(options = {})
    endpoint = options[:endpoint] || data_source.connection_details['default_endpoint']
    method = (options[:method] || 'GET').downcase.to_sym
    
    if options[:paginated]
      fetch_paginated_data(endpoint, method, options)
    else
      fetch_single_page(endpoint, method, options)
    end
  end
  
  def get_schema_info
    # For APIs, schema is often documented separately or discoverable via specific endpoints
    schema_endpoint = data_source.connection_details['schema_endpoint']
    return {} unless schema_endpoint
    
    response = make_request(endpoint: schema_endpoint, method: :get)
    parse_api_schema(response.parsed_response) if response.success?
  end
  
  private
  
  def make_request(endpoint:, method:, params: {}, body: nil, headers: {})
    @rate_limiter.throttle do
      url = build_url(endpoint)
      options = build_request_options(params, body, headers)
      
      @logger.debug "Making #{method.upcase} request to #{url}"
      
      response = self.class.send(method, url, options)
      
      handle_rate_limiting(response)
      handle_errors(response)
      
      response
    end
  end
  
  def build_url(endpoint)
    # Handle both absolute and relative URLs
    if endpoint.start_with?('http://', 'https://')
      endpoint
    else
      URI.join(@base_uri, endpoint).to_s
    end
  end
  
  def build_request_options(params, body, additional_headers)
    options = {
      headers: build_headers(additional_headers),
      timeout: data_source.connection_details['timeout'] || 30
    }
    
    options[:query] = params if params.present?
    options[:body] = format_body(body) if body.present?
    
    options
  end
  
  def build_headers(additional_headers = {})
    headers = {
      'User-Agent' => "DataRefineryPlatform/1.0",
      'Accept' => 'application/json'
    }
    
    # Add authentication headers
    case @auth_type
    when 'api_key'
      add_api_key_auth(headers)
    when 'bearer'
      add_bearer_auth(headers)
    when 'oauth2'
      add_oauth2_auth(headers)
    when 'basic'
      add_basic_auth(headers)
    when 'custom_header'
      add_custom_header_auth(headers)
    end
    
    headers.merge(additional_headers)
  end
  
  def add_api_key_auth(headers)
    api_key = data_source.credentials['api_key']
    key_location = data_source.connection_details['api_key_location'] || 'header'
    key_name = data_source.connection_details['api_key_name'] || 'X-API-Key'
    
    case key_location
    when 'header'
      headers[key_name] = api_key
    when 'query'
      # Will be added to query params in make_request
    end
  end
  
  def add_bearer_auth(headers)
    token = data_source.credentials['access_token']
    headers['Authorization'] = "Bearer #{token}"
  end
  
  def add_oauth2_auth(headers)
    # OAuth2 implementation would involve token refresh logic
    token = refresh_oauth2_token_if_needed
    headers['Authorization'] = "Bearer #{token}"
  end
  
  def add_basic_auth(headers)
    username = data_source.credentials['username']
    password = data_source.credentials['password']
    credentials = Base64.strict_encode64("#{username}:#{password}")
    headers['Authorization'] = "Basic #{credentials}"
  end
  
  def add_custom_header_auth(headers)
    custom_headers = data_source.credentials['custom_headers'] || {}
    headers.merge!(custom_headers)
  end
  
  def format_body(body)
    case data_source.connection_details['content_type']
    when 'application/x-www-form-urlencoded'
      body.to_query
    when 'application/xml'
      body.to_xml
    else
      body.to_json
    end
  end
  
  def fetch_single_page(endpoint, method, options)
    response = make_request(
      endpoint: endpoint,
      method: method,
      params: options[:params],
      body: options[:body]
    )
    
    parse_response(response)
  end
  
  def fetch_paginated_data(endpoint, method, options)
    pagination_type = data_source.connection_details['pagination_type'] || 'offset'
    
    case pagination_type
    when 'offset'
      fetch_offset_pagination(endpoint, method, options)
    when 'cursor'
      fetch_cursor_pagination(endpoint, method, options)
    when 'page'
      fetch_page_pagination(endpoint, method, options)
    when 'link_header'
      fetch_link_header_pagination(endpoint, method, options)
    else
      raise NotImplementedError, "Pagination type #{pagination_type} not supported"
    end
  end
  
  def fetch_offset_pagination(endpoint, method, options)
    all_data = []
    offset = 0
    limit = options[:page_size] || 100
    
    loop do
      params = (options[:params] || {}).merge(
        data_source.connection_details['offset_param'] || 'offset' => offset,
        data_source.connection_details['limit_param'] || 'limit' => limit
      )
      
      response = make_request(endpoint: endpoint, method: method, params: params)
      data = parse_response(response)
      
      break if data.empty?
      
      all_data.concat(data)
      offset += limit
      
      # Check if we've reached the total count if available
      if response.headers['x-total-count']
        total = response.headers['x-total-count'].to_i
        break if offset >= total
      end
    end
    
    all_data
  end
  
  def fetch_cursor_pagination(endpoint, method, options)
    all_data = []
    cursor = nil
    
    loop do
      params = options[:params] || {}
      params[data_source.connection_details['cursor_param'] || 'cursor'] = cursor if cursor
      
      response = make_request(endpoint: endpoint, method: method, params: params)
      result = response.parsed_response
      
      # Extract data and next cursor based on API structure
      data_field = data_source.connection_details['data_field'] || 'data'
      cursor_field = data_source.connection_details['cursor_field'] || 'next_cursor'
      
      data = result[data_field] || result
      all_data.concat(Array(data))
      
      cursor = result[cursor_field]
      break unless cursor
    end
    
    all_data
  end
  
  def fetch_page_pagination(endpoint, method, options)
    all_data = []
    page = 1
    page_size = options[:page_size] || 100
    
    loop do
      params = (options[:params] || {}).merge(
        data_source.connection_details['page_param'] || 'page' => page,
        data_source.connection_details['page_size_param'] || 'per_page' => page_size
      )
      
      response = make_request(endpoint: endpoint, method: method, params: params)
      data = parse_response(response)
      
      break if data.empty?
      
      all_data.concat(data)
      page += 1
      
      # Check for total pages if available
      if response.headers['x-total-pages']
        total_pages = response.headers['x-total-pages'].to_i
        break if page > total_pages
      end
    end
    
    all_data
  end
  
  def fetch_link_header_pagination(endpoint, method, options)
    all_data = []
    next_url = build_url(endpoint)
    
    while next_url
      response = self.class.get(next_url, build_request_options(options[:params], nil, {}))
      data = parse_response(response)
      all_data.concat(data)
      
      # Parse Link header for next page
      link_header = response.headers['link']
      next_url = parse_link_header(link_header)['next'] if link_header
    end
    
    all_data
  end
  
  def parse_link_header(header)
    links = {}
    
    header.split(',').each do |link|
      if link =~ /<(.+?)>;\s*rel="(.+?)"/
        url, rel = $1, $2
        links[rel] = url
      end
    end
    
    links
  end
  
  def parse_response(response)
    return [] unless response.success?
    
    data = response.parsed_response
    
    # Handle nested data structure
    if data_field = data_source.connection_details['data_field']
      data = data.dig(*data_field.split('.'))
    end
    
    Array(data)
  end
  
  def handle_rate_limiting(response)
    if response.code == 429
      retry_after = response.headers['retry-after']&.to_i || 60
      raise RateLimitError, "Rate limit exceeded. Retry after #{retry_after} seconds"
    end
    
    # Update rate limiter with actual limits from headers if available
    if response.headers['x-ratelimit-limit']
      @rate_limiter.update_limits(
        limit: response.headers['x-ratelimit-limit'].to_i,
        remaining: response.headers['x-ratelimit-remaining']&.to_i,
        reset: response.headers['x-ratelimit-reset']&.to_i
      )
    end
  end
  
  def handle_errors(response)
    case response.code
    when 401
      raise AuthenticationError, "Authentication failed: #{response.message}"
    when 403
      raise AuthenticationError, "Access forbidden: #{response.message}"
    when 404
      raise ExtractionError, "Resource not found: #{response.message}"
    when 500..599
      raise ExtractionError, "Server error: #{response.code} - #{response.message}"
    end
  end
  
  def refresh_oauth2_token_if_needed
    # OAuth2 token refresh implementation
    credentials = data_source.credentials
    
    if Time.current > Time.parse(credentials['token_expires_at'])
      new_token = refresh_oauth2_token(credentials['refresh_token'])
      
      # Update credentials with new token
      data_source.update_credentials(
        access_token: new_token['access_token'],
        refresh_token: new_token['refresh_token'] || credentials['refresh_token'],
        token_expires_at: Time.current + new_token['expires_in'].seconds
      )
      
      new_token['access_token']
    else
      credentials['access_token']
    end
  end
  
  def refresh_oauth2_token(refresh_token)
    # Implementation depends on OAuth2 provider
    # This is a generic example
    response = self.class.post(
      data_source.connection_details['token_endpoint'],
      body: {
        grant_type: 'refresh_token',
        refresh_token: refresh_token,
        client_id: data_source.credentials['client_id'],
        client_secret: data_source.credentials['client_secret']
      }
    )
    
    response.parsed_response
  end
  
  def parse_api_schema(schema_data)
    # Convert API schema format to our standard format
    # This would be customized based on the API's schema format
    schema_data
  end
  
  # RateLimiter helper class
  class RateLimiter
    def initialize(max_requests:, window:)
      @max_requests = max_requests
      @window = window
      @requests = []
      @mutex = Mutex.new
    end
    
    def throttle
      @mutex.synchronize do
        now = Time.current
        @requests.reject! { |time| time < now - @window }
        
        if @requests.size >= @max_requests
          sleep_time = @requests.first + @window - now
          sleep(sleep_time) if sleep_time > 0
          @requests.shift
        end
        
        @requests << now
      end
      
      yield
    end
    
    def update_limits(limit:, remaining:, reset:)
      @mutex.synchronize do
        @max_requests = limit if limit
        # Could implement more sophisticated tracking based on remaining and reset
      end
    end
  end
end