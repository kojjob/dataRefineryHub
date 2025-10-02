# frozen_string_literal: true

require 'rails_helper'

RSpec.describe QuickbooksExtractor, type: :service do
  let(:organization) { create(:organization) }

  let(:valid_configuration) do
    {
      realm_id: '123456789',
      access_token: 'test_access_token',
      refresh_token: 'test_refresh_token',
      token_expires_at: (Time.current + 30.minutes).iso8601
    }
  end

  let(:data_source) do
    create(
      :data_source,
      organization: organization,
      source_type: 'quickbooks',
      configuration: valid_configuration
    )
  end

  let(:extractor) { described_class.new(data_source) }

  # Mock QuickBooks API responses
  let(:company_info_response) do
    {
      'CompanyInfo' => {
        'CompanyName' => 'Test Company',
        'Id' => '123456789'
      }
    }
  end

  let(:invoice_response) do
    {
      'QueryResponse' => {
        'Invoice' => [
          {
            'Id' => '1',
            'DocNumber' => 'INV-001',
            'CustomerRef' => { 'value' => '5', 'name' => 'Test Customer' },
            'TxnDate' => '2024-01-15',
            'DueDate' => '2024-02-15',
            'TotalAmt' => 1500.00,
            'Balance' => 1500.00,
            'Line' => [
              {
                'DetailType' => 'SalesItemLineDetail',
                'Description' => 'Professional Services',
                'Amount' => 1500.00,
                'SalesItemLineDetail' => {
                  'Qty' => 10,
                  'UnitPrice' => 150.00,
                  'ItemRef' => { 'value' => '3', 'name' => 'Consulting' }
                }
              }
            ],
            'MetaData' => {
              'CreateTime' => '2024-01-15T10:00:00Z',
              'LastUpdatedTime' => '2024-01-15T10:00:00Z'
            }
          }
        ]
      }
    }
  end

  let(:customer_response) do
    {
      'QueryResponse' => {
        'Customer' => [
          {
            'Id' => '5',
            'DisplayName' => 'Test Customer',
            'GivenName' => 'John',
            'FamilyName' => 'Doe',
            'CompanyName' => 'Test Company LLC',
            'PrimaryEmailAddr' => { 'Address' => 'john@example.com' },
            'PrimaryPhone' => { 'FreeFormNumber' => '555-0123' },
            'Balance' => 5000.00,
            'Active' => true,
            'MetaData' => {
              'CreateTime' => '2024-01-01T10:00:00Z',
              'LastUpdatedTime' => '2024-01-01T10:00:00Z'
            }
          }
        ]
      }
    }
  end

  let(:profit_loss_response) do
    {
      'Header' => {
        'ReportName' => 'ProfitAndLoss',
        'StartPeriod' => '2024-01-01',
        'EndPeriod' => '2024-12-31',
        'Currency' => 'USD'
      },
      'Rows' => {
        'Row' => [
          {
            'type' => 'Section',
            'Summary' => {
              'ColData' => [
                { 'value' => 'Total Income' },
                { 'value' => '150000.00' }
              ]
            },
            'ColData' => [
              { 'value' => 'Total Income', 'id' => '' },
              { 'value' => '150000.00', 'id' => '' }
            ]
          }
        ]
      }
    }
  end

  describe '#initialize' do
    it 'sets data source and initializes rate limiter' do
      expect(extractor.data_source).to eq(data_source)
      expect(extractor.instance_variable_get(:@rate_limiter)).to be_present
    end
  end

  describe '#validate_connection' do
    context 'with valid credentials' do
      before do
        stub_company_info_request(realm_id: '123456789', access_token: 'test_access_token')
      end

      it 'successfully validates connection' do
        expect { extractor.validate_connection }.not_to raise_error
      end

      it 'logs success message' do
        expect(Rails.logger).to receive(:info).with(/Successfully connected to QuickBooks/)
        extractor.validate_connection
      end
    end

    context 'with missing configuration' do
      before do
        data_source.update!(configuration: { realm_id: '123456789' })
      end

      it 'raises AuthenticationError for missing fields' do
        expect {
          extractor.validate_connection
        }.to raise_error(
          BaseExtractor::AuthenticationError,
          /Missing required QuickBooks configuration/
        )
      end
    end

    context 'with invalid credentials' do
      before do
        stub_request(:get, /quickbooks\.api\.intuit\.com/)
          .to_return(status: 401, body: { error: 'Unauthorized' }.to_json)
      end

      it 'raises AuthenticationError' do
        expect {
          extractor.validate_connection
        }.to raise_error(BaseExtractor::AuthenticationError, /authentication failed/)
      end
    end

    context 'with expired token' do
      before do
        data_source.update!(
          configuration: valid_configuration.merge(
            token_expires_at: (Time.current - 1.hour).iso8601
          )
        )

        stub_token_refresh_request
        stub_company_info_request(realm_id: '123456789', access_token: 'new_access_token')
      end

      it 'refreshes token before validation' do
        expect(extractor).to receive(:refresh_access_token_if_needed).and_call_original
        extractor.validate_connection
      end

      it 'updates data source with new tokens' do
        extractor.validate_connection

        data_source.reload
        expect(data_source.configuration['access_token']).to eq('new_access_token')
        expect(data_source.configuration['refresh_token']).to eq('new_refresh_token')
      end
    end
  end

  describe '#perform_extraction' do
    before do
      stub_company_info_request(realm_id: '123456789', access_token: 'test_access_token')
      stub_invoice_query
      stub_customer_query
      stub_account_query
      stub_purchase_query
      stub_bill_query
      stub_profit_loss_report
      stub_balance_sheet_report
    end

    it 'extracts all record types' do
      result = extractor.perform_extraction

      expect(result).to be_an(Array)
      expect(result.map { |r| r[:record_type] }).to include(
        'invoices',
        'expenses',
        'customers',
        'accounts',
        'profit_loss',
        'balance_sheet'
      )
    end

    it 'logs extraction progress' do
      expect(Rails.logger).to receive(:info).with(/Starting QuickBooks data extraction/)
      expect(Rails.logger).to receive(:info).with(/Extracting invoices from QuickBooks/)
      expect(Rails.logger).to receive(:info).with(/Completed QuickBooks extraction/)

      extractor.perform_extraction
    end

    it 'includes extracted_at timestamp for each record' do
      result = extractor.perform_extraction

      result.each do |record|
        expect(record[:extracted_at]).to be_present
        expect(record[:extracted_at]).to be_a(Time)
      end
    end
  end

  describe 'invoice extraction' do
    before do
      stub_invoice_query
    end

    it 'extracts invoices with pagination' do
      result = extractor.send(:extract_invoices)

      expect(result).to be_an(Array)
      expect(result.first[:record_type]).to eq('invoices')
      expect(result.first[:data]).to include('Id' => '1', 'DocNumber' => 'INV-001')
    end

    context 'with incremental sync' do
      before do
        data_source.update!(last_sync_at: 1.day.ago)
      end

      it 'includes LastUpdatedTime filter in query' do
        expect_any_instance_of(Faraday::Connection).to receive(:get).with(
          anything,
          hash_including(query: /LastUpdatedTime/)
        ).and_call_original

        extractor.send(:extract_invoices)
      end
    end
  end

  describe 'expense extraction' do
    before do
      stub_purchase_query
      stub_bill_query
    end

    it 'extracts both purchases and bills' do
      result = extractor.send(:extract_expenses)

      expect(result).to be_an(Array)
      expect(result.count).to be >= 0
    end
  end

  describe 'customer extraction' do
    before do
      stub_customer_query
    end

    it 'extracts customer data' do
      result = extractor.send(:extract_customers)

      expect(result).to be_an(Array)
      expect(result.first[:record_type]).to eq('customers')
    end
  end

  describe 'report extraction' do
    before do
      stub_profit_loss_report
      stub_balance_sheet_report
    end

    it 'extracts Profit & Loss report' do
      result = extractor.send(:extract_profit_loss_report)

      expect(result).to be_an(Array)
      expect(result.first[:record_type]).to eq('profit_loss')
      expect(result.first[:data]).to include('Header' => hash_including('ReportName'))
    end

    it 'extracts Balance Sheet report' do
      result = extractor.send(:extract_balance_sheet_report)

      expect(result).to be_an(Array)
      expect(result.first[:record_type]).to eq('balance_sheet')
    end
  end

  describe '#normalize_data' do
    let(:raw_data) do
      [
        {
          record_type: 'invoices',
          data: invoice_response['QueryResponse']['Invoice'].first,
          extracted_at: Time.current
        },
        {
          record_type: 'customers',
          data: customer_response['QueryResponse']['Customer'].first,
          extracted_at: Time.current
        }
      ]
    end

    it 'normalizes all record types' do
      result = extractor.normalize_data(raw_data)

      expect(result).to be_an(Array)
      expect(result.count).to eq(2)
    end

    it 'normalizes invoice data correctly' do
      invoice_data = raw_data.select { |r| r[:record_type] == 'invoices' }
      result = extractor.normalize_data(invoice_data)

      normalized = result.first
      expect(normalized[:external_id]).to eq('1')
      expect(normalized[:invoice_number]).to eq('INV-001')
      expect(normalized[:customer_name]).to eq('Test Customer')
      expect(normalized[:total_amount]).to eq(1500.00)
      expect(normalized[:status]).to eq('unpaid')
      expect(normalized[:line_items]).to be_an(Array)
    end

    it 'normalizes customer data correctly' do
      customer_data = raw_data.select { |r| r[:record_type] == 'customers' }
      result = extractor.normalize_data(customer_data)

      normalized = result.first
      expect(normalized[:external_id]).to eq('5')
      expect(normalized[:display_name]).to eq('Test Customer')
      expect(normalized[:email]).to eq('john@example.com')
      expect(normalized[:balance]).to eq(5000.00)
    end

    it 'preserves raw data in normalized records' do
      result = extractor.normalize_data(raw_data)

      result.each do |record|
        expect(record[:raw_data]).to be_present
      end
    end
  end

  describe 'invoice normalization' do
    let(:invoice_data) { invoice_response['QueryResponse']['Invoice'].first }

    it 'determines correct invoice status' do
      # Unpaid invoice
      invoice_data['Balance'] = invoice_data['TotalAmt']
      normalized = extractor.send(:normalize_invoice, invoice_data)
      expect(normalized[:status]).to eq('unpaid')

      # Partially paid invoice
      invoice_data['Balance'] = invoice_data['TotalAmt'] / 2
      normalized = extractor.send(:normalize_invoice, invoice_data)
      expect(normalized[:status]).to eq('partially_paid')

      # Fully paid invoice
      invoice_data['Balance'] = 0
      normalized = extractor.send(:normalize_invoice, invoice_data)
      expect(normalized[:status]).to eq('paid')
    end

    it 'normalizes invoice line items correctly' do
      normalized = extractor.send(:normalize_invoice, invoice_data)

      expect(normalized[:line_items]).to be_an(Array)
      expect(normalized[:line_items].count).to eq(1)

      line_item = normalized[:line_items].first
      expect(line_item[:description]).to eq('Professional Services')
      expect(line_item[:quantity]).to eq(10.0)
      expect(line_item[:unit_price]).to eq(150.0)
      expect(line_item[:amount]).to eq(1500.0)
    end

    it 'handles missing line items gracefully' do
      invoice_data.delete('Line')
      normalized = extractor.send(:normalize_invoice, invoice_data)

      expect(normalized[:line_items]).to eq([])
    end
  end

  describe 'error handling' do
    context 'when API returns error' do
      before do
        stub_request(:get, /quickbooks\.api\.intuit\.com/)
          .to_return(
            status: 400,
            body: {
              'Fault' => {
                'Error' => [
                  { 'code' => 'BAD_REQUEST', 'Message' => 'Invalid query' }
                ]
              }
            }.to_json
          )
      end

      it 'raises DataValidationError for 400 errors' do
        expect {
          extractor.validate_connection
        }.to raise_error(BaseExtractor::DataValidationError, /Invalid query/)
      end
    end

    context 'when rate limit is exceeded' do
      before do
        stub_request(:get, /quickbooks\.api\.intuit\.com/)
          .to_return(status: 429, body: { error: 'Rate limit exceeded' }.to_json)
      end

      it 'raises RateLimitError' do
        expect {
          extractor.validate_connection
        }.to raise_error(BaseExtractor::RateLimitError)
      end
    end

    context 'when server error occurs' do
      before do
        stub_request(:get, /quickbooks\.api\.intuit\.com/)
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'raises ConnectionError' do
        expect {
          extractor.validate_connection
        }.to raise_error(BaseExtractor::ConnectionError, /server error/)
      end
    end
  end

  describe 'rate limiting' do
    it 'enforces rate limits on API calls' do
      rate_limiter = extractor.instance_variable_get(:@rate_limiter)

      expect(rate_limiter).to receive(:execute).and_call_original

      extractor.send(:with_rate_limiting) { 'test' }
    end
  end

  describe 'token refresh' do
    before do
      stub_token_refresh_request
    end

    context 'when token is about to expire' do
      before do
        data_source.update!(
          configuration: valid_configuration.merge(
            token_expires_at: (Time.current + 2.minutes).iso8601
          )
        )
      end

      it 'refreshes access token' do
        expect(extractor.send(:should_refresh_token?)).to be true

        extractor.send(:refresh_access_token_if_needed)

        data_source.reload
        expect(data_source.configuration['access_token']).to eq('new_access_token')
      end

      it 'logs token refresh' do
        expect(Rails.logger).to receive(:info).with(/Refreshing QuickBooks access token/)
        expect(Rails.logger).to receive(:info).with(/Successfully refreshed/)

        extractor.send(:refresh_access_token_if_needed)
      end
    end

    context 'when token has valid time remaining' do
      it 'does not refresh token' do
        expect(extractor.send(:should_refresh_token?)).to be false

        expect_any_instance_of(Faraday::Connection).not_to receive(:post)

        extractor.send(:refresh_access_token_if_needed)
      end
    end

    context 'when token refresh fails' do
      before do
        data_source.update!(
          configuration: valid_configuration.merge(
            token_expires_at: (Time.current + 2.minutes).iso8601
          )
        )

        stub_request(:post, /oauth\.platform\.intuit\.com/)
          .to_return(status: 400, body: { error: 'Invalid refresh token' }.to_json)
      end

      it 'raises AuthenticationError' do
        expect {
          extractor.send(:refresh_access_token_if_needed)
        }.to raise_error(BaseExtractor::AuthenticationError, /Token refresh failed/)
      end
    end
  end

  describe 'pagination handling' do
    before do
      # First page with results
      stub_request(:get, /quickbooks\.api\.intuit\.com.*STARTPOSITION 1/)
        .to_return(
          status: 200,
          body: {
            'QueryResponse' => {
              'Invoice' => Array.new(100) { |i|
                { 'Id' => (i + 1).to_s, 'DocNumber' => "INV-#{i + 1}" }
              }
            }
          }.to_json
        )

      # Second page with results
      stub_request(:get, /quickbooks\.api\.intuit\.com.*STARTPOSITION 101/)
        .to_return(
          status: 200,
          body: {
            'QueryResponse' => {
              'Invoice' => Array.new(50) { |i|
                { 'Id' => (i + 101).to_s, 'DocNumber' => "INV-#{i + 101}" }
              }
            }
          }.to_json
        )

      # Third page empty (end of pagination)
      stub_request(:get, /quickbooks\.api\.intuit\.com.*STARTPOSITION 201/)
        .to_return(
          status: 200,
          body: { 'QueryResponse' => {} }.to_json
        )
    end

    it 'handles pagination correctly' do
      result = extractor.send(:extract_invoices)

      expect(result.count).to eq(150)
    end
  end

  describe 'retry with backoff' do
    context 'when API call fails temporarily' do
      before do
        call_count = 0
        stub_request(:get, /quickbooks\.api\.intuit\.com/)
          .to_return do |request|
            call_count += 1
            if call_count < 2
              { status: 500, body: 'Server error' }
            else
              { status: 200, body: company_info_response.to_json }
            end
          end
      end

      it 'retries failed requests' do
        expect {
          extractor.send(:retry_with_backoff) do
            extractor.send(:quickbooks_client).get("/v3/company/#{data_source.configuration['realm_id']}/companyinfo/#{data_source.configuration['realm_id']}")
          end
        }.not_to raise_error
      end
    end

    context 'when max retries exceeded' do
      before do
        stub_request(:get, /quickbooks\.api\.intuit\.com/)
          .to_return(status: 500, body: 'Server error')
      end

      it 'raises error after max attempts' do
        expect {
          extractor.send(:retry_with_backoff, max_attempts: 3) do
            extractor.send(:quickbooks_client).get("/v3/company/#{data_source.configuration['realm_id']}/companyinfo/#{data_source.configuration['realm_id']}")
          end
        }.to raise_error(Faraday::ServerError)
      end
    end
  end

  # Helper methods for stubbing API requests

  def stub_company_info_request(realm_id:, access_token:)
    stub_request(:get, "https://quickbooks.api.intuit.com/v3/company/#{realm_id}/companyinfo/#{realm_id}")
      .with(headers: { 'Authorization' => "Bearer #{access_token}" })
      .to_return(status: 200, body: company_info_response.to_json)
  end

  def stub_invoice_query
    stub_request(:get, /quickbooks\.api\.intuit\.com.*Invoice/)
      .to_return(status: 200, body: invoice_response.to_json)
  end

  def stub_customer_query
    stub_request(:get, /quickbooks\.api\.intuit\.com.*Customer/)
      .to_return(status: 200, body: customer_response.to_json)
  end

  def stub_account_query
    stub_request(:get, /quickbooks\.api\.intuit\.com.*Account/)
      .to_return(status: 200, body: { 'QueryResponse' => {} }.to_json)
  end

  def stub_purchase_query
    stub_request(:get, /quickbooks\.api\.intuit\.com.*Purchase/)
      .to_return(status: 200, body: { 'QueryResponse' => {} }.to_json)
  end

  def stub_bill_query
    stub_request(:get, /quickbooks\.api\.intuit\.com.*Bill/)
      .to_return(status: 200, body: { 'QueryResponse' => {} }.to_json)
  end

  def stub_profit_loss_report
    stub_request(:get, /quickbooks\.api\.intuit\.com.*ProfitAndLoss/)
      .to_return(status: 200, body: profit_loss_response.to_json)
  end

  def stub_balance_sheet_report
    stub_request(:get, /quickbooks\.api\.intuit\.com.*BalanceSheet/)
      .to_return(status: 200, body: { 'Header' => {}, 'Rows' => {} }.to_json)
  end

  def stub_token_refresh_request
    stub_request(:post, 'https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer')
      .to_return(
        status: 200,
        body: {
          access_token: 'new_access_token',
          refresh_token: 'new_refresh_token',
          expires_in: 3600
        }.to_json
      )
  end
end
