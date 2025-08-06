# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ai::AgentConfiguration, type: :model do
  let(:organization) { create(:organization) }

  describe 'associations' do
    it { should belong_to(:organization) }
  end

  describe 'validations' do
    subject { build(:ai_agent_configuration, organization: organization) }

    it { should validate_presence_of(:organization) }
    it { should validate_presence_of(:agent_type) }
    it { should validate_uniqueness_of(:agent_type).scoped_to(:organization_id) }
    it { should validate_inclusion_of(:agent_type).in_array(%w[
      business_intelligence
      customer_success
      sales_optimization
      inventory_management
      financial_advisor
      marketing_strategist
    ]) }
  end

  describe 'scopes' do
    let!(:enabled_agent) { create(:ai_agent_configuration, organization: organization, enabled: true) }
    let!(:disabled_agent) { create(:ai_agent_configuration, organization: organization, enabled: false, agent_type: 'sales_optimization') }
    let!(:high_performing) { create(:ai_agent_configuration, organization: organization, performance_score: 0.9, agent_type: 'inventory_management') }

    describe '.enabled' do
      it 'returns only enabled agents' do
        expect(Ai::AgentConfiguration.enabled).to contain_exactly(enabled_agent, high_performing)
      end
    end

    describe '.by_performance' do
      it 'orders by performance score descending' do
        expect(Ai::AgentConfiguration.by_performance).to eq([ high_performing, enabled_agent, disabled_agent ])
      end
    end
  end

  describe 'default values' do
    let(:agent) { Ai::AgentConfiguration.new(organization: organization, agent_type: 'business_intelligence') }

    it 'sets enabled to true by default' do
      expect(agent.enabled).to be true
    end

    it 'initializes empty settings' do
      expect(agent.settings).to eq({})
    end

    it 'initializes empty learning_data' do
      expect(agent.learning_data).to eq({})
    end
  end

  describe 'instance methods' do
    let(:agent) { create(:ai_agent_configuration, organization: organization) }

    describe '#update_settings' do
      it 'merges new settings with existing ones' do
        agent.update_settings(threshold: 0.8)
        agent.update_settings(frequency: 'daily')

        expect(agent.settings).to include('threshold' => 0.8, 'frequency' => 'daily')
      end
    end

    describe '#record_learning' do
      it 'adds learning data with timestamp' do
        agent.record_learning(:successful_prediction, { accuracy: 0.85 })

        expect(agent.learning_data['successful_predictions']).to be_present
        expect(agent.learning_data['successful_predictions'].first).to include('accuracy' => 0.85)
      end

      it 'maintains learning history limit' do
        101.times { agent.record_learning(:event, {}) }

        expect(agent.learning_data['events'].count).to eq(100)
      end
    end

    describe '#update_performance_score' do
      it 'calculates score based on recent performance' do
        agent.record_learning(:successful_action, { impact: 'high' })
        agent.record_learning(:successful_action, { impact: 'medium' })
        agent.record_learning(:failed_action, { reason: 'timeout' })

        agent.update_performance_score

        expect(agent.performance_score).to be_between(0.6, 0.7)
      end
    end

    describe '#configuration_for' do
      before do
        agent.update_settings(
          revenue_threshold: 1000,
          alert_channels: [ 'email', 'slack' ]
        )
      end

      it 'returns specific configuration value' do
        expect(agent.configuration_for(:revenue_threshold)).to eq(1000)
      end

      it 'returns nil for non-existent configuration' do
        expect(agent.configuration_for(:non_existent)).to be_nil
      end
    end

    describe '#reset_to_defaults' do
      before do
        agent.update!(
          settings: { custom: 'value' },
          learning_data: { events: [] },
          performance_score: 0.5
        )
      end

      it 'resets configuration to defaults' do
        agent.reset_to_defaults

        expect(agent.settings).to eq(agent.default_settings_for_type)
        expect(agent.learning_data).to eq({})
        expect(agent.performance_score).to be_nil
      end
    end

    describe '#default_settings_for_type' do
      context 'for business_intelligence agent' do
        let(:agent) { build(:ai_agent_configuration, agent_type: 'business_intelligence') }

        it 'returns BI-specific defaults' do
          defaults = agent.default_settings_for_type
          expect(defaults).to include(
            'monitoring_frequency' => 'hourly',
            'anomaly_threshold' => 0.85,
            'insight_generation' => true
          )
        end
      end

      context 'for customer_success agent' do
        let(:agent) { build(:ai_agent_configuration, agent_type: 'customer_success') }

        it 'returns CS-specific defaults' do
          defaults = agent.default_settings_for_type
          expect(defaults).to include(
            'churn_risk_threshold' => 0.7,
            'engagement_monitoring' => true,
            'satisfaction_surveys' => true
          )
        end
      end
    end
  end

  describe 'specialized agent behaviors' do
    describe 'Business Intelligence Agent' do
      let(:bi_agent) { create(:ai_agent_configuration,
        organization: organization,
        agent_type: 'business_intelligence'
      ) }

      it 'monitors key business metrics' do
        expect(bi_agent.monitored_metrics).to include(
          'revenue', 'customer_acquisition', 'churn_rate', 'profit_margin'
        )
      end

      it 'generates insights on schedule' do
        expect(bi_agent.insight_schedule).to eq('hourly')
      end
    end

    describe 'Sales Optimization Agent' do
      let(:sales_agent) { create(:ai_agent_configuration,
        organization: organization,
        agent_type: 'sales_optimization'
      ) }

      it 'tracks sales funnel metrics' do
        expect(sales_agent.funnel_stages).to eq(
          [ 'lead', 'qualified', 'proposal', 'negotiation', 'closed' ]
        )
      end

      it 'recommends pricing strategies' do
        expect(sales_agent).to respond_to(:recommend_pricing)
      end
    end
  end

  describe 'callbacks' do
    describe 'after_create' do
      it 'initializes with default settings for agent type' do
        agent = create(:ai_agent_configuration,
          organization: organization,
          agent_type: 'financial_advisor'
        )

        expect(agent.settings).to include('risk_tolerance', 'investment_horizon')
      end
    end

    describe 'before_save' do
      it 'validates settings schema for agent type' do
        agent = build(:ai_agent_configuration,
          organization: organization,
          agent_type: 'business_intelligence',
          settings: { invalid_key: 'value' }
        )

        expect(agent).not_to be_valid
        expect(agent.errors[:settings]).to include('contains invalid keys')
      end
    end
  end
end
