require 'rails_helper'

RSpec.describe DataSource, type: :model do
  subject { build(:data_source) }

  describe 'associations' do
    it { should belong_to(:organization) }
    it { should have_many(:extraction_jobs).dependent(:destroy) }
    it { should have_many(:raw_data_records).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_least(2).is_at_most(100) }
    it { should validate_inclusion_of(:source_type).in_array(DataSource::SOURCE_TYPES) }
    it { should validate_inclusion_of(:status).in_array(DataSource::STATUSES) }
    it { should validate_inclusion_of(:sync_frequency).in_array(DataSource::SYNC_FREQUENCIES) }
    it { should validate_uniqueness_of(:name).scoped_to(:organization_id) }
  end

  describe 'scopes' do
    let!(:connected_source) { create(:data_source, :connected) }
    let!(:syncing_source) { create(:data_source, :syncing) }
    let!(:shopify_source) { create(:data_source, :shopify) }
    let!(:stripe_source) { create(:data_source, :stripe) }
    let!(:needs_sync_source) { create(:data_source, next_sync_at: 1.hour.ago) }

    it 'filters connected data sources' do
      expect(DataSource.connected).to include(connected_source)
      expect(DataSource.connected).not_to include(syncing_source)
    end

    it 'filters by source type' do
      expect(DataSource.by_type('shopify')).to include(shopify_source)
      expect(DataSource.by_type('shopify')).not_to include(stripe_source)
    end

    it 'finds sources that need sync' do
      expect(DataSource.needs_sync).to include(needs_sync_source)
    end

    it 'identifies priority 1 integrations' do
      priority_sources = DataSource.priority_1
      expect(priority_sources).to include(shopify_source, stripe_source)
    end
  end

  describe 'status predicate methods' do
    it 'correctly identifies connected status' do
      source = build(:data_source, status: 'connected')
      expect(source).to be_connected
      expect(source).not_to be_syncing
    end

    it 'correctly identifies syncing status' do
      source = build(:data_source, status: 'syncing')
      expect(source).to be_syncing
      expect(source).not_to be_connected
    end

    it 'correctly identifies error status' do
      source = build(:data_source, status: 'error')
      expect(source).to be_error
      expect(source).not_to be_connected
    end

    it 'correctly identifies disconnected status' do
      source = build(:data_source, status: 'disconnected')
      expect(source).to be_disconnected
      expect(source).not_to be_connected
    end
  end

  describe '#needs_sync?' do
    it 'returns false for disconnected sources' do
      source = build(:data_source, status: 'disconnected')
      expect(source.needs_sync?).to be false
    end

    it 'returns true for connected sources with past next_sync_at' do
      source = build(:data_source, status: 'connected', next_sync_at: 1.hour.ago)
      expect(source.needs_sync?).to be true
    end

    it 'returns false for connected sources with future next_sync_at' do
      source = build(:data_source, status: 'connected', next_sync_at: 1.hour.from_now)
      expect(source.needs_sync?).to be false
    end

    it 'returns true for connected sources with nil next_sync_at' do
      source = build(:data_source, status: 'connected', next_sync_at: nil)
      expect(source.needs_sync?).to be true
    end
  end

  describe '#priority_integration?' do
    it 'returns true for priority 1 integrations' do
      %w[shopify quickbooks google_analytics stripe mailchimp].each do |type|
        source = build(:data_source, source_type: type)
        expect(source.priority_integration?).to be true
      end
    end

    it 'returns false for non-priority integrations' do
      source = build(:data_source, source_type: 'custom_api')
      expect(source.priority_integration?).to be false
    end
  end

  describe 'sync capabilities' do
    describe '#can_connect?' do
      it 'returns true for disconnected sources' do
        source = build(:data_source, status: 'disconnected')
        expect(source.can_connect?).to be true
      end

      it 'returns true for error sources' do
        source = build(:data_source, status: 'error')
        expect(source.can_connect?).to be true
      end

      it 'returns false for connected sources' do
        source = build(:data_source, status: 'connected')
        expect(source.can_connect?).to be false
      end
    end

    describe '#can_sync?' do
      it 'returns true for connected, non-syncing sources' do
        source = build(:data_source, status: 'connected')
        expect(source.can_sync?).to be true
      end

      it 'returns false for syncing sources' do
        source = build(:data_source, status: 'syncing')
        expect(source.can_sync?).to be false
      end

      it 'returns false for disconnected sources' do
        source = build(:data_source, status: 'disconnected')
        expect(source.can_sync?).to be false
      end
    end
  end

  describe 'sync interval calculations' do
    describe '#sync_interval' do
      it 'returns correct intervals for each frequency' do
        expect(build(:data_source, sync_frequency: 'realtime').sync_interval).to eq(5.minutes)
        expect(build(:data_source, sync_frequency: 'hourly').sync_interval).to eq(1.hour)
        expect(build(:data_source, sync_frequency: 'daily').sync_interval).to eq(1.day)
        expect(build(:data_source, sync_frequency: 'weekly').sync_interval).to eq(1.week)
        expect(build(:data_source, sync_frequency: 'monthly').sync_interval).to eq(1.month)
      end
    end

    describe '#calculate_next_sync' do
      it 'returns nil for non-connected sources' do
        source = build(:data_source, status: 'disconnected')
        expect(source.calculate_next_sync).to be_nil
      end

      it 'calculates next sync based on last sync time' do
        source = build(:data_source, status: 'connected', sync_frequency: 'daily', last_sync_at: 2.hours.ago)
        expected_time = 2.hours.ago + 1.day
        expect(source.calculate_next_sync).to be_within(1.second).of(expected_time)
      end

      it 'uses current time if no last sync' do
        source = build(:data_source, status: 'connected', sync_frequency: 'hourly', last_sync_at: nil)
        expected_time = Time.current + 1.hour
        expect(source.calculate_next_sync).to be_within(1.second).of(expected_time)
      end
    end
  end

  describe 'sync status management' do
    let(:data_source) { create(:data_source, status: 'connected') }

    describe '#mark_syncing!' do
      it 'updates status to syncing and clears error message' do
        data_source.error_message = 'Previous error'
        data_source.mark_syncing!

        expect(data_source.reload).to be_syncing
        expect(data_source.error_message).to be_nil
      end
    end

    describe '#mark_sync_completed!' do
      it 'updates status and sync timestamps' do
        freeze_time do
          data_source.mark_sync_completed!

          data_source.reload
          expect(data_source).to be_connected
          expect(data_source.last_sync_at).to be_within(1.second).of(Time.current)
          expect(data_source.next_sync_at).to be_within(1.second).of(Time.current + 1.day)
          expect(data_source.error_message).to be_nil
        end
      end
    end

    describe '#mark_sync_failed!' do
      it 'updates status to error with message' do
        error_message = 'Connection timeout'
        data_source.mark_sync_failed!(error_message)

        data_source.reload
        expect(data_source).to be_error
        expect(data_source.error_message).to eq(error_message)
        expect(data_source.next_sync_at).not_to be_nil
      end

      it 'handles exception objects' do
        error = StandardError.new('API rate limit exceeded')
        data_source.mark_sync_failed!(error)

        expect(data_source.reload.error_message).to eq('API rate limit exceeded')
      end
    end
  end

  describe 'file upload functionality' do
    describe '#file_upload_source?' do
      it 'returns true for file_upload source type' do
        source = build(:data_source, source_type: 'file_upload')
        expect(source.file_upload_source?).to be true
      end

      it 'returns false for other source types' do
        source = build(:data_source, source_type: 'shopify')
        expect(source.file_upload_source?).to be false
      end
    end

    describe '#supported_file_types' do
      it 'returns array of supported MIME types' do
        source = build(:data_source)
        expect(source.supported_file_types).to include('text/csv', 'application/json')
      end
    end

    describe '#file_type_display_names' do
      it 'returns human-readable file type names' do
        source = build(:data_source)
        display_names = source.file_type_display_names
        expect(display_names['text/csv']).to eq('CSV')
        expect(display_names['application/json']).to eq('JSON')
      end
    end
  end

  describe 'extractor integration' do
    let(:data_source) { create(:data_source, source_type: 'shopify') }

    describe '#extractor_supported?' do
      it 'delegates to ExtractorFactory' do
        expect(ExtractorFactory).to receive(:supported_source_type?).with('shopify').and_return(true)
        expect(data_source.extractor_supported?).to be true
      end
    end

    describe '#sync_now!' do
      context 'when can sync' do
        before { allow(data_source).to receive(:can_sync?).and_return(true) }

        it 'enqueues extraction job' do
          expect(ExtractionJobProcessor).to receive(:perform_later).with(data_source.id)
          expect(data_source.sync_now!).to be true
        end
      end

      context 'when cannot sync' do
        before { allow(data_source).to receive(:can_sync?).and_return(false) }

        it 'returns false without enqueuing job' do
          expect(ExtractionJobProcessor).not_to receive(:perform_later)
          expect(data_source.sync_now!).to be false
        end
      end
    end
  end

  describe 'configuration handling' do
    let(:data_source) { create(:data_source) }

    describe '#configuration' do
      it 'returns empty hash when config is nil' do
        data_source.config = nil
        expect(data_source.configuration).to eq({})
      end

      it 'returns config when present' do
        config = { 'api_key' => 'test123' }
        data_source.config = config
        expect(data_source.configuration).to eq(config)
      end
    end

    describe '#configuration=' do
      it 'accepts hash configuration' do
        config = { 'api_key' => 'test123' }
        data_source.configuration = config
        expect(data_source.config).to eq(config)
      end

      it 'parses JSON string configuration' do
        config_json = '{"api_key":"test123"}'
        data_source.configuration = config_json
        expect(data_source.config).to eq({ 'api_key' => 'test123' })
      end
    end
  end

  describe 'callbacks and validations' do
    describe 'before_validation callbacks' do
      it 'normalizes name by stripping whitespace' do
        source = build(:data_source, name: '  My Source  ')
        source.valid?
        expect(source.name).to eq('My Source')
      end

      it 'sets default values on create' do
        source = DataSource.new(name: 'Test', source_type: 'shopify', organization: create(:organization))
        source.valid?
        expect(source.status).to eq('disconnected')
        expect(source.sync_frequency).to eq('daily')
      end
    end

    describe 'encryption' do
      it 'encrypts credentials field' do
        source = create(:data_source)
        source.credentials = 'secret_api_key'
        source.save!
        
        # Credentials should be encrypted in database
        raw_value = DataSource.connection.select_value(
          "SELECT credentials FROM data_sources WHERE id = #{source.id}"
        )
        expect(raw_value).not_to eq('secret_api_key')
        expect(raw_value).to be_present
        
        # But should be decrypted when accessed
        expect(source.reload.credentials).to eq('secret_api_key')
      end
    end
      end
    end

    describe '#mark_sync_failed!' do
      it 'updates status to error and records error message' do
        error = StandardError.new('Sync failed')
        data_source.mark_sync_failed!(error)

        data_source.reload
        expect(data_source).to be_error
        expect(data_source.error_message).to eq('Sync failed')
        expect(data_source.next_sync_at).to be_present
      end
    end
  end

  describe '#source_display_name' do
    it 'returns formatted names for special cases' do
      expect(build(:data_source, source_type: 'google_analytics').source_display_name).to eq('Google Analytics')
      expect(build(:data_source, source_type: 'facebook_ads').source_display_name).to eq('Facebook Ads')
      expect(build(:data_source, source_type: 'custom_api').source_display_name).to eq('Custom API')
    end

    it 'returns humanized name for standard cases' do
      expect(build(:data_source, source_type: 'shopify').source_display_name).to eq('Shopify')
      expect(build(:data_source, source_type: 'stripe').source_display_name).to eq('Stripe')
    end
  end

  describe 'callbacks' do
    describe 'on create' do
      it 'sets default status to disconnected' do
        source = DataSource.create!(organization: create(:organization), name: 'Test Source', source_type: 'shopify')
        expect(source.status).to eq('disconnected')
      end

      it 'sets default sync frequency to daily' do
        source = DataSource.create!(organization: create(:organization), name: 'Test Source', source_type: 'shopify')
        expect(source.sync_frequency).to eq('daily')
      end

      it 'initializes config as empty hash' do
        source = DataSource.create!(organization: create(:organization), name: 'Test Source', source_type: 'shopify')
        expect(source.config).to eq({})
      end
    end

    describe 'name normalization' do
      it 'strips whitespace from name' do
        source = create(:data_source, name: '  Test Source  ')
        expect(source.name).to eq('Test Source')
      end
    end
  end

  describe 'encryption' do
    it 'encrypts credentials' do
      source = create(:data_source, credentials: { api_key: 'secret_key' })

      # Check that credentials are encrypted in the database
      raw_credentials = source.class.connection.select_value(
        "SELECT credentials FROM data_sources WHERE id = #{source.id}"
      )
      expect(raw_credentials).not_to include('secret_key')

      # Check that credentials can be decrypted
      expect(source.reload.credentials['api_key']).to eq('secret_key')
    end
  end
end
