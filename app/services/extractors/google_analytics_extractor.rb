# frozen_string_literal: true

require 'net/http'
require 'json'

# Google Analytics 4 (GA4) Data Extractor
# Extracts analytics data using Google Analytics Data API v1
#
# Required Configuration:
# - property_id: GA4 property ID (format: "properties/123456789")
# - access_token: OAuth 2.0 access token
# - refresh_token: OAuth 2.0 refresh token
# - token_expires_at: Token expiration timestamp
#
# Optional Configuration:
# - metrics: Array of metrics to extract (default: common metrics)
# - dimensions: Array of dimensions to extract (default: common dimensions)
# - date_ranges: Array of date ranges (default: last 30 days)
# - metric_filter: Metric filter expression
# - dimension_filter: Dimension filter expression
class GoogleAnalyticsExtractor < BaseExtractor
  API_BASE_URL = 'https://analyticsdata.googleapis.com/v1beta'
  TOKEN_REFRESH_URL = 'https://oauth2.googleapis.com/token'

  # GA4 API rate limits: 25,000 tokens per day per project
  MAX_REQUESTS_PER_HOUR = 1000
  MAX_ROWS_PER_REQUEST = 10000

  class << self
    def required_fields
      %w[property_id access_token refresh_token]
    end

    def optional_fields
      %w[metrics dimensions date_ranges metric_filter dimension_filter]
    end

    def supports_realtime?
      true
    end

    def supports_incremental_sync?
      true
    end

    def rate_limit_per_hour
      MAX_REQUESTS_PER_HOUR
    end
  end

  def validate_connection
    ensure_valid_token

    # Test connection by fetching property metadata
    uri = URI("#{API_BASE_URL}/#{property_id}/metadata")
    request = build_authenticated_request(uri, Net::HTTP::Get)

    response = execute_request(uri, request)

    unless response.is_a?(Net::HTTPSuccess)
      error_message = parse_error_response(response)
      raise AuthenticationError, "GA4 connection failed: #{error_message}"
    end

    @logger.info "GA4 connection validated for property: #{property_id}"
    true
  end

  def perform_extraction
    ensure_valid_token

    extracted_records = []
    report_requests = build_report_requests

    report_requests.each_with_index do |request_config, index|
      @logger.info "Fetching GA4 report #{index + 1}/#{report_requests.size}: #{request_config[:name]}"

      report_data = fetch_report_with_pagination(request_config)
      normalized_data = normalize_report_data(report_data, request_config[:name])

      extracted_records.concat(normalized_data)

      # Rate limiting: wait between requests
      sleep(0.5) if index < report_requests.size - 1
    end

    @logger.info "Extracted #{extracted_records.size} GA4 records across #{report_requests.size} reports"
    extracted_records
  end

  protected

  def normalize_data(record)
    {
      source: 'google_analytics',
      property_id: property_id,
      report_type: record[:report_type],
      date: record[:date],
      dimensions: record[:dimensions],
      metrics: record[:metrics],
      metadata: record[:metadata] || {},
      extracted_at: Time.current,
      record_hash: generate_record_hash(record)
    }
  end

  private

  # Configuration accessors

  def property_id
    config['property_id'] || raise(AuthenticationError, "GA4 property_id not configured")
  end

  def access_token
    config['access_token']
  end

  def refresh_token
    config['refresh_token']
  end

  def token_expires_at
    Time.parse(config['token_expires_at']) if config['token_expires_at']
  rescue ArgumentError
    nil
  end

  def config
    @data_source.configuration
  end

  # Token management

  def ensure_valid_token
    return if token_valid?

    @logger.info "GA4 access token expired or missing, refreshing..."
    refresh_access_token
  end

  def token_valid?
    return false unless access_token.present?
    return false unless token_expires_at.present?

    # Refresh if token expires within 5 minutes
    token_expires_at > 5.minutes.from_now
  end

  def refresh_access_token
    unless refresh_token.present?
      raise AuthenticationError, "No refresh token available for GA4"
    end

    uri = URI(TOKEN_REFRESH_URL)
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/x-www-form-urlencoded'

    request.set_form_data(
      client_id: google_client_id,
      client_secret: google_client_secret,
      refresh_token: refresh_token,
      grant_type: 'refresh_token'
    )

    response = execute_request(uri, request)

    unless response.is_a?(Net::HTTPSuccess)
      error_message = parse_error_response(response)
      raise AuthenticationError, "Failed to refresh GA4 token: #{error_message}"
    end

    token_data = JSON.parse(response.body)

    # Update data source with new token
    @data_source.update!(
      configuration: config.merge(
        'access_token' => token_data['access_token'],
        'token_expires_at' => (Time.current + token_data['expires_in'].to_i.seconds).iso8601,
        'token_refreshed_at' => Time.current.iso8601
      )
    )

    @logger.info "GA4 access token refreshed successfully"
  end

  # Report configuration

  def build_report_requests
    date_ranges = configured_date_ranges

    [
      {
        name: 'traffic_overview',
        metrics: traffic_metrics,
        dimensions: traffic_dimensions,
        date_ranges: date_ranges
      },
      {
        name: 'user_acquisition',
        metrics: acquisition_metrics,
        dimensions: acquisition_dimensions,
        date_ranges: date_ranges
      },
      {
        name: 'engagement',
        metrics: engagement_metrics,
        dimensions: engagement_dimensions,
        date_ranges: date_ranges
      },
      {
        name: 'conversions',
        metrics: conversion_metrics,
        dimensions: conversion_dimensions,
        date_ranges: date_ranges
      }
    ]
  end

  def configured_date_ranges
    custom_ranges = config['date_ranges']
    return custom_ranges if custom_ranges.present?

    # Default: last 30 days
    [
      {
        'startDate' => 30.days.ago.strftime('%Y-%m-%d'),
        'endDate' => Date.yesterday.strftime('%Y-%m-%d')
      }
    ]
  end

  # Metric definitions

  def traffic_metrics
    config['metrics'] || %w[
      sessions
      totalUsers
      newUsers
      screenPageViews
      averageSessionDuration
      bounceRate
    ]
  end

  def acquisition_metrics
    %w[
      sessions
      totalUsers
      newUsers
      conversions
    ]
  end

  def engagement_metrics
    %w[
      engagedSessions
      engagementRate
      averageSessionDuration
      screenPageViews
      screenPageViewsPerSession
    ]
  end

  def conversion_metrics
    %w[
      conversions
      totalRevenue
      ecommercePurchases
      transactions
    ]
  end

  # Dimension definitions

  def traffic_dimensions
    config['dimensions'] || %w[date country city deviceCategory]
  end

  def acquisition_dimensions
    %w[date sessionSource sessionMedium sessionCampaignName]
  end

  def engagement_dimensions
    %w[date pagePath pageTitle landingPage]
  end

  def conversion_dimensions
    %w[date eventName transactionId]
  end

  # API communication

  def fetch_report_with_pagination(request_config)
    all_rows = []
    offset = 0

    loop do
      report_response = fetch_report_page(request_config, offset)

      rows = report_response.dig('rows') || []
      all_rows.concat(rows)

      row_count = report_response.dig('rowCount')&.to_i || 0

      @logger.debug "Fetched #{rows.size} rows (total: #{all_rows.size}/#{row_count})"

      # Check if we have all rows
      break if all_rows.size >= row_count || rows.empty?
      break if rows.size < MAX_ROWS_PER_REQUEST

      offset += rows.size
      sleep(0.2) # Rate limiting between pagination requests
    end

    {
      name: request_config[:name],
      metrics: request_config[:metrics],
      dimensions: request_config[:dimensions],
      date_ranges: request_config[:date_ranges],
      rows: all_rows
    }
  end

  def fetch_report_page(request_config, offset = 0)
    uri = URI("#{API_BASE_URL}/#{property_id}:runReport")
    request = build_authenticated_request(uri, Net::HTTP::Post)
    request['Content-Type'] = 'application/json'

    request_body = build_report_request_body(request_config, offset)
    request.body = request_body.to_json

    response = execute_request(uri, request)

    unless response.is_a?(Net::HTTPSuccess)
      error_message = parse_error_response(response)
      raise ConnectionError, "Failed to fetch GA4 report: #{error_message}"
    end

    JSON.parse(response.body)
  end

  def build_report_request_body(request_config, offset)
    {
      dateRanges: request_config[:date_ranges],
      dimensions: request_config[:dimensions].map { |dim| { name: dim } },
      metrics: request_config[:metrics].map { |metric| { name: metric } },
      offset: offset,
      limit: MAX_ROWS_PER_REQUEST,
      keepEmptyRows: false,
      returnPropertyQuota: true
    }.tap do |body|
      # Add optional filters if configured
      body[:dimensionFilter] = config['dimension_filter'] if config['dimension_filter'].present?
      body[:metricFilter] = config['metric_filter'] if config['metric_filter'].present?
    end
  end

  # Data normalization

  def normalize_report_data(report_data, report_name)
    rows = report_data[:rows] || []
    dimension_headers = report_data[:dimensions] || []
    metric_headers = report_data[:metrics] || []

    rows.map do |row|
      dimension_values = extract_dimension_values(row, dimension_headers)
      metric_values = extract_metric_values(row, metric_headers)

      {
        report_type: report_name,
        date: extract_date_from_dimensions(dimension_values),
        dimensions: dimension_values,
        metrics: metric_values,
        metadata: {
          property_id: property_id,
          date_ranges: report_data[:date_ranges]
        }
      }
    end
  end

  def extract_dimension_values(row, dimension_headers)
    dimension_values = row.dig('dimensionValues') || []

    dimension_headers.each_with_index.map do |dimension, index|
      value = dimension_values[index]&.dig('value')
      [dimension, value]
    end.to_h
  end

  def extract_metric_values(row, metric_headers)
    metric_values = row.dig('metricValues') || []

    metric_headers.each_with_index.map do |metric, index|
      value = metric_values[index]&.dig('value')
      # Convert numeric values
      numeric_value = value.to_f if value.present?
      [metric, numeric_value]
    end.to_h
  end

  def extract_date_from_dimensions(dimensions)
    dimensions['date'] || Date.today.strftime('%Y%m%d')
  end

  # HTTP utilities

  def build_authenticated_request(uri, request_class)
    request = request_class.new(uri)
    request['Authorization'] = "Bearer #{access_token}"
    request['Accept'] = 'application/json'
    request
  end

  def execute_request(uri, request, max_retries: 3)
    retries = 0

    begin
      Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError => e
      retries += 1

      if retries <= max_retries
        @logger.warn "Request timeout (attempt #{retries}/#{max_retries}): #{e.message}"
        sleep(2 ** retries) # Exponential backoff
        retry
      else
        raise ConnectionError, "Request failed after #{max_retries} attempts: #{e.message}"
      end
    end
  end

  def parse_error_response(response)
    error_data = JSON.parse(response.body)
    error_message = error_data.dig('error', 'message') || response.message
    error_code = error_data.dig('error', 'code') || response.code

    "#{error_code}: #{error_message}"
  rescue JSON::ParserError
    "#{response.code}: #{response.message}"
  end

  # Utility methods

  def google_client_id
    Rails.application.credentials.dig(:google, :client_id) ||
      ENV['GOOGLE_CLIENT_ID'] ||
      raise(AuthenticationError, "Google Client ID not configured")
  end

  def google_client_secret
    Rails.application.credentials.dig(:google, :client_secret) ||
      ENV['GOOGLE_CLIENT_SECRET'] ||
      raise(AuthenticationError, "Google Client Secret not configured")
  end

  def generate_record_hash(record)
    # Create unique hash for deduplication
    hash_input = "#{property_id}_#{record[:report_type]}_#{record[:date]}_#{record[:dimensions]}"
    Digest::SHA256.hexdigest(hash_input)
  end

  def determine_record_type(record)
    record[:report_type] || 'analytics_data'
  end

  def extract_external_id(record)
    record[:record_hash]
  end
end
