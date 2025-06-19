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
