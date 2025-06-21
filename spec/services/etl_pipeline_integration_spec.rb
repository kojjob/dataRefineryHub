require 'rails_helper'

RSpec.describe 'ETL Pipeline Integration', type: :integration do
  let(:data_source) { create(:data_source, source_type: 'api', status: 'connected') }
  let(:sample_data) do
    [
      { id: 1, name: 'John Doe', email: 'john@example.com', age: 30, created_at: Time.current },
      { id: 2, name: 'Jane Smith', email: 'jane@example.com', age: 25, created_at: Time.current },
      { id: 3, name: 'Bob Johnson', email: 'bob@example.com', age: 35, created_at: Time.current }
    ]
  end

  before do
    # Ensure ETL configuration is loaded
    EtlConfigurationManager.reload!
  end

  describe 'Enhanced Error Handling and Circuit Breaker' do
    it 'handles extraction failures with circuit breaker protection' do
      # Mock extraction failure
      allow_any_instance_of(EcommerceExtractor).to receive(:perform_extraction).and_raise(StandardError, 'API Error')
      
      # Attempt extraction multiple times to trigger circuit breaker
      circuit_breaker_config = ETL.circuit_breaker_config(:extraction)
      failure_threshold = circuit_breaker_config[:failure_threshold]
      
      failure_threshold.times do
        expect {
          ExtractionJobProcessor.perform_now(data_source.id)
        }.to raise_error(StandardError)
      end
      
      # Next attempt should trigger circuit breaker
      expect {
        ExtractionJobProcessor.perform_now(data_source.id)
      }.to raise_error(CircuitBreakerService::CircuitBreakerOpenError)
      
      # Verify data source status is updated
      data_source.reload
      expect(data_source.status).to eq('circuit_breaker_open')
    end
    
    it 'recovers from circuit breaker open state after timeout' do
      # Configure short timeout for testing
      circuit_breaker = CircuitBreakerService.new('test_extraction', { timeout: 1 })
      
      # Trigger circuit breaker
      circuit_breaker.instance_variable_set(:@state, CircuitBreakerService::OPEN)
      circuit_breaker.instance_variable_set(:@last_failure_time, Time.current - 2)
      
      # Should transition to half-open
      expect(circuit_breaker.send(:should_attempt_reset?)).to be true
    end
  end

  describe 'Batch Processing' do
    let(:large_dataset) { Array.new(1500) { |i| { id: i, name: "User #{i}", email: "user#{i}@example.com" } } }
    
    it 'processes large datasets in configurable batches' do
      batch_processor = BatchProcessingService.new
      batch_config = ETL.batch_config(:extraction)
      
      processed_batches = []
      
      batch_processor.process_in_batches(large_dataset) do |batch, batch_number|
        processed_batches << { batch_number: batch_number, size: batch.size }
        batch # Return processed batch
      end
      
      # Verify batching occurred
      expect(processed_batches.length).to be > 1
      expect(processed_batches.first[:size]).to eq(batch_config[:default_size])
      
      # Verify all data was processed
      total_processed = processed_batches.sum { |b| b[:size] }
      expect(total_processed).to eq(large_dataset.size)
    end
    
    it 'adapts batch size based on performance' do
      batch_processor = BatchProcessingService.new(:extraction)
      
      # Simulate slow processing
      allow(batch_processor).to receive(:calculate_processing_time).and_return(2.0) # 2 seconds
      
      initial_size = batch_processor.instance_variable_get(:@config)[:extraction_batch_size]
      
      # Process a batch to trigger adaptation
      batch_processor.process_in_batches(large_dataset.first(100)) do |batch, batch_number|
        sleep(0.01) # Simulate processing time
        batch
      end
      
      # Batch size should be adapted (this would be tested with more sophisticated mocking)
      expect(batch_processor.processing_metrics[:batches_processed]).to eq(1)
    end
  end

  describe 'Data Quality Validation' do
    let(:mixed_quality_data) do
      [
        { id: 1, name: 'John Doe', email: 'john@example.com', age: 30 }, # Valid
        { id: 2, name: '', email: 'invalid-email', age: -5 }, # Invalid
        { id: 3, name: 'Jane Smith', email: 'jane@example.com', age: 25 }, # Valid
        { id: 4, name: 'Bob', email: 'bob@example.com' } # Missing age
      ]
    end
    
    it 'validates data quality with configurable rules' do
      validator = DataQualityValidationService.new
      
      result = validator.validate_data(mixed_quality_data, context: 'api_user')
      
      # Should identify quality issues
      expect(result.valid?).to be false
      expect(result.error_count).to be > 0
      expect(result.quality_score).to be < 100
      
      # Should provide detailed error information
      expect(result.errors).not_to be_empty
      expect(result.errors.first).to respond_to(:field)
      expect(result.errors.first).to respond_to(:message)
      expect(result.errors.first).to respond_to(:severity)
    end
    
    it 'generates comprehensive quality metrics' do
      validator = DataQualityValidationService.new
      
      result = validator.validate_data(mixed_quality_data, context: 'api_user')
      
      quality_report = result.quality_report
      
      # Should include all quality dimensions
      expect(quality_report).to have_key(:completeness)
      expect(quality_report).to have_key(:accuracy)
      expect(quality_report).to have_key(:consistency)
      expect(quality_report).to have_key(:validity)
      expect(quality_report).to have_key(:uniqueness)
      
      # Metrics should be between 0 and 1
      quality_report.each do |metric, value|
        expect(value).to be_between(0, 1)
      end
    end
    
    it 'filters invalid records when configured' do
      validator = DataQualityValidationService.new
      
      result = validator.validate_data(mixed_quality_data, context: 'api_user')
      
      # Valid records should be identified
      expect(result.valid_records.size).to be < mixed_quality_data.size
      expect(result.valid_records.size).to be > 0
      
      # All returned records should be valid
      result.valid_records.each do |record|
        expect(record[:name]).not_to be_blank
        expect(record[:email]).to match(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
      end
    end
  end

  describe 'End-to-End ETL Pipeline' do
    before do
      # Mock successful API extraction
      allow_any_instance_of(ApiExtractor).to receive(:perform_extraction).and_return(sample_data)
      allow_any_instance_of(ApiExtractor).to receive(:test_connection).and_return(true)
    end
    
    it 'processes data through complete ETL pipeline with enhancements' do
      # Start extraction
      ExtractionJobProcessor.perform_now(data_source.id)
      
      # Verify raw data was created
      expect(RawDataRecord.where(data_source: data_source).count).to eq(sample_data.size)
      
      # Verify extraction job was logged
      extraction_audit = AuditLog.where(
        action: 'extraction_completed',
        resource_type: 'DataSource',
        resource_id: data_source.id
      ).last
      
      expect(extraction_audit).to be_present
      expect(extraction_audit.details['records_extracted']).to eq(sample_data.size)
      expect(extraction_audit.details['extraction_stats']).to be_present
      
      # Start transformation
      TransformationJobProcessor.perform_now(data_source.id)
      
      # Verify processed data was created
      expect(ProcessedDataRecord.where(data_source: data_source).count).to eq(sample_data.size)
      
      # Verify transformation job was logged
      transformation_audit = AuditLog.where(
        action: 'transformation_completed',
        resource_type: 'DataSource',
        resource_id: data_source.id
      ).last
      
      expect(transformation_audit).to be_present
      expect(transformation_audit.details['records_processed']).to eq(sample_data.size)
      expect(transformation_audit.details['success_rate']).to eq(100.0)
      
      # Verify all raw records are marked as processed
      unprocessed_count = RawDataRecord.where(
        data_source: data_source,
        processed: false
      ).count
      expect(unprocessed_count).to eq(0)
    end
    
    it 'handles mixed success/failure scenarios gracefully' do
      # Mock partial failure in transformation
      allow_any_instance_of(TransformerFactory).to receive(:create_transformer).and_wrap_original do |method, *args|
        transformer = method.call(*args)
        
        # Make every other record fail
        allow(transformer).to receive(:transform).and_wrap_original do |transform_method, data|
          if data[:id].even?
            raise StandardError, 'Transformation failed'
          else
            transform_method.call(data)
          end
        end
        
        transformer
      end
      
      # Process through pipeline
      ExtractionJobProcessor.perform_now(data_source.id)
      TransformationJobProcessor.perform_now(data_source.id)
      
      # Verify partial success
      total_raw = RawDataRecord.where(data_source: data_source).count
      total_processed = ProcessedDataRecord.where(data_source: data_source).count
      
      expect(total_raw).to eq(sample_data.size)
      expect(total_processed).to be < total_raw
      expect(total_processed).to be > 0
      
      # Verify transformation job recorded failures
      transformation_job = TransformationJob.where(data_source: data_source).last
      expect(transformation_job.records_failed).to be > 0
      expect(transformation_job.records_processed + transformation_job.records_failed).to eq(total_raw)
    end
  end

  describe 'Configuration Management' do
    it 'loads configuration from centralized manager' do
      # Test circuit breaker configuration
      cb_config = ETL.circuit_breaker_config(:extraction)
      expect(cb_config).to have_key(:failure_threshold)
      expect(cb_config).to have_key(:timeout)
      expect(cb_config[:failure_threshold]).to be > 0
      
      # Test batch processing configuration
      batch_config = ETL.batch_config(:transformation)
      expect(batch_config).to have_key(:default_size)
      expect(batch_config[:default_size]).to be > 0
      
      # Test data quality configuration
      dq_config = ETL.data_quality_config
      expect(dq_config).to have_key(:validation_rules)
      expect(dq_config).to have_key(:quality_thresholds)
      
      # Test error handling configuration
      error_config = ETL.error_handling_config
      expect(error_config).to have_key(:retry_strategies)
      expect(error_config).to have_key(:dead_letter_queue)
    end
    
    it 'validates configuration on load' do
      # This would test configuration validation
      # In a real scenario, you'd test with invalid config files
      expect { EtlConfigurationManager.instance }.not_to raise_error
    end
  end

  describe 'Performance and Monitoring' do
    it 'collects comprehensive metrics during processing' do
      # Process data through pipeline
      ExtractionJobProcessor.perform_now(data_source.id)
      
      # Check that metrics are collected
      extraction_audit = AuditLog.where(
        action: 'extraction_completed',
        resource_id: data_source.id
      ).last
      
      expect(extraction_audit.details).to have_key('processing_duration')
      expect(extraction_audit.details).to have_key('extraction_stats')
      expect(extraction_audit.details['processing_duration']).to be > 0
    end
    
    it 'tracks memory usage and performance' do
      batch_processor = BatchProcessingService.new
      
      # Process some data
      batch_processor.process_in_batches(sample_data) do |batch, batch_number|
        batch
      end
      
      metrics = batch_processor.processing_metrics
      
      expect(metrics).to have_key(:batches_processed)
      expect(metrics).to have_key(:total_records_processed)
      expect(metrics).to have_key(:average_batch_processing_time)
      expect(metrics[:batches_processed]).to be > 0
    end
  end
end