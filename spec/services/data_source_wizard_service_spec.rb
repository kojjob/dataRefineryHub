require 'rails_helper'

RSpec.describe DataSourceWizardService do
  let(:service) { described_class.new }

  describe '#prepare_wizard_data' do
    subject(:wizard_data) { service.prepare_wizard_data }

    it 'returns a hash with all required keys' do
      expect(wizard_data).to be_a(Hash)
      expect(wizard_data.keys).to match_array([
        :wizard_data,
        :configurations,
        :sync_frequencies,
        :file_config
      ])
    end

    it 'includes wizard metadata' do
      expect(wizard_data[:wizard_data]).to be_present
      expect(wizard_data[:wizard_data][:steps]).to be_an(Array)
      expect(wizard_data[:wizard_data][:steps].size).to eq(4)
    end

    it 'includes data source configurations' do
      expect(wizard_data[:configurations]).to be_a(Hash)
      expect(wizard_data[:configurations]).to include(:postgresql, :mysql, :salesforce, :hubspot)
    end

    it 'includes sync frequency options' do
      expect(wizard_data[:sync_frequencies]).to be_an(Array)
      expect(wizard_data[:sync_frequencies].size).to be >= 4
    end

    it 'includes file upload configuration' do
      expect(wizard_data[:file_config]).to be_a(Hash)
      expect(wizard_data[:file_config]).to include(
        :max_file_size,
        :allowed_types,
        :max_files
      )
    end
  end

  describe 'wizard metadata' do
    subject(:wizard_metadata) { service.prepare_wizard_data[:wizard_data] }

    it 'defines 4 wizard steps' do
      expect(wizard_metadata[:steps].size).to eq(4)
    end

    it 'includes step details' do
      first_step = wizard_metadata[:steps].first
      expect(first_step).to include(
        :id,
        :name,
        :description,
        :icon,
        :required
      )
    end

    it 'marks platform selection as required' do
      first_step = wizard_metadata[:steps].first
      expect(first_step[:required]).to be true
    end

    it 'marks configuration as required' do
      second_step = wizard_metadata[:steps][1]
      expect(second_step[:required]).to be true
    end

    it 'marks preview as optional' do
      third_step = wizard_metadata[:steps][2]
      expect(third_step[:required]).to be false
    end

    it 'includes auto-save configuration' do
      expect(wizard_metadata[:auto_save_enabled]).to be true
      expect(wizard_metadata[:auto_save_interval]).to eq(30000)
    end
  end

  describe 'data source configurations' do
    subject(:configurations) { service.prepare_wizard_data[:configurations] }

    describe 'database platforms' do
      it 'includes PostgreSQL configuration' do
        postgres = configurations[:postgresql]
        expect(postgres[:name]).to eq("PostgreSQL")
        expect(postgres[:category]).to eq("Database")
        expect(postgres[:status]).to eq("production_ready")
      end

      it 'includes MySQL configuration' do
        mysql = configurations[:mysql]
        expect(mysql[:name]).to eq("MySQL")
        expect(mysql[:category]).to eq("Database")
        expect(mysql[:status]).to eq("production_ready")
      end

      it 'defines connection fields for PostgreSQL' do
        postgres = configurations[:postgresql]
        expect(postgres[:connection_fields]).to be_an(Array)

        field_names = postgres[:connection_fields].map { |f| f[:name] }
        expect(field_names).to include('host', 'port', 'database', 'username', 'password')
      end

      it 'includes default values for connection fields' do
        postgres = configurations[:postgresql]
        port_field = postgres[:connection_fields].find { |f| f[:name] == 'port' }

        expect(port_field[:default]).to eq(5432)
        expect(port_field[:type]).to eq('number')
      end

      it 'marks required fields appropriately' do
        postgres = configurations[:postgresql]
        required_fields = postgres[:connection_fields].select { |f| f[:required] }

        expect(required_fields.size).to be >= 4
        expect(required_fields.map { |f| f[:name] }).to include('host', 'database', 'username', 'password')
      end
    end

    describe 'CRM platforms' do
      it 'includes Salesforce configuration' do
        salesforce = configurations[:salesforce]
        expect(salesforce[:name]).to eq("Salesforce")
        expect(salesforce[:category]).to eq("CRM")
        expect(salesforce[:status]).to eq("production_ready")
      end

      it 'includes HubSpot configuration' do
        hubspot = configurations[:hubspot]
        expect(hubspot[:name]).to eq("HubSpot")
        expect(hubspot[:category]).to eq("CRM")
        expect(hubspot[:status]).to eq("production_ready")
      end

      it 'defines API-based connection fields for CRM platforms' do
        salesforce = configurations[:salesforce]
        field_names = salesforce[:connection_fields].map { |f| f[:name] }

        expect(field_names).to include('instance_url', 'username', 'password', 'security_token')
      end
    end

    describe 'file upload platform' do
      it 'includes CSV upload configuration' do
        csv = configurations[:csv_upload]
        expect(csv[:name]).to eq("CSV Upload")
        expect(csv[:category]).to eq("File")
        expect(csv[:status]).to eq("production_ready")
      end

      it 'has manual sync type for file uploads' do
        csv = configurations[:csv_upload]
        expect(csv[:sync_type]).to eq("manual")
      end

      it 'has no connection fields for file uploads' do
        csv = configurations[:csv_upload]
        expect(csv[:connection_fields]).to eq([])
      end
    end

    describe 'coming soon platforms' do
      it 'includes Snowflake as coming soon' do
        snowflake = configurations[:snowflake]
        expect(snowflake[:status]).to eq("coming_soon")
        expect(snowflake[:estimated_release]).to be_present
      end

      it 'includes BigQuery as coming soon' do
        bigquery = configurations[:bigquery]
        expect(bigquery[:status]).to eq("coming_soon")
        expect(bigquery[:estimated_release]).to be_present
      end

      it 'includes Stripe as coming soon' do
        stripe = configurations[:stripe]
        expect(stripe[:status]).to eq("coming_soon")
        expect(stripe[:estimated_release]).to be_present
      end
    end

    describe 'platform features' do
      it 'lists features for each platform' do
        configurations.each do |key, config|
          expect(config[:features]).to be_an(Array) if config[:features]
          expect(config[:features].size).to be >= 3 if config[:status] == "production_ready"
        end
      end

      it 'categorizes sync types correctly' do
        real_time_platforms = configurations.select { |_, config| config[:sync_type] == "real_time" }
        scheduled_platforms = configurations.select { |_, config| config[:sync_type] == "scheduled" }
        manual_platforms = configurations.select { |_, config| config[:sync_type] == "manual" }

        expect(real_time_platforms).not_to be_empty
        expect(scheduled_platforms).not_to be_empty
        expect(manual_platforms).not_to be_empty
      end
    end
  end

  describe 'sync frequency options' do
    subject(:frequencies) { service.prepare_wizard_data[:sync_frequencies] }

    it 'includes at least 6 frequency options' do
      expect(frequencies.size).to be >= 6
    end

    it 'includes real-time sync option' do
      real_time = frequencies.find { |f| f[:value] == "real_time" }
      expect(real_time).to be_present
      expect(real_time[:label]).to eq("Real-time")
      expect(real_time[:recommended_for]).to be_an(Array)
    end

    it 'includes hourly sync option' do
      hourly = frequencies.find { |f| f[:value] == "hourly" }
      expect(hourly).to be_present
      expect(hourly[:label]).to eq("Hourly")
    end

    it 'includes daily sync option' do
      daily = frequencies.find { |f| f[:value] == "daily" }
      expect(daily).to be_present
      expect(daily[:label]).to eq("Daily")
    end

    it 'includes weekly sync option' do
      weekly = frequencies.find { |f| f[:value] == "weekly" }
      expect(weekly).to be_present
      expect(weekly[:label]).to eq("Weekly")
    end

    it 'includes manual sync option' do
      manual = frequencies.find { |f| f[:value] == "manual" }
      expect(manual).to be_present
      expect(manual[:label]).to eq("Manual")
    end

    it 'includes recommendations for each frequency' do
      frequencies.each do |freq|
        expect(freq[:recommended_for]).to be_an(Array)
        expect(freq[:recommended_for]).not_to be_empty
      end
    end

    it 'includes icons for each frequency' do
      frequencies.each do |freq|
        expect(freq[:icon]).to be_present
      end
    end

    it 'includes descriptions for each frequency' do
      frequencies.each do |freq|
        expect(freq[:description]).to be_present
        expect(freq[:description].length).to be > 10
      end
    end
  end

  describe 'file upload configuration' do
    subject(:file_config) { service.prepare_wizard_data[:file_config] }

    it 'defines maximum file size' do
      expect(file_config[:max_file_size]).to eq(100.megabytes)
    end

    it 'defines allowed file types' do
      expect(file_config[:allowed_types]).to be_an(Array)
      expect(file_config[:allowed_types]).to include('.csv', '.xlsx', '.json', '.parquet')
    end

    it 'defines maximum number of files' do
      expect(file_config[:max_files]).to eq(10)
    end

    it 'defines chunk size for uploads' do
      expect(file_config[:chunk_size]).to eq(1.megabyte)
    end

    it 'defines preview row count' do
      expect(file_config[:preview_rows]).to eq(100)
    end

    it 'includes supported encodings' do
      expect(file_config[:supported_encodings]).to include("UTF-8", "ISO-8859-1", "Windows-1252")
    end

    it 'includes delimiter options for CSV' do
      expect(file_config[:delimiter_options]).to include(",", ";", '\t', "|")
    end

    it 'includes quote character options' do
      expect(file_config[:quote_options]).to include('"', "'", "None")
    end
  end

  describe 'configuration consistency' do
    subject(:configurations) { service.prepare_wizard_data[:configurations] }

    it 'ensures all production-ready platforms have complete configurations' do
      production_platforms = configurations.select { |_, config| config[:status] == "production_ready" }

      production_platforms.each do |key, config|
        expect(config[:name]).to be_present
        expect(config[:category]).to be_present
        expect(config[:description]).to be_present
        expect(config[:sync_type]).to be_present
        expect(config[:features]).to be_an(Array)
      end
    end

    it 'ensures connection fields have proper structure' do
      configurations.each do |key, config|
        next if config[:connection_fields].nil? || config[:connection_fields].empty?

        config[:connection_fields].each do |field|
          expect(field[:name]).to be_present
          expect(field[:type]).to be_present
          expect([ true, false ]).to include(field[:required])
          expect(field[:placeholder]).to be_present if field[:required]
        end
      end
    end

    it 'ensures no duplicate platform keys' do
      keys = configurations.keys
      expect(keys.size).to eq(keys.uniq.size)
    end

    it 'ensures consistent icon definitions' do
      configurations.each do |key, config|
        expect(config[:icon]).to be_present
      end
    end
  end

  describe 'performance' do
    it 'generates wizard data quickly' do
      # Simple performance check - should complete in reasonable time
      start_time = Time.now
      10.times { service.prepare_wizard_data }
      elapsed = Time.now - start_time

      expect(elapsed).to be < 1.0 # Should complete 10 calls in under 1 second
    end

    it 'returns the same data structure on multiple calls' do
      data1 = service.prepare_wizard_data
      data2 = service.prepare_wizard_data

      expect(data1.keys).to eq(data2.keys)
      expect(data1[:configurations].keys).to eq(data2[:configurations].keys)
    end
  end
end
