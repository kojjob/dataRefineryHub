require 'rails_helper'

RSpec.describe ExtractorFactory, type: :service do
  let(:organization) { create(:organization) }
  let(:shopify_data_source) { create(:data_source, organization: organization, source_type: 'shopify') }

  describe '.create_extractor' do
    context 'when source type is supported' do
      it 'creates ConcreteEcommerceExtractor for shopify source' do
        extractor = ExtractorFactory.create_extractor(shopify_data_source)
        expect(extractor).to be_a(ConcreteEcommerceExtractor)
        expect(extractor.data_source).to eq(shopify_data_source)
        expect(extractor.adapter).to be_a(ShopifyAdapter)
      end
    end

    context 'when source type is not supported' do
      it 'raises UnsupportedSourceTypeError' do
        # Create a test double for unsupported data source
        unknown_source = double('DataSource', source_type: 'unknown')
        
        expect {
          ExtractorFactory.create_extractor(unknown_source)
        }.to raise_error(ExtractorFactory::UnsupportedSourceTypeError)
      end
    end

    context 'when extractor class is not implemented' do
      let(:quickbooks_data_source) { create(:data_source, organization: organization, source_type: 'quickbooks') }

      it 'creates a placeholder extractor' do
        extractor = ExtractorFactory.create_extractor(quickbooks_data_source)
        expect(extractor).to be_a(BaseExtractor)
        expect(extractor.data_source).to eq(quickbooks_data_source)
      end

      it 'placeholder extractor raises NotImplementedError on connection' do
        extractor = ExtractorFactory.create_extractor(quickbooks_data_source)
        expect {
          extractor.test_connection
        }.to raise_error(NotImplementedError, /QuickbooksExtractor extractor not yet implemented/)
      end
    end
  end

  describe '.supported_source_types' do
    it 'returns all supported source types' do
      types = ExtractorFactory.supported_source_types
      expect(types).to include('shopify', 'quickbooks', 'google_analytics', 'stripe', 'mailchimp')
      expect(types).to include('zendesk', 'hubspot', 'google_ads', 'facebook_ads')
      expect(types).to include('salesforce', 'amazon_seller_central', 'custom_api')
    end
  end

  describe '.supported_source_type?' do
    it 'returns true for supported types' do
      expect(ExtractorFactory.supported_source_type?('shopify')).to be true
      expect(ExtractorFactory.supported_source_type?('stripe')).to be true
    end

    it 'returns false for unsupported types' do
      expect(ExtractorFactory.supported_source_type?('unknown')).to be false
      expect(ExtractorFactory.supported_source_type?('invalid')).to be false
    end

    it 'handles symbol input' do
      expect(ExtractorFactory.supported_source_type?(:shopify)).to be true
      expect(ExtractorFactory.supported_source_type?(:unknown)).to be false
    end
  end

  describe '.get_extractor_class' do
    it 'returns ShopifyExtractor class for shopify' do
      klass = ExtractorFactory.get_extractor_class('shopify')
      expect(klass).to eq(ShopifyExtractor)
    end

    it 'returns placeholder class for unimplemented extractors' do
      klass = ExtractorFactory.get_extractor_class('quickbooks')
      expect(klass).to be_a(Class)
      expect(klass.ancestors).to include(BaseExtractor)
    end

    it 'returns nil for unsupported types' do
      klass = ExtractorFactory.get_extractor_class('unknown')
      expect(klass).to be_nil
    end
  end

  describe '.extractors_by_status' do
    it 'separates implemented and planned extractors' do
      status = ExtractorFactory.extractors_by_status
      
      expect(status[:implemented]).to include('shopify')
      expect(status[:planned]).to include('quickbooks', 'google_analytics', 'stripe')
    end
  end

  describe '.extractor_metadata' do
    it 'returns metadata for all extractors' do
      metadata = ExtractorFactory.extractor_metadata
      
      # Check implemented extractor (Shopify)
      shopify_meta = metadata['shopify']
      expect(shopify_meta[:implemented]).to be true
      expect(shopify_meta[:supports_realtime]).to be true
      expect(shopify_meta[:rate_limit_per_hour]).to eq(2000)

      # Check planned extractor (QuickBooks)
      qb_meta = metadata['quickbooks']
      expect(qb_meta[:implemented]).to be false
      expect(qb_meta[:supports_realtime]).to be false
      expect(qb_meta[:rate_limit_per_hour]).to eq(0)
    end
  end

  describe '.priority_integrations' do
    it 'returns MVP priority integrations' do
      priorities = ExtractorFactory.priority_integrations
      expect(priorities).to eq(%w[shopify quickbooks google_analytics stripe mailchimp])
    end
  end

  describe '.growth_integrations' do
    it 'returns growth phase integrations' do
      growth = ExtractorFactory.growth_integrations
      expect(growth).to eq(%w[zendesk hubspot google_ads facebook_ads woocommerce amazon_seller_central])
    end
  end

  describe '.enterprise_integrations' do
    it 'returns enterprise integrations' do
      enterprise = ExtractorFactory.enterprise_integrations
      expect(enterprise).to eq(%w[salesforce custom_api])
    end
  end

  describe '.test_connection' do
    context 'with valid data source' do
      before do
        # Mock the Shopify API connection
        allow_any_instance_of(ShopifyExtractor).to receive(:validate_connection).and_return(true)
      end

      it 'returns success result' do
        result = ExtractorFactory.test_connection(shopify_data_source)
        expect(result[:status]).to eq(:success)
      end
    end

    context 'with connection error' do
      before do
        allow_any_instance_of(ShopifyExtractor).to receive(:validate_connection)
          .and_raise(BaseExtractor::ConnectionError, 'Connection failed')
      end

      it 'returns error result' do
        result = ExtractorFactory.test_connection(shopify_data_source)
        expect(result[:status]).to eq(:error)
        expect(result[:message]).to eq('Connection failed')
        expect(result[:error_type]).to eq('BaseExtractor::ConnectionError')
      end
    end

    context 'with unsupported source type' do
      it 'returns error result' do
        # Create a test double for unsupported data source
        unknown_source = double('DataSource', source_type: 'unknown')
        
        result = ExtractorFactory.test_connection(unknown_source)
        expect(result[:status]).to eq(:error)
        expect(result[:error_type]).to eq('UnsupportedSourceType')
      end
    end
  end

  describe '.extract_data' do
    context 'with valid data source' do
      before do
        # Mock the extraction process
        allow_any_instance_of(ShopifyExtractor).to receive(:extract_data).and_return([{ id: 1, name: 'test' }])
      end

      it 'calls extractor extract_data method' do
        result = ExtractorFactory.extract_data(shopify_data_source, job_id: 123)
        expect(result).to eq([{ id: 1, name: 'test' }])
      end
    end

    context 'with unsupported source type' do
      it 'raises UnsupportedSourceTypeError' do
        # Create a test double for unsupported data source
        unknown_source = double('DataSource', source_type: 'unknown')
        
        expect {
          ExtractorFactory.extract_data(unknown_source)
        }.to raise_error(ExtractorFactory::UnsupportedSourceTypeError)
      end
    end
  end

  describe '.extraction_stats' do
    let!(:completed_job) { create(:extraction_job, data_source: shopify_data_source, status: 'completed') }
    let!(:failed_job) { create(:extraction_job, data_source: shopify_data_source, status: 'failed') }

    it 'returns extraction statistics' do
      stats = ExtractorFactory.extraction_stats(shopify_data_source)
      
      expect(stats[:total_jobs]).to eq(2)
      expect(stats[:successful_jobs]).to eq(1)
      expect(stats[:failed_jobs]).to eq(1)
    end

    context 'with unsupported source type' do
      it 'returns error stats' do
        # Create a test double for unsupported data source
        unknown_source = double('DataSource', source_type: 'unknown')
        
        stats = ExtractorFactory.extraction_stats(unknown_source)
        
        expect(stats[:total_jobs]).to eq(0)
        expect(stats[:successful_jobs]).to eq(0)
        expect(stats[:failed_jobs]).to eq(0)
        expect(stats[:error]).to be_present
      end
    end
  end
end