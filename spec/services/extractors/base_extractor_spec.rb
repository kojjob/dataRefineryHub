require 'rails_helper'

RSpec.describe BaseExtractor, type: :service do
  let(:organization) { create(:organization) }
  let(:data_source) { create(:data_source, organization: organization, source_type: 'shopify') }

  # Create a test extractor class for testing
  let(:test_extractor_class) do
    Class.new(BaseExtractor) do
      def self.name
        'TestExtractor'
      end

      def validate_connection
        # Mock implementation
        true
      end

      def perform_extraction
        [
          { id: 1, name: 'Test Record 1', created_at: Time.current },
          { id: 2, name: 'Test Record 2', created_at: Time.current }
        ]
      end

      def determine_record_type(record)
        'test_record'
      end

      def extract_external_id(record)
        record[:id] || record['id']
      end

      class << self
        def required_fields
          %w[id name created_at]
        end

        def supported_source_type
          'test'
        end
      end
    end
  end

  let(:extractor) { test_extractor_class.new(data_source) }

  describe '#initialize' do
    it 'sets data source and logger' do
      expect(extractor.data_source).to eq(data_source)
      expect(extractor.logger).to eq(Rails.logger)
    end
  end

  describe '#extract_data' do
    it 'runs the complete extraction workflow' do
      expect(extractor).to receive(:validate_connection).and_call_original
      expect(extractor).to receive(:perform_extraction).and_call_original
      expect(extractor).to receive(:validate_data).and_call_original
      expect(extractor).to receive(:save_raw_data).and_call_original

      result = extractor.extract_data

      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
    end

    it 'creates an extraction job' do
      expect {
        extractor.extract_data
      }.to change(ExtractionJob, :count).by(1)

      job = ExtractionJob.last
      expect(job.data_source).to eq(data_source)
      expect(job.status).to eq('completed')
    end

    it 'saves raw data records' do
      expect {
        extractor.extract_data
      }.to change(RawDataRecord, :count).by(2)

      records = RawDataRecord.where(data_source: data_source)
      expect(records.count).to eq(2)
      expect(records.first.record_type).to eq('test_record')
    end

    it 'updates data source sync timestamps' do
      extractor.extract_data

      data_source.reload
      expect(data_source.last_sync_at).to be_present
      expect(data_source.next_sync_at).to be_present
      expect(data_source.status).to eq('connected')
    end

    context 'when extraction fails' do
      before do
        allow(extractor).to receive(:perform_extraction).and_raise(StandardError, 'Test error')
      end

      it 'handles errors gracefully' do
        expect {
          extractor.extract_data
        }.to raise_error(StandardError, 'Test error')

        job = ExtractionJob.last
        expect(job.status).to eq('failed')
        expect(job.error_message).to eq('Test error')
      end

      it 'updates data source status to error' do
        begin
          extractor.extract_data
        rescue StandardError
          # Expected to raise
        end

        data_source.reload
        expect(data_source.status).to eq('error')
      end

      it 'creates audit log for failure' do
        expect {
          begin
            extractor.extract_data
          rescue StandardError
            # Expected to raise
          end
        }.to change(AuditLog, :count).by(1)

        audit_log = AuditLog.last
        expect(audit_log.action).to eq('extraction_failed')
        expect(audit_log.resource_type).to eq('DataSource')
        expect(audit_log.resource_id).to eq(data_source.id)
      end
    end
  end

  describe '#test_connection' do
    it 'returns success when connection is valid' do
      result = extractor.test_connection

      expect(result[:status]).to eq(:success)
      expect(result[:message]).to eq('Connection successful')
    end

    it 'returns error when connection fails' do
      allow(extractor).to receive(:validate_connection).and_raise(BaseExtractor::ConnectionError, 'Connection failed')

      result = extractor.test_connection

      expect(result[:status]).to eq(:error)
      expect(result[:message]).to eq('Connection failed')
      expect(result[:error_type]).to eq('BaseExtractor::ConnectionError')
    end
  end

  describe '#extraction_stats' do
    let!(:completed_job) { create(:extraction_job, data_source: data_source, status: 'completed') }
    let!(:failed_job) { create(:extraction_job, data_source: data_source, status: 'failed') }

    it 'returns extraction statistics' do
      stats = extractor.extraction_stats

      expect(stats[:total_jobs]).to eq(2)
      expect(stats[:successful_jobs]).to eq(1)
      expect(stats[:failed_jobs]).to eq(1)
    end
  end

  describe '#validate_data' do
    let(:valid_records) do
      [
        { 'id' => 1, 'name' => 'Test 1', 'created_at' => Time.current.iso8601 },
        { 'id' => 2, 'name' => 'Test 2', 'created_at' => Time.current.iso8601 }
      ]
    end

    let(:invalid_records) do
      [
        { 'id' => 1, 'name' => 'Test 1' }, # Missing created_at
        { 'name' => 'Test 2', 'created_at' => Time.current.iso8601 } # Missing id
      ]
    end

    it 'validates records with required fields' do
      result = extractor.send(:validate_data, valid_records)
      expect(result.length).to eq(2)
    end

    it 'filters out invalid records' do
      result = extractor.send(:validate_data, invalid_records)
      expect(result.length).to eq(0)
    end

    it 'handles mixed valid and invalid records' do
      mixed_records = valid_records + invalid_records
      result = extractor.send(:validate_data, mixed_records)
      expect(result.length).to eq(2)
    end
  end

  describe '#save_raw_data' do
    let(:validated_data) do
      [
        { id: 1, name: 'Test 1' },
        { id: 2, name: 'Test 2' }
      ]
    end

    before do
      # Create an extraction job
      extractor.instance_variable_set(:@extraction_job, create(:extraction_job, data_source: data_source))
    end

    it 'saves raw data records' do
      expect {
        extractor.send(:save_raw_data, validated_data)
      }.to change(RawDataRecord, :count).by(2)
    end

    it 'sets correct attributes on raw data records' do
      extractor.send(:save_raw_data, validated_data)

      records = RawDataRecord.where(data_source: data_source)
      expect(records.count).to eq(2)

      record = records.first
      expect(record.record_type).to eq('test_record')
      expect(record.external_id).to eq(1)
      expect(record.extracted_at).to be_present
    end
  end

  describe 'circuit breaker' do
    let(:circuit_breaker) { extractor.instance_variable_get(:@circuit_breaker) }

    it 'opens circuit after multiple failures' do
      # Simulate multiple failures
      5.times do
        begin
          circuit_breaker.call { raise StandardError, 'Test error' }
        rescue StandardError
          # Expected
        end
      end

      # Circuit should now be open
      expect {
        circuit_breaker.call { 'test' }
      }.to raise_error(BaseExtractor::CircuitBreaker::CircuitBreakerOpenError)
    end

    it 'resets circuit on successful call' do
      # Cause some failures
      3.times do
        begin
          circuit_breaker.call { raise StandardError, 'Test error' }
        rescue StandardError
          # Expected
        end
      end

      # Successful call should reset failure count
      result = circuit_breaker.call { 'success' }
      expect(result).to eq('success')

      # Should be able to make more calls
      expect {
        circuit_breaker.call { 'another success' }
      }.not_to raise_error
    end
  end

  describe 'class methods' do
    describe '.supported_source_type' do
      it 'returns source type based on class name' do
        expect(test_extractor_class.supported_source_type).to eq('test')
      end
    end

    describe '.required_fields' do
      it 'returns required fields for validation' do
        expect(test_extractor_class.required_fields).to eq(%w[id name created_at])
      end
    end

    describe '.supports_realtime?' do
      it 'returns false by default' do
        expect(test_extractor_class.supports_realtime?).to be false
      end
    end

    describe '.supports_incremental_sync?' do
      it 'returns true by default' do
        expect(test_extractor_class.supports_incremental_sync?).to be true
      end
    end
  end
end
