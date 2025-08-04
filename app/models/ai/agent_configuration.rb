# frozen_string_literal: true

module Ai
  class AgentConfiguration < ApplicationRecord
    self.table_name = 'ai_agent_configurations'
    
    belongs_to :organization
    
    validates :agent_type, presence: true, uniqueness: { scope: :organization_id }
    validates :organization, presence: true
    
    # Available agent types
    AGENT_TYPES = %w[
      business_intelligence
      customer_success
      sales_optimization
      inventory_management
      financial_advisor
      marketing_strategist
    ].freeze
    
    validates :agent_type, inclusion: { in: AGENT_TYPES }
    
    # Scopes
    scope :enabled, -> { where(enabled: true) }
    scope :by_performance, -> { order(performance_score: :desc) }
    
    # Default settings for each agent type
    DEFAULT_SETTINGS = {
      business_intelligence: {
        monitoring_frequency: 'hourly',
        anomaly_threshold: 0.85,
        insight_generation: true,
        report_schedule: 'weekly',
        focus_metrics: ['revenue', 'churn', 'acquisition']
      },
      customer_success: {
        churn_risk_threshold: 0.7,
        engagement_monitoring: true,
        satisfaction_surveys: true,
        health_score_calculation: 'weighted',
        intervention_triggers: ['low_activity', 'support_tickets', 'payment_failed']
      },
      sales_optimization: {
        lead_scoring_enabled: true,
        pipeline_monitoring: true,
        forecast_accuracy_target: 0.85,
        deal_velocity_tracking: true,
        competitor_monitoring: []
      },
      inventory_management: {
        reorder_point_calculation: 'dynamic',
        safety_stock_multiplier: 1.5,
        demand_forecasting: true,
        supplier_performance_tracking: true,
        stockout_prevention_priority: 'high'
      },
      financial_advisor: {
        risk_tolerance: 'moderate',
        investment_horizon: 'long_term',
        cash_flow_monitoring: true,
        expense_categorization: 'automatic',
        budget_alerts: true,
        tax_optimization: true
      },
      marketing_strategist: {
        campaign_optimization: true,
        attribution_model: 'multi_touch',
        content_performance_tracking: true,
        audience_segmentation: 'behavioral',
        roi_threshold: 2.5,
        ab_testing_enabled: true
      }
    }.with_indifferent_access.freeze
    
    # Callbacks
    after_initialize :set_defaults, if: :new_record?
    before_validation :validate_settings_schema
    
    # Instance methods
    def update_settings(new_settings)
      self.settings = (settings || {}).merge(new_settings.stringify_keys)
      save
    end
    
    def record_learning(event_type, data)
      self.learning_data ||= {}
      event_key = event_type.to_s.pluralize
      
      self.learning_data[event_key] ||= []
      self.learning_data[event_key] << data.merge(timestamp: Time.current)
      
      # Keep only last 100 events per type
      if self.learning_data[event_key].size > 100
        self.learning_data[event_key] = self.learning_data[event_key].last(100)
      end
      
      save
    end
    
    def update_performance_score
      return unless learning_data.present?
      
      total_events = 0
      successful_events = 0
      
      learning_data.each do |event_type, events|
        total_events += events.size
        successful_events += events.count { |e| e['success'] || e['impact'] == 'high' }
      end
      
      self.performance_score = total_events > 0 ? (successful_events.to_f / total_events).round(2) : nil
      save
    end
    
    def configuration_for(key)
      settings&.dig(key.to_s)
    end
    
    def reset_to_defaults
      self.settings = default_settings_for_type
      self.learning_data = {}
      self.performance_score = nil
      save
    end
    
    def default_settings_for_type
      DEFAULT_SETTINGS[agent_type.to_sym] || {}
    end
    
    # Agent-specific behaviors
    def monitored_metrics
      case agent_type
      when 'business_intelligence'
        ['revenue', 'customer_acquisition', 'churn_rate', 'profit_margin']
      when 'sales_optimization'
        ['pipeline_value', 'conversion_rate', 'average_deal_size', 'sales_cycle_length']
      when 'customer_success'
        ['satisfaction_score', 'support_tickets', 'feature_adoption', 'engagement_rate']
      else
        []
      end
    end
    
    def insight_schedule
      configuration_for(:monitoring_frequency) || 'daily'
    end
    
    def funnel_stages
      return [] unless agent_type == 'sales_optimization'
      ['lead', 'qualified', 'proposal', 'negotiation', 'closed']
    end
    
    def recommend_pricing
      # Placeholder for pricing recommendation logic
      raise NotImplementedError unless agent_type == 'sales_optimization'
      { recommended_adjustment: 0, confidence: 0.75 }
    end
    
    private
    
    def set_defaults
      self.settings ||= default_settings_for_type
      self.learning_data ||= {}
      self.enabled = true if enabled.nil?
    end
    
    def validate_settings_schema
      return true unless settings.present?
      
      valid_keys = default_settings_for_type.keys.map(&:to_s)
      invalid_keys = settings.keys - valid_keys
      
      if invalid_keys.any?
        errors.add(:settings, "contains invalid keys: #{invalid_keys.join(', ')}")
      end
    end
  end
end