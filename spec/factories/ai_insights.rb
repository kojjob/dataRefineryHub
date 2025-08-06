# frozen_string_literal: true

FactoryBot.define do
  factory :ai_insight, class: 'Ai::Insight' do
    organization
    user
    insight_type { "anomaly" }
    title { "Unusual spike in customer churn" }
    description { "Customer churn rate increased by 35% compared to last month" }
    confidence_score { 0.89 }
    impact_level { "high" }
    actionable { true }
    metadata do
      {
        current_value: 0.15,
        previous_value: 0.11,
        threshold: 0.12,
        affected_segments: [ "premium", "enterprise" ]
      }
    end
    recommendations do
      [
        {
          action: "investigate_churn_reasons",
          description: "Survey recently churned customers",
          priority: "high"
        },
        {
          action: "retention_campaign",
          description: "Launch targeted retention campaign for at-risk segments",
          priority: "medium"
        }
      ]
    end

    trait :read do
      read_at { 1.hour.ago }
      read_by { user.id }
    end

    trait :acknowledged do
      read_at { 2.hours.ago }
      acknowledged_at { 1.hour.ago }
      read_by { user.id }
      acknowledged_by { user.id }
    end

    trait :dismissed do
      read_at { 3.hours.ago }
      acknowledged_at { 2.hours.ago }
      dismissed_at { 1.hour.ago }
      dismissal_reason { "False positive - seasonal variation" }
    end

    trait :opportunity do
      insight_type { "opportunity" }
      title { "Cross-sell opportunity identified" }
      description { "85% of customers who bought Product A also bought Product B" }
      impact_level { "medium" }
      metadata do
        {
          product_a: "Premium Plan",
          product_b: "Add-on Service",
          correlation_strength: 0.85,
          potential_revenue: 25000
        }
      end
    end

    trait :trend do
      insight_type { "trend" }
      title { "Revenue growth accelerating" }
      description { "Monthly revenue growth rate increased from 5% to 8%" }
      impact_level { "positive" }
      confidence_score { 0.92 }
    end

    trait :prediction do
      insight_type { "prediction" }
      title { "Q4 revenue forecast" }
      description { "Projected Q4 revenue: $2.5M (15% YoY growth)" }
      confidence_score { 0.78 }
      metadata do
        {
          forecast_value: 2500000,
          confidence_interval: [ 2300000, 2700000 ],
          key_drivers: [ "new_product_launch", "holiday_season" ]
        }
      end
    end
  end
end
