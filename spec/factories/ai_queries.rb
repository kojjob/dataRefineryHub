# frozen_string_literal: true

FactoryBot.define do
  factory :ai_query, class: 'Ai::Query' do
    organization
    user
    query { "What's my revenue this month?" }
    response do
      {
        message: "Your revenue for this month is $125,000.",
        data: {
          revenue: 125000,
          period: "current_month"
        },
        visualizations: [],
        actions: []
      }.to_json
    end
    intent { 1 } # revenue_analysis
    entities { { time_period: "current_month", metrics: ["revenue"] } }
    context do
      {
        current_page: "/dashboard",
        timestamp: Time.current.iso8601
      }
    end
    # execution_time is calculated, not stored
    
    trait :with_visualizations do
      response do
        {
          message: "Here's your revenue breakdown",
          data: { revenue: 125000 },
          visualizations: [
            {
              type: "bar_chart",
              title: "Revenue by Product",
              data: {
                "Product A" => 50000,
                "Product B" => 45000,
                "Product C" => 30000
              }
            }
          ],
          actions: []
        }.to_json
      end
    end
    
    trait :with_actions do
      response do
        {
          message: "I found some opportunities",
          data: {},
          visualizations: [],
          actions: [
            {
              type: "send_email",
              description: "Send revenue report to team",
              priority: "medium"
            }
          ]
        }.to_json
      end
    end
    
    trait :helpful do
      after(:create) do |query|
        query.mark_as_helpful
      end
    end
    
    trait :not_helpful do
      after(:create) do |query|
        query.mark_as_not_helpful("Results were not accurate")
      end
    end
    
    trait :failed do
      response { nil }
    end
  end
end