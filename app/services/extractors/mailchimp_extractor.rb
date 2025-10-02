# frozen_string_literal: true

# Mailchimp Marketing API Integration Extractor
# Extracts email marketing data from Mailchimp using OAuth 2.0 and Marketing API v3.0
#
# Supported Data Types:
# - Lists: Email lists with subscriber counts and stats
# - Campaigns: Email campaigns with send statistics
# - Campaign Reports: Detailed campaign performance metrics
# - List Members: Subscriber data including activity and engagement
# - Automations: Automated email workflow data
#
# Authentication: OAuth 2.0 with refresh token support
# Rate Limit: 10 requests/second (600/minute)
# API Version: v3.0
#
# Required Configuration:
# - access_token: OAuth access token
# - refresh_token: OAuth refresh token for token renewal
# - token_expires_at: Expiration timestamp for access token
# - server_prefix: Mailchimp data center prefix (e.g., us19)

class MailchimpExtractor < BaseExtractor
  MAILCHIMP_API_VERSION = "3.0"

  # Data types supported for extraction
  DATA_TYPES = %w[
    lists
    campaigns
    campaign_reports
    list_members
    automations
  ].freeze

  # Required configuration fields for Mailchimp connection
  REQUIRED_CONFIG_FIELDS = %w[
    access_token
    refresh_token
    server_prefix
  ].freeze

  # Maximum records per API request
  MAX_RESULTS_PER_PAGE = 1000
  DEFAULT_RESULTS_PER_PAGE = 100

  # Rate limiting (Mailchimp allows 10 requests/second)
  MAX_REQUESTS_PER_SECOND = 10
  MAX_REQUESTS_PER_MINUTE = 600

  # Token refresh window (refresh if expires within 5 minutes)
  TOKEN_REFRESH_WINDOW = 5.minutes

  def initialize(data_source)
    super(data_source)
    @rate_limiter = RateLimiter.new(MAX_REQUESTS_PER_MINUTE)
  end

  # Validate connection to Mailchimp API
  # Tests authentication and API connectivity
  #
  # @raise [AuthenticationError] if credentials are invalid or missing
  # @raise [ConnectionError] if API is unreachable
  def validate_connection
    unless config_valid?
      raise AuthenticationError, "Missing required Mailchimp configuration: #{missing_config_fields.join(', ')}"
    end

    # Refresh token if needed before validation
    refresh_access_token_if_needed

    with_rate_limiting do
      # Test connection with account info query
      response = mailchimp_client.get("/3.0/")

      unless response.success?
        handle_api_error(response)
      end

      account_info = JSON.parse(response.body)
      logger.info "Successfully connected to Mailchimp account: #{account_info['account_name']}"
    end
  rescue Faraday::UnauthorizedError
    raise AuthenticationError, "Invalid Mailchimp credentials - token may be expired"
  rescue Faraday::Error => e
    raise ConnectionError, "Failed to connect to Mailchimp API: #{e.message}"
  end

  # Main extraction method - extracts all configured data types
  #
  # @return [Array<Hash>] extracted records with metadata
  def perform_extraction
    logger.info "Starting Mailchimp data extraction for #{data_source.name}"

    all_data = []
    configured_types = data_source.configuration["data_types"] || DATA_TYPES

    configured_types.each do |data_type|
      logger.info "Extracting Mailchimp #{data_type}..."

      begin
        data = extract_data_type(data_type)
        all_data.concat(data)
        logger.info "Successfully extracted #{data.size} #{data_type} records"
      rescue StandardError => e
        logger.error "Failed to extract #{data_type}: #{e.message}"
        raise ExtractionError, "Extraction failed for #{data_type}: #{e.message}"
      end
    end

    logger.info "Completed Mailchimp extraction: #{all_data.size} total records"
    all_data
  end

  private

  # Extract data based on type
  def extract_data_type(data_type)
    case data_type
    when "lists"
      extract_lists
    when "campaigns"
      extract_campaigns
    when "campaign_reports"
      extract_campaign_reports
    when "list_members"
      extract_list_members
    when "automations"
      extract_automations
    else
      raise ArgumentError, "Unsupported data type: #{data_type}"
    end
  end

  # Extract email lists
  def extract_lists
    logger.info "Fetching Mailchimp lists..."

    lists = []
    offset = 0

    loop do
      with_rate_limiting do
        response = mailchimp_client.get("/3.0/lists", {
          offset: offset,
          count: DEFAULT_RESULTS_PER_PAGE,
          sort_field: "date_created",
          sort_dir: "DESC"
        })

        handle_api_error(response) unless response.success?

        data = JSON.parse(response.body)
        batch = data["lists"] || []

        lists.concat(batch.map { |list| normalize_list(list) })

        break if batch.size < DEFAULT_RESULTS_PER_PAGE
        offset += batch.size
      end
    end

    lists
  end

  # Extract email campaigns
  def extract_campaigns
    logger.info "Fetching Mailchimp campaigns..."

    campaigns = []
    offset = 0

    # Filter by date if incremental sync is configured
    params = {
      offset: offset,
      count: DEFAULT_RESULTS_PER_PAGE,
      sort_field: "send_time",
      sort_dir: "DESC",
      status: "sent" # Focus on sent campaigns for reporting
    }

    if last_sync_at.present?
      params[:since_send_time] = last_sync_at.iso8601
    end

    loop do
      with_rate_limiting do
        response = mailchimp_client.get("/3.0/campaigns", params)

        handle_api_error(response) unless response.success?

        data = JSON.parse(response.body)
        batch = data["campaigns"] || []

        campaigns.concat(batch.map { |campaign| normalize_campaign(campaign) })

        break if batch.size < DEFAULT_RESULTS_PER_PAGE
        offset += batch.size
        params[:offset] = offset
      end
    end

    campaigns
  end

  # Extract campaign performance reports
  def extract_campaign_reports
    logger.info "Fetching Mailchimp campaign reports..."

    # First get list of sent campaigns
    campaigns = extract_campaigns

    reports = []

    campaigns.each do |campaign|
      campaign_id = campaign[:external_id]

      with_rate_limiting do
        response = mailchimp_client.get("/3.0/reports/#{campaign_id}")

        next unless response.success?

        report_data = JSON.parse(response.body)
        reports << normalize_campaign_report(report_data)
      end
    end

    reports
  end

  # Extract list members (subscribers)
  def extract_list_members
    logger.info "Fetching Mailchimp list members..."

    # First get all lists
    lists = extract_lists

    members = []

    lists.each do |list|
      list_id = list[:external_id]
      offset = 0

      logger.info "Fetching members for list: #{list[:data]['name']}"

      loop do
        with_rate_limiting do
          response = mailchimp_client.get("/3.0/lists/#{list_id}/members", {
            offset: offset,
            count: DEFAULT_RESULTS_PER_PAGE,
            sort_field: "timestamp_opt",
            sort_dir: "DESC"
          })

          handle_api_error(response) unless response.success?

          data = JSON.parse(response.body)
          batch = data["members"] || []

          members.concat(batch.map { |member| normalize_list_member(member, list_id) })

          break if batch.size < DEFAULT_RESULTS_PER_PAGE
          offset += batch.size
        end
      end
    end

    members
  end

  # Extract automation workflows
  def extract_automations
    logger.info "Fetching Mailchimp automations..."

    automations = []
    offset = 0

    loop do
      with_rate_limiting do
        response = mailchimp_client.get("/3.0/automations", {
          offset: offset,
          count: DEFAULT_RESULTS_PER_PAGE
        })

        handle_api_error(response) unless response.success?

        data = JSON.parse(response.body)
        batch = data["automations"] || []

        automations.concat(batch.map { |automation| normalize_automation(automation) })

        break if batch.size < DEFAULT_RESULTS_PER_PAGE
        offset += batch.size
      end
    end

    automations
  end

  # Normalize list data to standard format
  def normalize_list(list)
    {
      record_type: "list",
      external_id: list["id"],
      extracted_at: Time.current.iso8601,
      data: {
        id: list["id"],
        name: list["name"],
        web_id: list["web_id"],
        subscriber_count: list["stats"]["member_count"],
        unsubscribe_count: list["stats"]["unsubscribe_count"],
        cleaned_count: list["stats"]["cleaned_count"],
        open_rate: list["stats"]["open_rate"],
        click_rate: list["stats"]["click_rate"],
        date_created: list["date_created"],
        campaign_defaults: list["campaign_defaults"],
        stats: list["stats"]
      },
      metadata: {
        source: "mailchimp",
        api_version: MAILCHIMP_API_VERSION,
        list_id: list["id"]
      }
    }
  end

  # Normalize campaign data to standard format
  def normalize_campaign(campaign)
    {
      record_type: "campaign",
      external_id: campaign["id"],
      extracted_at: Time.current.iso8601,
      data: {
        id: campaign["id"],
        web_id: campaign["web_id"],
        type: campaign["type"],
        status: campaign["status"],
        subject_line: campaign["settings"]["subject_line"],
        from_name: campaign["settings"]["from_name"],
        reply_to: campaign["settings"]["reply_to"],
        list_id: campaign["recipients"]["list_id"],
        segment_text: campaign["recipients"]["segment_text"],
        emails_sent: campaign["emails_sent"],
        send_time: campaign["send_time"],
        create_time: campaign["create_time"],
        archive_url: campaign["archive_url"]
      },
      metadata: {
        source: "mailchimp",
        api_version: MAILCHIMP_API_VERSION,
        campaign_id: campaign["id"],
        list_id: campaign["recipients"]["list_id"]
      }
    }
  end

  # Normalize campaign report data to standard format
  def normalize_campaign_report(report)
    {
      record_type: "campaign_report",
      external_id: report["id"],
      extracted_at: Time.current.iso8601,
      data: {
        campaign_id: report["id"],
        campaign_title: report["campaign_title"],
        type: report["type"],
        list_id: report["list_id"],
        emails_sent: report["emails_sent"],
        abuse_reports: report["abuse_reports"],
        unsubscribed: report["unsubscribed"],
        hard_bounces: report["bounces"]["hard_bounces"],
        soft_bounces: report["bounces"]["soft_bounces"],
        syntax_errors: report["bounces"]["syntax_errors"],
        forwards_count: report["forwards"]["forwards_count"],
        opens_total: report["opens"]["opens_total"],
        unique_opens: report["opens"]["unique_opens"],
        open_rate: report["opens"]["open_rate"],
        clicks_total: report["clicks"]["clicks_total"],
        unique_clicks: report["clicks"]["unique_clicks"],
        click_rate: report["clicks"]["click_rate"],
        send_time: report["send_time"],
        industry_stats: report["industry_stats"]
      },
      metadata: {
        source: "mailchimp",
        api_version: MAILCHIMP_API_VERSION,
        campaign_id: report["id"],
        list_id: report["list_id"]
      }
    }
  end

  # Normalize list member data to standard format
  def normalize_list_member(member, list_id)
    {
      record_type: "list_member",
      external_id: member["id"],
      extracted_at: Time.current.iso8601,
      data: {
        id: member["id"],
        email_address: member["email_address"],
        unique_email_id: member["unique_email_id"],
        status: member["status"],
        member_rating: member["member_rating"],
        timestamp_signup: member["timestamp_signup"],
        timestamp_opt: member["timestamp_opt"],
        last_changed: member["last_changed"],
        email_client: member["email_client"],
        location: member["location"],
        merge_fields: member["merge_fields"],
        stats: member["stats"],
        tags: member["tags"]
      },
      metadata: {
        source: "mailchimp",
        api_version: MAILCHIMP_API_VERSION,
        list_id: list_id,
        email: member["email_address"]
      }
    }
  end

  # Normalize automation data to standard format
  def normalize_automation(automation)
    {
      record_type: "automation",
      external_id: automation["id"],
      extracted_at: Time.current.iso8601,
      data: {
        id: automation["id"],
        status: automation["status"],
        title: automation["settings"]["title"],
        from_name: automation["settings"]["from_name"],
        reply_to: automation["settings"]["reply_to"],
        recipients_list_id: automation["recipients"]["list_id"],
        emails_sent: automation["emails_sent"],
        create_time: automation["create_time"],
        start_time: automation["start_time"],
        tracking: automation["tracking"]
      },
      metadata: {
        source: "mailchimp",
        api_version: MAILCHIMP_API_VERSION,
        automation_id: automation["id"]
      }
    }
  end

  # Check if configuration is valid
  def config_valid?
    REQUIRED_CONFIG_FIELDS.all? { |field| configuration[field].present? }
  end

  # Get missing configuration fields
  def missing_config_fields
    REQUIRED_CONFIG_FIELDS.reject { |field| configuration[field].present? }
  end

  # Refresh access token if expiring soon
  def refresh_access_token_if_needed
    return unless token_expires_soon?

    logger.info "Mailchimp access token expiring soon, refreshing..."

    # Trigger refresh through OAuth controller
    # In production, this would call the refresh endpoint
    # For now, we'll just log and rely on the OAuth flow
    logger.warn "Token refresh needed - implement OAuth refresh endpoint call"
  end

  # Check if token expires within refresh window
  def token_expires_soon?
    return false unless configuration["token_expires_at"].present?

    expires_at = Time.parse(configuration["token_expires_at"])
    expires_at < (Time.current + TOKEN_REFRESH_WINDOW)
  rescue ArgumentError
    false
  end

  # Get last sync timestamp
  def last_sync_at
    data_source.last_synced_at
  end

  # Get Mailchimp server prefix from configuration
  def server_prefix
    configuration["server_prefix"]
  end

  # Get access token
  def access_token
    configuration["access_token"]
  end

  # Create Faraday HTTP client for Mailchimp API
  def mailchimp_client
    @mailchimp_client ||= Faraday.new(
      url: "https://#{server_prefix}.api.mailchimp.com",
      headers: {
        "Authorization" => "Bearer #{access_token}",
        "Content-Type" => "application/json",
        "User-Agent" => "DataRefineryPlatform/1.0"
      }
    ) do |faraday|
      faraday.request :json
      faraday.response :json, content_type: /\bjson$/
      faraday.response :raise_error
      faraday.adapter Faraday.default_adapter
    end
  end

  # Handle API errors
  def handle_api_error(response)
    error_body = JSON.parse(response.body) rescue {}
    error_message = error_body["title"] || error_body["detail"] || "Unknown error"
    error_type = error_body["type"] || "unknown"

    case response.status
    when 401
      raise AuthenticationError, "Mailchimp authentication failed: #{error_message}"
    when 403
      raise AuthenticationError, "Mailchimp access forbidden: #{error_message}"
    when 429
      retry_after = response.headers["Retry-After"] || 60
      raise RateLimitError, "Mailchimp rate limit exceeded, retry after #{retry_after} seconds"
    when 500..599
      raise ConnectionError, "Mailchimp server error: #{error_message}"
    else
      raise ExtractionError, "Mailchimp API error (#{error_type}): #{error_message}"
    end
  end

  # Execute block with rate limiting
  def with_rate_limiting(&block)
    @rate_limiter.execute(&block)
  end

  # Logger instance
  def logger
    @logger ||= Rails.logger
  end
end
