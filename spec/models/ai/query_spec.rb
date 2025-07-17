# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ai::Query, type: :model do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  
  describe 'associations' do
    it { should belong_to(:organization) }
    it { should belong_to(:user) }
  end
  
  describe 'validations' do
    it { should validate_presence_of(:query) }
  end
  
  describe 'scopes' do
    let!(:recent_query) { create(:ai_query, organization: organization, user: user, created_at: 1.hour.ago) }
    let!(:old_query) { create(:ai_query, organization: organization, user: user, created_at: 2.days.ago) }
    let!(:successful_query) { create(:ai_query, organization: organization, user: user, response: { data: 'test' }.to_json) }
    let!(:failed_query) { create(:ai_query, organization: organization, user: user, response: nil) }
    
    describe '.recent' do
      it 'returns queries ordered by creation date descending' do
        recent_queries = Ai::Query.recent
        expect(recent_queries.map(&:created_at)).to eq(recent_queries.map(&:created_at).sort.reverse)
      end
    end
    
    describe '.successful' do
      it 'returns only queries with responses' do
        expect(Ai::Query.successful).to contain_exactly(recent_query, old_query, successful_query)
      end
    end
    
    describe '.by_intent' do
      let!(:revenue_query) { create(:ai_query, organization: organization, user: user, intent: :revenue_analysis) }
      
      it 'returns queries with specific intent' do
        expect(Ai::Query.by_intent(:revenue_analysis)).to include(revenue_query)
      end
    end
    
    describe '.average_execution_time' do
      it 'calculates average execution time' do
        avg_time = Ai::Query.average_execution_time(organization)
        expect(avg_time).to be_a(Numeric)
      end
    end
  end
  
  describe 'instance methods' do
    let(:query) { create(:ai_query, organization: organization, user: user) }
    
    describe '#mark_as_helpful' do
      it 'adds helpful context and records feedback timestamp' do
        query.mark_as_helpful
        expect(query.get_context('helpful')).to be true
        expect(query.get_context('feedback_at')).to be_present
      end
    end
    
    describe '#mark_as_not_helpful' do
      it 'adds not helpful context, records feedback and reason' do
        query.mark_as_not_helpful('Not accurate')
        expect(query.get_context('helpful')).to be false
        expect(query.get_context('feedback_at')).to be_present
        expect(query.get_context('feedback_reason')).to eq('Not accurate')
      end
    end
    
    describe '#has_visualizations?' do
      context 'when response contains visualizations' do
        let(:query) { create(:ai_query, response: { 'visualizations' => [{ type: 'chart' }] }.to_json) }
        
        it 'returns true' do
          expect(query.has_visualizations?).to be true
        end
      end
      
      context 'when response has no visualizations' do
        let(:query) { create(:ai_query, response: { 'message' => 'Test' }.to_json) }
        
        it 'returns false' do
          expect(query.has_visualizations?).to be_falsey
        end
      end
    end
    
    describe '#has_actions?' do
      context 'when response contains actions' do
        let(:query) { create(:ai_query, response: { 'actions' => [{ type: 'email' }] }.to_json) }
        
        it 'returns true' do
          expect(query.has_actions?).to be true
        end
      end
      
      context 'when response has no actions' do
        let(:query) { create(:ai_query, response: { 'message' => 'Test' }.to_json) }
        
        it 'returns false' do
          expect(query.has_actions?).to be_falsey
        end
      end
    end
    
    describe '#execution_time' do
      let(:query) { create(:ai_query, response: 'test') }
      
      before do
        query.update_columns(created_at: 2.seconds.ago, updated_at: Time.current)
      end
      
      it 'calculates time between creation and update' do
        expect(query.execution_time).to be_within(0.5).of(2.0)
      end
    end
  end
  
  describe 'enum' do
    it 'defines intent enum' do
      query = create(:ai_query, intent: :revenue_analysis)
      expect(query.intent_revenue_analysis?).to be true
    end
  end
  
  describe 'analytics methods' do
    let!(:queries) { create_list(:ai_query, 5, organization: organization, user: user) }
    
    describe '.popular_queries' do
      before do
        2.times { create(:ai_query, organization: organization, query: 'What is my revenue?') }
        create(:ai_query, organization: organization, query: 'Show customer churn')
      end
      
      it 'returns popular queries with counts' do
        popular = Ai::Query.popular_queries(organization, 5)
        expect(popular['What is my revenue?']).to eq(2)
      end
    end
    
    describe '.intent_distribution' do
      before do
        create(:ai_query, organization: organization, intent: :revenue_analysis)
        create(:ai_query, organization: organization, intent: :revenue_analysis)
        create(:ai_query, organization: organization, intent: :customer_analysis)
      end
      
      it 'returns intent distribution' do
        distribution = Ai::Query.intent_distribution(organization)
        expect(distribution.values.sum).to be >= 3
      end
    end
  end
end