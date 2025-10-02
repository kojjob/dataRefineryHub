# frozen_string_literal: true

# QuickBooks Online Integration Extractor
# Extracts financial data from QuickBooks Online using OAuth 2.0 and REST API v3
#
# Supported Record Types:
# - Invoices: Customer invoices with line items and payment status
# - Expenses: Expense transactions and bills
# - Customers: Customer master data
# - Accounts: Chart of accounts
# - ProfitAndLoss: Financial reports (P&L statements)
# - BalanceSheet: Financial reports (Balance sheets)
#
# Authentication: OAuth 2.0 with refresh token support
# Rate Limit: 500 API calls per minute
# API Version: v3
#
# Required Configuration:
# - realm_id: QuickBooks company ID
# - access_token: OAuth access token
# - refresh_token: OAuth refresh token for token renewal
# - token_expires_at: Expiration timestamp for access token

class QuickbooksExtractor < BaseExtractor
  QUICKBOOKS_API_VERSION = "v3"
  QUICKBOOKS_BASE_URL = "https://quickbooks.api.intuit.com"

  # Record types supported for extraction
  RECORD_TYPES = %w[
    invoices
    expenses
    customers
    accounts
    profit_loss
    balance_sheet
  ].freeze

  # Required configuration fields for QuickBooks connection
  REQUIRED_CONFIG_FIELDS = %w[
    realm_id
    access_token
    refresh_token
  ].freeze

  # Maximum records per API request (QuickBooks limit)
  MAX_RESULTS_PER_PAGE = 1000
  DEFAULT_RESULTS_PER_PAGE = 100

  # Rate limiting
  MAX_REQUESTS_PER_MINUTE = 500

  # Token refresh window (refresh if expires within 5 minutes)
  TOKEN_REFRESH_WINDOW = 5.minutes

  def initialize(data_source)
    super(data_source)
    @rate_limiter = RateLimiter.new(MAX_REQUESTS_PER_MINUTE)
  end

  # Validate connection to QuickBooks API
  # Tests authentication and API connectivity
  #
  # @raise [AuthenticationError] if credentials are invalid or missing
  # @raise [ConnectionError] if API is unreachable
  def validate_connection
    unless config_valid?
      raise AuthenticationError, "Missing required QuickBooks configuration: #{missing_config_fields.join(', ')}"
    end

    # Refresh token if needed before validation
    refresh_access_token_if_needed

    with_rate_limiting do
      # Test connection with company info query
      response = quickbooks_client.get(
        "/v3/company/#{realm_id}/companyinfo/#{realm_id}"
      )

      unless response.success?
        handle_api_error(response)
      end

      company_info = JSON.parse(response.body)["CompanyInfo"]
      logger.info "Successfully connected to QuickBooks company: #{company_info['CompanyName']}"
    end
  rescue Faraday::UnauthorizedError
    raise AuthenticationError, "Invalid QuickBooks credentials - token may be expired"
  rescue Faraday::Error => e
    raise ConnectionError, "Failed to connect to QuickBooks API: #{e.message}"
  end

  # Main extraction method - extracts all configured record types
  # Implements incremental sync using LastUpdatedTime filter
  #
  # @return [Array<Hash>] extracted records with metadata
  def perform_extraction
    logger.info "Starting QuickBooks data extraction for #{data_source.name}"

    all_data = []

    RECORD_TYPES.each do |record_type|
      logger.info "Extracting #{record_type} from QuickBooks"

      records = extract_record_type(record_type)

      logger.info "Extracted #{records.count} #{record_type} records"
      all_data.concat(records)
    end

    logger.info "Completed QuickBooks extraction: #{all_data.count} total records"
    all_data
  end

  # Transform QuickBooks data to standardized format
  # Each record type has specific normalization logic
  #
  # @param raw_data [Array<Hash>] raw data from QuickBooks API
  # @return [Array<Hash>] normalized data in standard format
  def normalize_data(raw_data)
    raw_data.map do |record|
      case record[:record_type]
      when "invoices"
        normalize_invoice(record[:data])
      when "expenses"
        normalize_expense(record[:data])
      when "customers"
        normalize_customer(record[:data])
      when "accounts"
        normalize_account(record[:data])
      when "profit_loss"
        normalize_profit_loss(record[:data])
      when "balance_sheet"
        normalize_balance_sheet(record[:data])
      else
        record
      end
    end
  end

  private

  # Extract specific record type from QuickBooks
  #
  # @param record_type [String] type of record to extract
  # @return [Array<Hash>] extracted records
  def extract_record_type(record_type)
    case record_type
    when "invoices"
      extract_invoices
    when "expenses"
      extract_expenses
    when "customers"
      extract_customers
    when "accounts"
      extract_accounts
    when "profit_loss"
      extract_profit_loss_report
    when "balance_sheet"
      extract_balance_sheet_report
    else
      raise ExtractionError, "Unknown QuickBooks record type: #{record_type}"
    end
  end

  # Extract invoices from QuickBooks
  # Supports incremental sync using LastUpdatedTime filter
  #
  # @return [Array<Hash>] invoice records with metadata
  def extract_invoices
    query = "SELECT * FROM Invoice"

    # Add incremental sync filter if last sync exists
    if data_source.last_sync_at && supports_incremental_sync?
      query += " WHERE MetaData.LastUpdatedTime > '#{data_source.last_sync_at.iso8601}'"
    end

    query += " ORDERBY MetaData.LastUpdatedTime ASC"

    execute_query(query, "invoices")
  end

  # Extract expenses from QuickBooks
  # Includes both expense transactions and bills
  #
  # @return [Array<Hash>] expense records
  def extract_expenses
    # Extract Purchase transactions (expenses)
    purchases_query = "SELECT * FROM Purchase"

    if data_source.last_sync_at && supports_incremental_sync?
      purchases_query += " WHERE MetaData.LastUpdatedTime > '#{data_source.last_sync_at.iso8601}'"
    end

    purchases_query += " ORDERBY MetaData.LastUpdatedTime ASC"

    purchases = execute_query(purchases_query, "expenses")

    # Extract Bills
    bills_query = "SELECT * FROM Bill"

    if data_source.last_sync_at && supports_incremental_sync?
      bills_query += " WHERE MetaData.LastUpdatedTime > '#{data_source.last_sync_at.iso8601}'"
    end

    bills_query += " ORDERBY MetaData.LastUpdatedTime ASC"

    bills = execute_query(bills_query, "expenses")

    purchases + bills
  end

  # Extract customers from QuickBooks
  #
  # @return [Array<Hash>] customer records
  def extract_customers
    query = "SELECT * FROM Customer"

    if data_source.last_sync_at && supports_incremental_sync?
      query += " WHERE MetaData.LastUpdatedTime > '#{data_source.last_sync_at.iso8601}'"
    end

    query += " ORDERBY MetaData.LastUpdatedTime ASC"

    execute_query(query, "customers")
  end

  # Extract chart of accounts from QuickBooks
  #
  # @return [Array<Hash>] account records
  def extract_accounts
    query = "SELECT * FROM Account WHERE Active = true"

    if data_source.last_sync_at && supports_incremental_sync?
      query += " AND MetaData.LastUpdatedTime > '#{data_source.last_sync_at.iso8601}'"
    end

    query += " ORDERBY MetaData.LastUpdatedTime ASC"

    execute_query(query, "accounts")
  end

  # Extract Profit & Loss report from QuickBooks
  # Uses Reports API instead of Query API
  #
  # @return [Array<Hash>] P&L report data
  def extract_profit_loss_report
    report_data = []

    with_rate_limiting do
      response = retry_with_backoff do
        quickbooks_client.get(
          "/v3/company/#{realm_id}/reports/ProfitAndLoss",
          {
            start_date: (data_source.last_sync_at || 90.days.ago).to_date.to_s,
            end_date: Date.current.to_s,
            accounting_method: "Accrual"
          }
        )
      end

      handle_api_error(response) unless response.success?

      report = JSON.parse(response.body)

      report_data << {
        record_type: "profit_loss",
        data: report,
        extracted_at: Time.current
      }
    end

    report_data
  end

  # Extract Balance Sheet report from QuickBooks
  #
  # @return [Array<Hash>] balance sheet report data
  def extract_balance_sheet_report
    report_data = []

    with_rate_limiting do
      response = retry_with_backoff do
        quickbooks_client.get(
          "/v3/company/#{realm_id}/reports/BalanceSheet",
          {
            date: Date.current.to_s,
            accounting_method: "Accrual"
          }
        )
      end

      handle_api_error(response) unless response.success?

      report = JSON.parse(response.body)

      report_data << {
        record_type: "balance_sheet",
        data: report,
        extracted_at: Time.current
      }
    end

    report_data
  end

  # Execute QuickBooks query with pagination
  # Handles automatic pagination using startPosition parameter
  #
  # @param query [String] QuickBooks SQL-like query
  # @param record_type [String] type of record being queried
  # @return [Array<Hash>] query results
  def execute_query(query, record_type)
    results = []
    start_position = 1
    max_results = DEFAULT_RESULTS_PER_PAGE

    loop do
      paginated_query = "#{query} STARTPOSITION #{start_position} MAXRESULTS #{max_results}"

      response = retry_with_backoff do
        with_rate_limiting do
          quickbooks_client.get(
            "/v3/company/#{realm_id}/query",
            { query: paginated_query, minorversion: "65" }
          )
        end
      end

      handle_api_error(response) unless response.success?

      data = JSON.parse(response.body)
      query_response = data["QueryResponse"]

      # Extract records from response
      records = extract_records_from_query_response(query_response, record_type)

      break if records.empty?

      records.each do |record|
        results << {
          record_type: record_type,
          data: record,
          extracted_at: Time.current
        }
      end

      # Check if more pages exist
      break if records.count < max_results

      start_position += max_results
    end

    results
  end

  # Extract records from QueryResponse based on record type
  #
  # @param query_response [Hash] QuickBooks query response
  # @param record_type [String] type of record
  # @return [Array<Hash>] extracted records
  def extract_records_from_query_response(query_response, record_type)
    return [] unless query_response

    case record_type
    when "invoices"
      query_response["Invoice"] || []
    when "expenses"
      (query_response["Purchase"] || []) + (query_response["Bill"] || [])
    when "customers"
      query_response["Customer"] || []
    when "accounts"
      query_response["Account"] || []
    else
      []
    end
  end

  # Normalize invoice data to standard format
  #
  # @param invoice_data [Hash] raw invoice data from QuickBooks
  # @return [Hash] normalized invoice data
  def normalize_invoice(invoice_data)
    {
      external_id: invoice_data["Id"],
      invoice_number: invoice_data["DocNumber"],
      customer_id: invoice_data.dig("CustomerRef", "value"),
      customer_name: invoice_data.dig("CustomerRef", "name"),
      invoice_date: invoice_data["TxnDate"],
      due_date: invoice_data["DueDate"],
      total_amount: invoice_data["TotalAmt"]&.to_f,
      balance: invoice_data["Balance"]&.to_f,
      currency: invoice_data.dig("CurrencyRef", "value") || "USD",
      status: determine_invoice_status(invoice_data),
      line_items: normalize_invoice_line_items(invoice_data["Line"] || []),
      billing_address: normalize_address(invoice_data["BillAddr"]),
      shipping_address: normalize_address(invoice_data["ShipAddr"]),
      created_at: invoice_data.dig("MetaData", "CreateTime"),
      updated_at: invoice_data.dig("MetaData", "LastUpdatedTime"),
      raw_data: invoice_data
    }
  end

  # Determine invoice payment status
  #
  # @param invoice_data [Hash] invoice data
  # @return [String] status (paid, partially_paid, unpaid)
  def determine_invoice_status(invoice_data)
    balance = invoice_data["Balance"]&.to_f || 0
    total = invoice_data["TotalAmt"]&.to_f || 0

    if balance.zero?
      "paid"
    elsif balance < total
      "partially_paid"
    else
      "unpaid"
    end
  end

  # Normalize invoice line items
  #
  # @param line_items [Array<Hash>] raw line items
  # @return [Array<Hash>] normalized line items
  def normalize_invoice_line_items(line_items)
    line_items.select { |line| line["DetailType"] == "SalesItemLineDetail" }.map do |line|
      detail = line["SalesItemLineDetail"] || {}

      {
        description: line["Description"],
        quantity: detail["Qty"]&.to_f,
        unit_price: detail["UnitPrice"]&.to_f,
        amount: line["Amount"]&.to_f,
        item_id: detail.dig("ItemRef", "value"),
        item_name: detail.dig("ItemRef", "name"),
        tax_code: detail.dig("TaxCodeRef", "value")
      }
    end
  end

  # Normalize expense data
  #
  # @param expense_data [Hash] raw expense data
  # @return [Hash] normalized expense data
  def normalize_expense(expense_data)
    {
      external_id: expense_data["Id"],
      transaction_type: expense_data["TxnType"] || "Purchase",
      transaction_date: expense_data["TxnDate"],
      total_amount: expense_data["TotalAmt"]&.to_f,
      currency: expense_data.dig("CurrencyRef", "value") || "USD",
      vendor_id: expense_data.dig("EntityRef", "value"),
      vendor_name: expense_data.dig("EntityRef", "name"),
      payment_method: expense_data["PaymentType"],
      account_id: expense_data.dig("AccountRef", "value"),
      account_name: expense_data.dig("AccountRef", "name"),
      line_items: normalize_expense_line_items(expense_data["Line"] || []),
      created_at: expense_data.dig("MetaData", "CreateTime"),
      updated_at: expense_data.dig("MetaData", "LastUpdatedTime"),
      raw_data: expense_data
    }
  end

  # Normalize expense line items
  #
  # @param line_items [Array<Hash>] raw line items
  # @return [Array<Hash>] normalized line items
  def normalize_expense_line_items(line_items)
    line_items.select { |line| line["DetailType"] == "AccountBasedExpenseLineDetail" }.map do |line|
      detail = line["AccountBasedExpenseLineDetail"] || {}

      {
        description: line["Description"],
        amount: line["Amount"]&.to_f,
        account_id: detail.dig("AccountRef", "value"),
        account_name: detail.dig("AccountRef", "name"),
        customer_id: detail.dig("CustomerRef", "value"),
        customer_name: detail.dig("CustomerRef", "name")
      }
    end
  end

  # Normalize customer data
  #
  # @param customer_data [Hash] raw customer data
  # @return [Hash] normalized customer data
  def normalize_customer(customer_data)
    {
      external_id: customer_data["Id"],
      display_name: customer_data["DisplayName"],
      given_name: customer_data["GivenName"],
      family_name: customer_data["FamilyName"],
      company_name: customer_data["CompanyName"],
      email: customer_data.dig("PrimaryEmailAddr", "Address"),
      phone: customer_data.dig("PrimaryPhone", "FreeFormNumber"),
      billing_address: normalize_address(customer_data["BillAddr"]),
      shipping_address: normalize_address(customer_data["ShipAddr"]),
      balance: customer_data["Balance"]&.to_f,
      active: customer_data["Active"],
      created_at: customer_data.dig("MetaData", "CreateTime"),
      updated_at: customer_data.dig("MetaData", "LastUpdatedTime"),
      raw_data: customer_data
    }
  end

  # Normalize account (chart of accounts) data
  #
  # @param account_data [Hash] raw account data
  # @return [Hash] normalized account data
  def normalize_account(account_data)
    {
      external_id: account_data["Id"],
      name: account_data["Name"],
      fully_qualified_name: account_data["FullyQualifiedName"],
      account_type: account_data["AccountType"],
      account_sub_type: account_data["AccountSubType"],
      classification: account_data["Classification"],
      current_balance: account_data["CurrentBalance"]&.to_f,
      currency: account_data.dig("CurrencyRef", "value") || "USD",
      active: account_data["Active"],
      parent_account_id: account_data.dig("ParentRef", "value"),
      created_at: account_data.dig("MetaData", "CreateTime"),
      updated_at: account_data.dig("MetaData", "LastUpdatedTime"),
      raw_data: account_data
    }
  end

  # Normalize Profit & Loss report data
  #
  # @param report_data [Hash] raw P&L report
  # @return [Hash] normalized report data
  def normalize_profit_loss(report_data)
    {
      report_type: "profit_and_loss",
      report_name: report_data.dig("Header", "ReportName"),
      start_date: report_data.dig("Header", "StartPeriod"),
      end_date: report_data.dig("Header", "EndPeriod"),
      currency: report_data.dig("Header", "Currency"),
      rows: normalize_report_rows(report_data["Rows"]),
      generated_at: Time.current,
      raw_data: report_data
    }
  end

  # Normalize Balance Sheet report data
  #
  # @param report_data [Hash] raw balance sheet report
  # @return [Hash] normalized report data
  def normalize_balance_sheet(report_data)
    {
      report_type: "balance_sheet",
      report_name: report_data.dig("Header", "ReportName"),
      report_date: report_data.dig("Header", "Time"),
      currency: report_data.dig("Header", "Currency"),
      rows: normalize_report_rows(report_data["Rows"]),
      generated_at: Time.current,
      raw_data: report_data
    }
  end

  # Normalize report rows (recursive for nested rows)
  #
  # @param rows [Hash] report rows data
  # @return [Array<Hash>] normalized rows
  def normalize_report_rows(rows)
    return [] unless rows && rows["Row"]

    rows["Row"].map do |row|
      {
        type: row["type"],
        summary: row["Summary"],
        columns: extract_column_data(row["ColData"]),
        rows: row["Rows"] ? normalize_report_rows(row["Rows"]) : []
      }
    end
  end

  # Extract column data from report row
  #
  # @param col_data [Array<Hash>] column data
  # @return [Array<Hash>] extracted values
  def extract_column_data(col_data)
    return [] unless col_data

    col_data.map do |col|
      {
        value: col["value"],
        id: col["id"]
      }
    end
  end

  # Normalize address data
  #
  # @param address_data [Hash] raw address data
  # @return [Hash] normalized address
  def normalize_address(address_data)
    return nil unless address_data

    {
      line1: address_data["Line1"],
      line2: address_data["Line2"],
      line3: address_data["Line3"],
      line4: address_data["Line4"],
      line5: address_data["Line5"],
      city: address_data["City"],
      country_sub_division_code: address_data["CountrySubDivisionCode"],
      postal_code: address_data["PostalCode"],
      country: address_data["Country"],
      lat: address_data["Lat"],
      long: address_data["Long"]
    }
  end

  # Refresh OAuth access token if needed
  # QuickBooks access tokens expire after 1 hour
  def refresh_access_token_if_needed
    return unless should_refresh_token?

    logger.info "Refreshing QuickBooks access token"

    response = refresh_token_client.post(
      "/oauth2/v1/tokens/bearer",
      {
        grant_type: "refresh_token",
        refresh_token: refresh_token
      }
    )

    unless response.success?
      raise AuthenticationError, "Failed to refresh QuickBooks token: #{response.body}"
    end

    token_data = JSON.parse(response.body)

    # Update data source with new tokens
    data_source.update!(
      configuration: data_source.configuration.merge(
        access_token: token_data["access_token"],
        refresh_token: token_data["refresh_token"],
        token_expires_at: (Time.current + token_data["expires_in"].seconds).iso8601
      )
    )

    logger.info "Successfully refreshed QuickBooks access token"
  rescue => e
    raise AuthenticationError, "Token refresh failed: #{e.message}"
  end

  # Check if access token should be refreshed
  #
  # @return [Boolean] true if token needs refresh
  def should_refresh_token?
    return true unless token_expires_at

    expires_at = Time.parse(token_expires_at)
    expires_at < (Time.current + TOKEN_REFRESH_WINDOW)
  rescue ArgumentError
    true
  end

  # Execute block with rate limiting
  # QuickBooks allows 500 API calls per minute
  #
  # @yield block to execute with rate limiting
  def with_rate_limiting(&block)
    @rate_limiter.execute(&block)
  end

  # Retry failed requests with exponential backoff
  # Handles transient errors and rate limiting
  #
  # @param max_attempts [Integer] maximum retry attempts
  # @yield block to retry
  # @return result of block
  def retry_with_backoff(max_attempts: 3, &block)
    attempt = 0

    begin
      attempt += 1
      yield
    rescue Faraday::TooManyRequestsError => e
      if attempt < max_attempts
        wait_time = 2**attempt + rand(0..1)
        logger.warn "Rate limit exceeded, retrying in #{wait_time}s (attempt #{attempt}/#{max_attempts})"
        sleep wait_time
        retry
      else
        raise RateLimitError, "QuickBooks rate limit exceeded after #{max_attempts} attempts"
      end
    rescue Faraday::ServerError => e
      if attempt < max_attempts
        wait_time = 2**attempt
        logger.warn "Server error, retrying in #{wait_time}s (attempt #{attempt}/#{max_attempts})"
        sleep wait_time
        retry
      else
        raise
      end
    end
  end

  # Handle QuickBooks API errors
  #
  # @param response [Faraday::Response] HTTP response
  # @raise appropriate error based on response status
  def handle_api_error(response)
    error_body = begin
      JSON.parse(response.body)
    rescue JSON::ParserError
      {}
    end

    error_message = error_body.dig("Fault", "Error", 0, "Message") || response.body
    error_code = error_body.dig("Fault", "Error", 0, "code")

    case response.status
    when 401
      raise AuthenticationError, "QuickBooks authentication failed: #{error_message}"
    when 403
      raise AuthenticationError, "QuickBooks access forbidden: #{error_message}"
    when 429
      raise RateLimitError, "QuickBooks rate limit exceeded"
    when 400
      raise DataValidationError, "Invalid QuickBooks request (#{error_code}): #{error_message}"
    when 500..599
      raise ConnectionError, "QuickBooks server error (#{response.status}): #{error_message}"
    else
      raise ExtractionError, "QuickBooks API error (#{response.status}, code: #{error_code}): #{error_message}"
    end
  end

  # Get Faraday HTTP client for QuickBooks API
  #
  # @return [Faraday::Connection] configured HTTP client
  def quickbooks_client
    @quickbooks_client ||= begin
      require "faraday"
      require "faraday/retry"

      Faraday.new(
        url: QUICKBOOKS_BASE_URL,
        headers: {
          "Authorization" => "Bearer #{access_token}",
          "Accept" => "application/json",
          "Content-Type" => "application/json",
          "User-Agent" => "DataRefinery/1.0"
        }
      ) do |faraday|
        faraday.request :url_encoded
        faraday.request :retry, max: 2, interval: 0.5
        faraday.response :raise_error
        faraday.adapter Faraday.default_adapter
      end
    end
  end

  # Get Faraday HTTP client for OAuth token refresh
  #
  # @return [Faraday::Connection] OAuth client
  def refresh_token_client
    @refresh_token_client ||= begin
      require "faraday"

      Faraday.new(
        url: "https://oauth.platform.intuit.com",
        headers: {
          "Accept" => "application/json",
          "Content-Type" => "application/x-www-form-urlencoded",
          "Authorization" => "Basic #{encoded_credentials}"
        }
      ) do |faraday|
        faraday.request :url_encoded
        faraday.response :raise_error
        faraday.adapter Faraday.default_adapter
      end
    end
  end

  # Encode OAuth client credentials for token refresh
  #
  # @return [String] Base64 encoded credentials
  def encoded_credentials
    # In production, these would come from Rails credentials
    client_id = Rails.application.credentials.dig(:quickbooks, :client_id)
    client_secret = Rails.application.credentials.dig(:quickbooks, :client_secret)

    Base64.strict_encode64("#{client_id}:#{client_secret}")
  end

  # Validate required configuration fields are present
  #
  # @return [Boolean] true if all required fields present
  def config_valid?
    missing_config_fields.empty?
  end

  # Get list of missing required configuration fields
  #
  # @return [Array<String>] missing field names
  def missing_config_fields
    REQUIRED_CONFIG_FIELDS.reject { |field| data_source.configuration[field].present? }
  end

  # Configuration accessors
  def realm_id
    data_source.configuration["realm_id"]
  end

  def access_token
    data_source.configuration["access_token"]
  end

  def refresh_token
    data_source.configuration["refresh_token"]
  end

  def token_expires_at
    data_source.configuration["token_expires_at"]
  end

  # Check if incremental sync is supported
  #
  # @return [Boolean] true if incremental sync available
  def supports_incremental_sync?
    data_source.last_sync_at.present?
  end

  # Simple rate limiter class
  class RateLimiter
    def initialize(max_requests_per_minute)
      @max_requests = max_requests_per_minute
      @requests = []
      @mutex = Mutex.new
    end

    def execute(&block)
      @mutex.synchronize do
        # Remove requests older than 1 minute
        current_time = Time.current
        @requests.reject! { |time| time < (current_time - 1.minute) }

        # Wait if rate limit would be exceeded
        if @requests.count >= @max_requests
          sleep_time = @requests.first - (current_time - 1.minute)
          sleep(sleep_time) if sleep_time.positive?
          @requests.shift
        end

        @requests << current_time
      end

      yield
    end
  end
end
