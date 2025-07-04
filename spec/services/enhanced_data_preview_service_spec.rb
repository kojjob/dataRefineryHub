require 'rails_helper'

RSpec.describe EnhancedDataPreviewService, type: :service do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }
  let(:data_source) { create(:data_source, organization: organization) }

  describe 'business field detection' do
    subject { described_class.new(data_source: data_source, user: user) }

    describe '#detect_field_business_context' do
      it 'detects customer fields correctly' do
        customer_fields = ['customer_name', 'email', 'customer_id', 'phone', 'contact', 'user_name', 'client_email']
        
        customer_fields.each do |field|
          context = subject.send(:detect_field_business_context, field)
          expect(context[:category]).to eq(:customer), "Expected #{field} to be detected as customer field, got #{context[:category]}"
          expect(context[:confidence]).to be > 0.3
        end
      end
      
      it 'detects financial fields correctly' do
        financial_fields = ['price', 'total', 'cost', 'revenue', 'amount', 'payment', 'value', 'billing']
        
        financial_fields.each do |field|
          context = subject.send(:detect_field_business_context, field)
          expect(context[:category]).to eq(:financial)
          expect(context[:confidence]).to be > 0.3
        end
      end
      
      it 'detects temporal fields correctly' do
        temporal_fields = ['order_date', 'created_at', 'timestamp', 'when_created', 'time_stamp', 'updated_at']
        
        temporal_fields.each do |field|
          context = subject.send(:detect_field_business_context, field)
          expect(context[:category]).to eq(:temporal), "Expected #{field} to be detected as temporal field, got #{context[:category]}"
          expect(context[:confidence]).to be > 0.3
        end
      end
      
      it 'detects location fields correctly' do
        location_fields = ['customer_address', 'city', 'state', 'country', 'zip_code', 'location', 'region']
        
        location_fields.each do |field|
          context = subject.send(:detect_field_business_context, field)
          expect(context[:category]).to eq(:location), "Expected #{field} to be detected as location field, got #{context[:category]}"
          expect(context[:confidence]).to be > 0.3
        end
      end

      it 'detects product fields correctly' do
        product_fields = ['product', 'item', 'sku', 'inventory', 'stock', 'category']
        
        product_fields.each do |field|
          context = subject.send(:detect_field_business_context, field)
          expect(context[:category]).to eq(:product)
          expect(context[:confidence]).to be > 0.3
        end
      end

      it 'detects order fields correctly' do
        order_fields = ['order', 'transaction', 'purchase', 'sale', 'checkout', 'cart']
        
        order_fields.each do |field|
          context = subject.send(:detect_field_business_context, field)
          expect(context[:category]).to eq(:order)
          expect(context[:confidence]).to be > 0.3
        end
      end

      it 'detects marketing fields correctly' do
        marketing_fields = ['campaign', 'source', 'medium', 'utm', 'referrer', 'channel']
        
        marketing_fields.each do |field|
          context = subject.send(:detect_field_business_context, field)
          expect(context[:category]).to eq(:marketing)
          expect(context[:confidence]).to be > 0.3
        end
      end

      it 'returns nil category for unrecognized fields' do
        unrecognized_fields = ['xyz', 'random_field', 'unknown']
        
        unrecognized_fields.each do |field|
          context = subject.send(:detect_field_business_context, field)
          expect(context[:category]).to be_nil
          expect(context[:confidence]).to eq(0)
        end
      end
    end

    describe '#detect_business_fields' do
      it 'returns array of detected business fields' do
        headers = ['customer_name', 'email', 'order_total', 'order_date', 'product_name', 'city']
        
        detected_fields = subject.send(:detect_business_fields, headers)
        
        expect(detected_fields).to be_an(Array)
        expect(detected_fields.length).to eq(6)
        
        categories = detected_fields.map { |f| f[:category] }
        expect(categories).to include(:customer, :financial, :temporal, :product, :location)
      end

      it 'handles empty headers gracefully' do
        detected_fields = subject.send(:detect_business_fields, [])
        expect(detected_fields).to eq([])
      end

      it 'handles nil headers gracefully' do
        detected_fields = subject.send(:detect_business_fields, nil)
        expect(detected_fields).to eq([])
      end
    end
  end

  describe 'data quality assessment' do
    subject { described_class.new(data_source: data_source, user: user) }

    let(:sample_data) do
      [
        { 'name' => 'John Doe', 'email' => 'john@example.com', 'amount' => '99.99' },
        { 'name' => 'Jane Smith', 'email' => 'jane@company.org', 'amount' => '149.50' },
        { 'name' => '', 'email' => 'invalid-email', 'amount' => 'not-a-number' }
      ]
    end
    
    describe '#calculate_completeness' do
      it 'calculates completeness correctly' do
        completeness = subject.send(:calculate_completeness, sample_data)
        
        # 8 out of 9 fields are filled (one empty name)
        expect(completeness).to be_within(5).of(89)
      end

      it 'handles empty data' do
        completeness = subject.send(:calculate_completeness, [])
        expect(completeness).to eq(0)
      end
    end
    
    describe '#calculate_validity' do
      it 'calculates validity correctly' do
        validity = subject.send(:calculate_validity, sample_data)
        
        # Should detect invalid email and invalid amount
        expect(validity).to be < 100
        expect(validity).to be > 0
      end
    end
    
    describe '#calculate_uniqueness' do
      it 'calculates uniqueness correctly' do
        uniqueness = subject.send(:calculate_uniqueness, sample_data)
        
        # All names and emails are unique, amounts are unique
        expect(uniqueness).to be > 60
      end
    end

    describe '#is_valid_value?' do
      it 'validates normal values as valid' do
        expect(subject.send(:is_valid_value?, 'normal text')).to be true
        expect(subject.send(:is_valid_value?, '123')).to be true
        expect(subject.send(:is_valid_value?, 'test@example.com')).to be true
      end

      it 'validates empty/nil values as invalid' do
        expect(subject.send(:is_valid_value?, '')).to be false
        expect(subject.send(:is_valid_value?, nil)).to be false
        expect(subject.send(:is_valid_value?, '   ')).to be false
      end

      it 'validates suspiciously long values as invalid' do
        long_value = 'x' * 10001
        expect(subject.send(:is_valid_value?, long_value)).to be false
      end
    end

    describe '#detect_value_format' do
      it 'detects various value formats correctly' do
        expect(subject.send(:detect_value_format, '123')).to eq('integer')
        expect(subject.send(:detect_value_format, '123.45')).to eq('decimal')
        expect(subject.send(:detect_value_format, '2024-01-15')).to eq('date')
        expect(subject.send(:detect_value_format, 'test@example.com')).to eq('email')
        expect(subject.send(:detect_value_format, 'regular text')).to eq('text')
        expect(subject.send(:detect_value_format, '')).to eq('null')
      end
    end
  end

  describe 'business impact calculation' do
    subject { described_class.new(data_source: data_source, user: user) }

    let(:detected_fields) do
      [
        { category: :customer, confidence: 0.9 },
        { category: :financial, confidence: 0.8 },
        { category: :temporal, confidence: 0.7 },
        { category: :location, confidence: 0.6 }
      ]
    end
    
    describe '#determine_primary_business_area' do
      it 'determines primary business area correctly' do
        primary_area = subject.send(:determine_primary_business_area, detected_fields)
        
        expect(primary_area).to be_a(String)
        expect(primary_area).not_to eq('General Data')
      end

      it 'handles empty detected fields' do
        primary_area = subject.send(:determine_primary_business_area, [])
        expect(primary_area).to eq('General Data')
      end
    end
    
    describe '#calculate_data_richness' do
      it 'calculates data richness accurately' do
        richness = subject.send(:calculate_data_richness, detected_fields)
        
        expect(richness).to be_between(0, 1)
        expect(richness).to be > 0.5  # 4 out of 7 possible categories
      end

      it 'handles empty fields' do
        richness = subject.send(:calculate_data_richness, [])
        expect(richness).to eq(0.1)
      end
    end
    
    describe '#assess_analytical_potential' do
      it 'assesses analytical potential correctly' do
        potential = subject.send(:assess_analytical_potential, detected_fields)
        
        expect(potential).to be_between(0, 1)
        expect(potential).to be > 0.5  # Has customer, financial, temporal data
      end
    end

    describe '#calculate_detection_confidence' do
      it 'calculates average confidence correctly' do
        confidence = subject.send(:calculate_detection_confidence, detected_fields)
        
        expected_avg = (0.9 + 0.8 + 0.7 + 0.6) / 4 * 100
        expect(confidence).to eq(expected_avg.round)
      end

      it 'handles empty fields' do
        confidence = subject.send(:calculate_detection_confidence, [])
        expect(confidence).to eq(0)
      end
    end
  end

  describe 'utility methods' do
    subject { described_class.new(data_source: data_source, user: user) }

    describe '#format_file_size' do
      it 'formats file sizes correctly' do
        expect(subject.send(:format_file_size, 1024)).to eq('1.0 KB')
        expect(subject.send(:format_file_size, 1048576)).to eq('1.0 MB')
        expect(subject.send(:format_file_size, 500)).to eq('500.0 B')
        expect(subject.send(:format_file_size, 0)).to eq('0 B')
      end
    end

    describe '#determine_quality_grade' do
      it 'assigns correct quality grades' do
        expect(subject.send(:determine_quality_grade, 95)).to eq('A')
        expect(subject.send(:determine_quality_grade, 85)).to eq('B')
        expect(subject.send(:determine_quality_grade, 75)).to eq('C')
        expect(subject.send(:determine_quality_grade, 65)).to eq('D')
        expect(subject.send(:determine_quality_grade, 55)).to eq('F')
      end
    end

    describe '#determine_impact_level' do
      it 'assigns correct impact levels' do
        expect(subject.send(:determine_impact_level, 85)).to eq('High')
        expect(subject.send(:determine_impact_level, 65)).to eq('Medium')
        expect(subject.send(:determine_impact_level, 45)).to eq('Moderate')
        expect(subject.send(:determine_impact_level, 25)).to eq('Low')
      end
    end

    describe '#calculate_pattern_confidence' do
      it 'calculates pattern confidence correctly' do
        # Test with exact pattern match
        confidence = subject.send(:calculate_pattern_confidence, 'customer_email', /customer/)
        expect(confidence).to be > 0.3
        expect(confidence).to be <= 1.0
      end
    end

    describe '#extract_time_minutes' do
      it 'extracts time correctly from various formats' do
        expect(subject.send(:extract_time_minutes, '10-15 minutes')).to eq(10)
        expect(subject.send(:extract_time_minutes, '30-60 minutes')).to eq(30)
        expect(subject.send(:extract_time_minutes, '1-2 hours')).to eq(60)
        expect(subject.send(:extract_time_minutes, '2-3 hours')).to eq(120)
      end

      it 'handles invalid formats gracefully' do
        expect(subject.send(:extract_time_minutes, 'invalid format')).to eq(30)
      end
    end
  end

  describe 'transformation suggestions' do
    subject { described_class.new(data_source: data_source, user: user) }

    describe '#suggest_customer_transformations' do
      it 'suggests email transformations for email fields' do
        transformations = subject.send(:suggest_customer_transformations, 'customer_email', {})
        
        expect(transformations).to be_an(Array)
        expect(transformations.any? { |t| t[:type] == 'extract_domain' }).to be true
      end

      it 'suggests name transformations for name fields' do
        transformations = subject.send(:suggest_customer_transformations, 'customer_name', {})
        
        expect(transformations).to be_an(Array)
        expect(transformations.any? { |t| t[:type] == 'split_name' }).to be true
      end
    end

    describe '#suggest_financial_transformations' do
      it 'suggests currency normalization for financial fields' do
        transformations = subject.send(:suggest_financial_transformations, 'order_total', {})
        
        expect(transformations).to be_an(Array)
        expect(transformations.any? { |t| t[:type] == 'normalize_currency' }).to be true
      end
    end

    describe '#suggest_temporal_transformations' do
      it 'suggests date parsing for temporal fields' do
        transformations = subject.send(:suggest_temporal_transformations, 'created_at', {})
        
        expect(transformations).to be_an(Array)
        expect(transformations.any? { |t| t[:type] == 'parse_datetime' }).to be true
      end
    end

    describe '#suggest_location_transformations' do
      it 'suggests geocoding for location fields' do
        transformations = subject.send(:suggest_location_transformations, 'customer_address', {})
        
        expect(transformations).to be_an(Array)
        expect(transformations.any? { |t| t[:type] == 'geocode_location' }).to be true
      end
    end
  end

  describe 'error handling' do
    subject { described_class.new(data_source: data_source, user: user) }

    describe '#base_error_response' do
      it 'returns properly formatted error response' do
        response = subject.send(:base_error_response, 'Test error message')
        
        expect(response[:success]).to be false
        expect(response[:error]).to eq('Test error message')
        expect(response[:suggestions]).to be_an(Array)
        expect(response[:file_info]).to be_a(Hash)
      end
    end
  end

  describe 'business context patterns' do
    subject { described_class.new(data_source: data_source, user: user) }

    it 'has comprehensive business field patterns defined' do
      patterns = described_class::BUSINESS_FIELD_PATTERNS
      
      expect(patterns).to have_key(:customer)
      expect(patterns).to have_key(:financial)
      expect(patterns).to have_key(:product)
      expect(patterns).to have_key(:order)
      expect(patterns).to have_key(:marketing)
      expect(patterns).to have_key(:temporal)
      expect(patterns).to have_key(:location)

      # Each pattern should have required keys
      patterns.each do |category, config|
        expect(config).to have_key(:patterns)
        expect(config).to have_key(:icon)
        expect(config).to have_key(:color)
        expect(config).to have_key(:insights)
        expect(config[:insights]).to be_an(Array)
      end
    end

    it 'has proper data quality thresholds defined' do
      thresholds = described_class::DATA_QUALITY_THRESHOLDS
      
      expect(thresholds).to have_key(:excellent)
      expect(thresholds).to have_key(:good)
      expect(thresholds).to have_key(:fair)
      expect(thresholds).to have_key(:poor)

      # Each threshold should have quality metrics
      thresholds.each do |level, metrics|
        expect(metrics).to have_key(:completeness)
        expect(metrics).to have_key(:uniqueness)
        expect(metrics).to have_key(:validity)
      end
    end
  end

  describe 'integration scenarios' do
    subject { described_class.new(data_source: data_source, user: user) }

    context 'with organization having existing data sources' do
      let!(:existing_source) { create(:data_source, organization: organization) }

      describe '#identify_cross_reference_opportunities' do
        it 'identifies opportunities when other sources exist' do
          detected_fields = [{ category: :customer, confidence: 0.9 }]
          opportunities = subject.send(:identify_cross_reference_opportunities, detected_fields)
          
          expect(opportunities).to be_an(Array)
          expect(opportunities).not_to be_empty
        end
      end
    end

    context 'with no existing data sources' do
      describe '#identify_cross_reference_opportunities' do
        it 'returns empty array when no other sources exist' do
          detected_fields = [{ category: :customer, confidence: 0.9 }]
          opportunities = subject.send(:identify_cross_reference_opportunities, detected_fields)
          
          expect(opportunities).to eq([])
        end
      end
    end
  end
end