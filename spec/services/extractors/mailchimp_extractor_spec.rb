# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MailchimpExtractor, type: :service do
  let(:organization) { create(:organization) }

  let(:valid_configuration) do
    {
      access_token: 'test_access_token',
      refresh_token: 'test_refresh_token',
      token_expires_at: (Time.current + 180.days).iso8601,
      server_prefix: 'us19',
      api_endpoint: 'https://us19.api.mailchimp.com',
      data_types: %w[lists campaigns campaign_reports list_members automations]
    }
  end

  let(:data_source) do
    create(
      :data_source,
      organization: organization,
      source_type: 'mailchimp',
      configuration: valid_configuration
    )
  end

  let(:extractor) { described_class.new(data_source) }

  # Mock Mailchimp API responses
  let(:account_info_response) do
    {
      'account_name' => 'Test Mailchimp Account',
      'account_id' => 'test123',
      'email' => 'test@example.com'
    }
  end

  let(:lists_response) do
    {
      'lists' => [
        {
          'id' => 'list123',
          'web_id' => 12345,
          'name' => 'Newsletter Subscribers',
          'date_created' => '2024-01-01T10:00:00Z',
          'stats' => {
            'member_count' => 1500,
            'unsubscribe_count' => 50,
            'cleaned_count' => 10,
            'open_rate' => 25.5,
            'click_rate' => 12.3
          },
          'campaign_defaults' => {
            'from_name' => 'Test Company',
            'from_email' => 'info@example.com',
            'subject' => '',
            'language' => 'en'
          }
        }
      ]
    }
  end

  let(:campaigns_response) do
    {
      'campaigns' => [
        {
          'id' => 'campaign123',
          'web_id' => 45678,
          'type' => 'regular',
          'status' => 'sent',
          'settings' => {
            'subject_line' => 'Monthly Newsletter',
            'from_name' => 'Test Company',
            'reply_to' => 'info@example.com'
          },
          'recipients' => {
            'list_id' => 'list123',
            'segment_text' => 'All subscribers'
          },
          'emails_sent' => 1500,
          'send_time' => '2024-01-15T10:00:00Z',
          'create_time' => '2024-01-10T10:00:00Z',
          'archive_url' => 'https://example.com/archive'
        }
      ]
    }
  end

  let(:campaign_report_response) do
    {
      'id' => 'campaign123',
      'campaign_title' => 'Monthly Newsletter',
      'type' => 'regular',
      'list_id' => 'list123',
      'emails_sent' => 1500,
      'abuse_reports' => 2,
      'unsubscribed' => 5,
      'send_time' => '2024-01-15T10:00:00Z',
      'bounces' => {
        'hard_bounces' => 10,
        'soft_bounces' => 5,
        'syntax_errors' => 2
      },
      'forwards' => {
        'forwards_count' => 50
      },
      'opens' => {
        'opens_total' => 800,
        'unique_opens' => 600,
        'open_rate' => 40.0
      },
      'clicks' => {
        'clicks_total' => 300,
        'unique_clicks' => 250,
        'click_rate' => 16.7
      },
      'industry_stats' => {
        'open_rate' => 21.0,
        'click_rate' => 2.6
      }
    }
  end

  let(:list_members_response) do
    {
      'members' => [
        {
          'id' => 'member123',
          'email_address' => 'subscriber@example.com',
          'unique_email_id' => 'unique123',
          'status' => 'subscribed',
          'member_rating' => 4,
          'timestamp_signup' => '2024-01-01T10:00:00Z',
          'timestamp_opt' => '2024-01-01T10:05:00Z',
          'last_changed' => '2024-01-15T10:00:00Z',
          'email_client' => 'Gmail',
          'location' => {
            'country_code' => 'US',
            'timezone' => 'America/New_York'
          },
          'merge_fields' => {
            'FNAME' => 'John',
            'LNAME' => 'Doe'
          },
          'stats' => {
            'avg_open_rate' => 35.0,
            'avg_click_rate' => 15.0
          },
          'tags' => [
            { 'name' => 'customer', 'id' => 1 }
          ]
        }
      ]
    }
  end

  let(:automations_response) do
    {
      'automations' => [
        {
          'id' => 'automation123',
          'status' => 'sending',
          'settings' => {
            'title' => 'Welcome Series',
            'from_name' => 'Test Company',
            'reply_to' => 'info@example.com'
          },
          'recipients' => {
            'list_id' => 'list123'
          },
          'emails_sent' => 500,
          'create_time' => '2024-01-01T10:00:00Z',
          'start_time' => '2024-01-02T10:00:00Z',
          'tracking' => {
            'opens' => true,
            'html_clicks' => true,
            'text_clicks' => false
          }
        }
      ]
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
        stub_account_info_request(server_prefix: 'us19', access_token: 'test_access_token')
      end

      it 'successfully validates connection' do
        expect { extractor.validate_connection }.not_to raise_error
      end

      it 'logs success message' do
        expect(Rails.logger).to receive(:info).with(/Successfully connected to Mailchimp account/)
        extractor.validate_connection
      end
    end

    context 'with missing configuration' do
      before do
        data_source.update!(configuration: { server_prefix: 'us19' })
      end

      it 'raises AuthenticationError for missing fields' do
        expect {
          extractor.validate_connection
        }.to raise_error(
          BaseExtractor::AuthenticationError,
          /Missing required Mailchimp configuration/
        )
      end
    end

    context 'with invalid credentials' do
      before do
        stub_request(:get, /api\.mailchimp\.com/)
          .to_return(status: 401, body: { title: 'Unauthorized', detail: 'Invalid API Key' }.to_json)
      end

      it 'raises AuthenticationError' do
        expect {
          extractor.validate_connection
        }.to raise_error(BaseExtractor::AuthenticationError, /authentication failed/)
      end
    end
  end

  describe '#perform_extraction' do
    before do
      stub_account_info_request(server_prefix: 'us19', access_token: 'test_access_token')
      stub_lists_query
      stub_campaigns_query
      stub_campaign_report_query('campaign123')
      stub_list_members_query('list123')
      stub_automations_query
    end

    it 'extracts all configured data types' do
      result = extractor.perform_extraction

      expect(result).to be_an(Array)
      expect(result.map { |r| r[:record_type] }).to include(
        'list',
        'campaign',
        'campaign_report',
        'list_member',
        'automation'
      )
    end

    it 'logs extraction progress' do
      expect(Rails.logger).to receive(:info).with(/Starting Mailchimp data extraction/)
      expect(Rails.logger).to receive(:info).with(/Extracting Mailchimp lists/)
      expect(Rails.logger).to receive(:info).with(/Completed Mailchimp extraction/)

      extractor.perform_extraction
    end

    it 'includes extracted_at timestamp for each record' do
      result = extractor.perform_extraction

      result.each do |record|
        expect(record[:extracted_at]).to be_present
        expect(Time.parse(record[:extracted_at])).to be_within(5.seconds).of(Time.current)
      end
    end

    context 'with partial data types configured' do
      before do
        data_source.update!(
          configuration: valid_configuration.merge(
            data_types: %w[lists campaigns]
          )
        )
      end

      it 'only extracts configured data types' do
        result = extractor.perform_extraction

        record_types = result.map { |r| r[:record_type] }
        expect(record_types).to include('list', 'campaign')
        expect(record_types).not_to include('campaign_report', 'list_member', 'automation')
      end
    end
  end

  describe 'list extraction' do
    before do
      stub_lists_query
    end

    it 'extracts lists with pagination' do
      result = extractor.send(:extract_lists)

      expect(result).to be_an(Array)
      expect(result.first[:record_type]).to eq('list')
      expect(result.first[:data]).to include('id' => 'list123', 'name' => 'Newsletter Subscribers')
    end

    it 'normalizes list data correctly' do
      result = extractor.send(:extract_lists)

      list = result.first
      expect(list[:external_id]).to eq('list123')
      expect(list[:data]['subscriber_count']).to eq(1500)
      expect(list[:data]['open_rate']).to eq(25.5)
      expect(list[:data]['click_rate']).to eq(12.3)
      expect(list[:metadata]['source']).to eq('mailchimp')
    end
  end

  describe 'campaign extraction' do
    before do
      stub_campaigns_query
    end

    it 'extracts sent campaigns' do
      result = extractor.send(:extract_campaigns)

      expect(result).to be_an(Array)
      expect(result.first[:record_type]).to eq('campaign')
    end

    it 'normalizes campaign data correctly' do
      result = extractor.send(:extract_campaigns)

      campaign = result.first
      expect(campaign[:external_id]).to eq('campaign123')
      expect(campaign[:data]['subject_line']).to eq('Monthly Newsletter')
      expect(campaign[:data]['emails_sent']).to eq(1500)
      expect(campaign[:data]['status']).to eq('sent')
    end

    context 'with incremental sync enabled' do
      before do
        data_source.update!(last_synced_at: 1.day.ago)
      end

      it 'includes since_send_time parameter in query' do
        expect_any_instance_of(Faraday::Connection).to receive(:get).with(
          '/3.0/campaigns',
          hash_including(since_send_time: anything)
        ).and_call_original

        extractor.send(:extract_campaigns)
      end
    end
  end

  describe 'campaign report extraction' do
    before do
      stub_campaigns_query
      stub_campaign_report_query('campaign123')
    end

    it 'extracts performance reports for campaigns' do
      result = extractor.send(:extract_campaign_reports)

      expect(result).to be_an(Array)
      expect(result.first[:record_type]).to eq('campaign_report')
    end

    it 'normalizes report data correctly' do
      result = extractor.send(:extract_campaign_reports)

      report = result.first
      expect(report[:data]['opens_total']).to eq(800)
      expect(report[:data]['unique_opens']).to eq(600)
      expect(report[:data]['open_rate']).to eq(40.0)
      expect(report[:data]['clicks_total']).to eq(300)
      expect(report[:data]['unique_clicks']).to eq(250)
      expect(report[:data]['hard_bounces']).to eq(10)
    end
  end

  describe 'list member extraction' do
    before do
      stub_lists_query
      stub_list_members_query('list123')
    end

    it 'extracts subscribers for all lists' do
      result = extractor.send(:extract_list_members)

      expect(result).to be_an(Array)
      expect(result.first[:record_type]).to eq('list_member')
    end

    it 'normalizes member data correctly' do
      result = extractor.send(:extract_list_members)

      member = result.first
      expect(member[:data]['email_address']).to eq('subscriber@example.com')
      expect(member[:data]['status']).to eq('subscribed')
      expect(member[:data]['member_rating']).to eq(4)
      expect(member[:metadata]['list_id']).to eq('list123')
    end

    it 'logs list processing' do
      expect(Rails.logger).to receive(:info).with(/Fetching members for list:/)
      extractor.send(:extract_list_members)
    end
  end

  describe 'automation extraction' do
    before do
      stub_automations_query
    end

    it 'extracts automation workflows' do
      result = extractor.send(:extract_automations)

      expect(result).to be_an(Array)
      expect(result.first[:record_type]).to eq('automation')
    end

    it 'normalizes automation data correctly' do
      result = extractor.send(:extract_automations)

      automation = result.first
      expect(automation[:external_id]).to eq('automation123')
      expect(automation[:data]['title']).to eq('Welcome Series')
      expect(automation[:data]['status']).to eq('sending')
      expect(automation[:data]['emails_sent']).to eq(500)
    end
  end

  describe 'error handling' do
    context 'when API returns validation error' do
      before do
        stub_request(:get, /api\.mailchimp\.com/)
          .to_return(
            status: 400,
            body: {
              'title' => 'Invalid Resource',
              'detail' => 'The resource submitted could not be validated',
              'type' => 'validation_error'
            }.to_json
          )
      end

      it 'raises ExtractionError for 400 errors' do
        expect {
          extractor.validate_connection
        }.to raise_error(BaseExtractor::ExtractionError, /validation_error/)
      end
    end

    context 'when rate limit is exceeded' do
      before do
        stub_request(:get, /api\.mailchimp\.com/)
          .to_return(
            status: 429,
            headers: { 'Retry-After' => '60' },
            body: { title: 'Too Many Requests', detail: 'Rate limit exceeded' }.to_json
          )
      end

      it 'raises RateLimitError with retry information' do
        expect {
          extractor.validate_connection
        }.to raise_error(BaseExtractor::RateLimitError, /retry after 60 seconds/)
      end
    end

    context 'when server error occurs' do
      before do
        stub_request(:get, /api\.mailchimp\.com/)
          .to_return(status: 500, body: { title: 'Internal Server Error' }.to_json)
      end

      it 'raises ConnectionError' do
        expect {
          extractor.validate_connection
        }.to raise_error(BaseExtractor::ConnectionError, /server error/)
      end
    end

    context 'when access is forbidden' do
      before do
        stub_request(:get, /api\.mailchimp\.com/)
          .to_return(status: 403, body: { title: 'Forbidden', detail: 'Access denied' }.to_json)
      end

      it 'raises AuthenticationError for 403 errors' do
        expect {
          extractor.validate_connection
        }.to raise_error(BaseExtractor::AuthenticationError, /access forbidden/)
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

  describe 'token management' do
    context 'when tokens do not expire (Mailchimp behavior)' do
      it 'token_expires_soon? returns false for distant expiration' do
        expect(extractor.send(:token_expires_soon?)).to be false
      end

      it 'does not attempt token refresh' do
        expect(extractor).not_to receive(:refresh_access_token)
        extractor.send(:refresh_access_token_if_needed)
      end
    end

    context 'when token_expires_at is missing' do
      before do
        data_source.update!(
          configuration: valid_configuration.except('token_expires_at')
        )
      end

      it 'handles missing expiration gracefully' do
        expect(extractor.send(:token_expires_soon?)).to be false
      end
    end
  end

  describe 'HTTP client configuration' do
    it 'uses correct server prefix in API URL' do
      client = extractor.send(:mailchimp_client)

      expect(client.url_prefix.to_s).to eq('https://us19.api.mailchimp.com/')
    end

    it 'includes bearer token in authorization header' do
      client = extractor.send(:mailchimp_client)

      expect(client.headers['Authorization']).to eq('Bearer test_access_token')
    end

    it 'sets correct content type and user agent' do
      client = extractor.send(:mailchimp_client)

      expect(client.headers['Content-Type']).to eq('application/json')
      expect(client.headers['User-Agent']).to eq('DataRefineryPlatform/1.0')
    end
  end

  describe 'pagination handling' do
    before do
      # First page with 100 lists
      stub_request(:get, /api\.mailchimp\.com.*offset=0/)
        .to_return(
          status: 200,
          body: {
            'lists' => Array.new(100) { |i|
              { 'id' => "list#{i + 1}", 'name' => "List #{i + 1}", 'stats' => {} }
            }
          }.to_json
        )

      # Second page with 50 lists
      stub_request(:get, /api\.mailchimp\.com.*offset=100/)
        .to_return(
          status: 200,
          body: {
            'lists' => Array.new(50) { |i|
              { 'id' => "list#{i + 101}", 'name' => "List #{i + 101}", 'stats' => {} }
            }
          }.to_json
        )

      # Third page empty (end of pagination)
      stub_request(:get, /api\.mailchimp\.com.*offset=150/)
        .to_return(
          status: 200,
          body: { 'lists' => [] }.to_json
        )
    end

    it 'handles pagination correctly' do
      result = extractor.send(:extract_lists)

      expect(result.count).to eq(150)
    end
  end

  describe 'server prefix extraction' do
    it 'extracts server prefix from configuration' do
      expect(extractor.send(:server_prefix)).to eq('us19')
    end

    context 'with different server prefixes' do
      let(:prefixes) { %w[us1 us5 us19 us20] }

      it 'handles various server prefixes correctly' do
        prefixes.each do |prefix|
          data_source.update!(
            configuration: valid_configuration.merge(server_prefix: prefix)
          )

          client = extractor.send(:mailchimp_client)
          expect(client.url_prefix.to_s).to eq("https://#{prefix}.api.mailchimp.com/")
        end
      end
    end
  end

  # Helper methods for stubbing API requests

  def stub_account_info_request(server_prefix:, access_token:)
    stub_request(:get, "https://#{server_prefix}.api.mailchimp.com/3.0/")
      .with(headers: { 'Authorization' => "Bearer #{access_token}" })
      .to_return(status: 200, body: account_info_response.to_json)
  end

  def stub_lists_query
    stub_request(:get, /api\.mailchimp\.com\/3\.0\/lists/)
      .to_return(status: 200, body: lists_response.to_json)
  end

  def stub_campaigns_query
    stub_request(:get, /api\.mailchimp\.com\/3\.0\/campaigns/)
      .to_return(status: 200, body: campaigns_response.to_json)
  end

  def stub_campaign_report_query(campaign_id)
    stub_request(:get, "https://us19.api.mailchimp.com/3.0/reports/#{campaign_id}")
      .to_return(status: 200, body: campaign_report_response.to_json)
  end

  def stub_list_members_query(list_id)
    stub_request(:get, /api\.mailchimp\.com\/3\.0\/lists\/#{list_id}\/members/)
      .to_return(status: 200, body: list_members_response.to_json)
  end

  def stub_automations_query
    stub_request(:get, /api\.mailchimp\.com\/3\.0\/automations/)
      .to_return(status: 200, body: automations_response.to_json)
  end
end
