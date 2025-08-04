FactoryBot.define do
  factory :pipeline do
    association :organization
    association :created_by, factory: :user
    
    name { "Pipeline #{SecureRandom.hex(4)}" }
    description { "Test pipeline for data transformation" }
    pipeline_type { "etl" }
    status { "active" }
    
    source_config do
      {
        type: "database",
        connection_id: SecureRandom.uuid,
        table_name: "users",
        columns: ["id", "name", "email"]
      }
    end
    
    destination_config do
      {
        type: "warehouse",
        connection_id: SecureRandom.uuid,
        table_name: "dim_users",
        schema: "analytics"
      }
    end
    
    transformation_rules { [] }
    
    trait :with_schedule do
      schedule_type { "daily" }
      schedule_expression { "14:30" }
      schedule_timezone { "UTC" }
    end
    
    trait :with_cron_schedule do
      schedule_type { "cron" }
      schedule_expression { "0 */6 * * *" }
      schedule_timezone { "America/New_York" }
    end
    
    trait :with_interval_schedule do
      schedule_type { "interval" }
      schedule_expression { "30" }
      schedule_timezone { "UTC" }
    end
    
    trait :paused do
      status { "paused" }
    end
    
    trait :executed do
      association :last_executed_by, factory: :user
      last_executed_at { 1.hour.ago }
      execution_count { 5 }
    end
  end
end
