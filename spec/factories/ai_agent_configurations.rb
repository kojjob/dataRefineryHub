# frozen_string_literal: true

FactoryBot.define do
  factory :ai_agent_configuration, class: 'Ai::AgentConfiguration' do
    organization
    agent_type { "business_intelligence" }
    enabled { true }
    settings { {} }
    learning_data { {} }
    performance_score { nil }

    trait :disabled do
      enabled { false }
    end

    trait :high_performing do
      performance_score { 0.92 }
      learning_data do
        {
          successful_predictions: Array.new(20) { { accuracy: rand(0.85..0.95), timestamp: Time.current } },
          successful_actions: Array.new(15) { { impact: "high", timestamp: Time.current } }
        }
      end
    end

    trait :with_custom_settings do
      settings do
        {
          monitoring_frequency: "realtime",
          anomaly_threshold: 0.9,
          alert_channels: [ "email", "slack", "sms" ],
          custom_metrics: [ "ltv", "cac", "mrr" ]
        }
      end
    end

    factory :bi_agent_configuration do
      agent_type { "business_intelligence" }
      settings do
        {
          monitoring_frequency: "hourly",
          anomaly_threshold: 0.85,
          insight_generation: true,
          report_schedule: "weekly",
          focus_metrics: [ "revenue", "churn", "acquisition" ]
        }
      end
    end

    factory :customer_success_agent_configuration do
      agent_type { "customer_success" }
      settings do
        {
          churn_risk_threshold: 0.7,
          engagement_monitoring: true,
          satisfaction_surveys: true,
          health_score_calculation: "weighted",
          intervention_triggers: [ "low_activity", "support_tickets", "payment_failed" ]
        }
      end
    end

    factory :sales_agent_configuration do
      agent_type { "sales_optimization" }
      settings do
        {
          lead_scoring_enabled: true,
          pipeline_monitoring: true,
          forecast_accuracy_target: 0.85,
          deal_velocity_tracking: true,
          competitor_monitoring: [ "Competitor A", "Competitor B" ]
        }
      end
    end

    factory :inventory_agent_configuration do
      agent_type { "inventory_management" }
      settings do
        {
          reorder_point_calculation: "dynamic",
          safety_stock_multiplier: 1.5,
          demand_forecasting: true,
          supplier_performance_tracking: true,
          stockout_prevention_priority: "high"
        }
      end
    end

    factory :financial_agent_configuration do
      agent_type { "financial_advisor" }
      settings do
        {
          risk_tolerance: "moderate",
          investment_horizon: "long_term",
          cash_flow_monitoring: true,
          expense_categorization: "automatic",
          budget_alerts: true,
          tax_optimization: true
        }
      end
    end

    factory :marketing_agent_configuration do
      agent_type { "marketing_strategist" }
      settings do
        {
          campaign_optimization: true,
          attribution_model: "multi_touch",
          content_performance_tracking: true,
          audience_segmentation: "behavioral",
          roi_threshold: 2.5,
          ab_testing_enabled: true
        }
      end
    end
  end
end
