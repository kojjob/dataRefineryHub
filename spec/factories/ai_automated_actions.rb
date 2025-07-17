# frozen_string_literal: true

FactoryBot.define do
  factory :ai_automated_action, class: 'Ai::AutomatedAction' do
    organization
    action_type { "send_email" }
    parameters do
      {
        recipient: "team@example.com",
        subject: "Weekly Revenue Report",
        template: "revenue_summary",
        confidence: 0.85
      }
    end
    status { "pending" }
    suggested_by { "bi_agent" }
    
    trait :approved do
      status { "approved" }
      approved_at { 1.hour.ago }
      association :approved_by, factory: :user
    end
    
    trait :executing do
      status { "executing" }
      approved_at { 2.hours.ago }
      executed_at { 1.hour.ago }
      association :approved_by, factory: :user
    end
    
    trait :completed do
      status { "completed" }
      approved_at { 3.hours.ago }
      executed_at { 2.hours.ago }
      completed_at { 1.hour.ago }
      association :approved_by, factory: :user
      result do
        {
          success: true,
          message: "Email sent successfully",
          details: {
            message_id: "msg_123456",
            sent_at: 1.hour.ago.iso8601
          }
        }
      end
    end
    
    trait :failed do
      status { "failed" }
      approved_at { 2.hours.ago }
      executed_at { 1.hour.ago }
      completed_at { 30.minutes.ago }
      association :approved_by, factory: :user
      result do
        {
          success: false,
          error: "SMTP connection failed",
          retry_count: 3
        }
      end
    end
    
    trait :high_impact do
      action_type { "adjust_pricing" }
      parameters do
        {
          product_ids: [1, 2, 3],
          adjustment_type: "percentage",
          adjustment_value: 10,
          estimated_revenue_impact: 50000,
          confidence: 0.92
        }
      end
    end
    
    trait :with_insight do
      association :insight, factory: :ai_insight
    end
    
    factory :email_action do
      action_type { "send_email" }
    end
    
    factory :campaign_action do
      action_type { "create_campaign" }
      parameters do
        {
          name: "Summer Sale 2024",
          target_audience: "high_value_customers",
          discount: 20,
          duration_days: 14,
          estimated_reach: 5000,
          confidence: 0.88
        }
      end
    end
    
    factory :pricing_action do
      action_type { "adjust_pricing" }
      high_impact
    end
    
    factory :inventory_action do
      action_type { "reorder_inventory" }
      parameters do
        {
          product_id: 123,
          current_stock: 50,
          reorder_quantity: 200,
          supplier: "Main Supplier Inc",
          urgency: "medium",
          confidence: 0.79
        }
      end
    end
  end
end