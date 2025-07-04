FactoryBot.define do
  factory :scheduled_task_run do
    scheduled_task
    pipeline_execution
    task
    status { "running" }
    started_at { Time.current }
    
    trait :completed do
      status { "completed" }
      completed_at { 5.minutes.from_now }
      duration_seconds { 300 }
      output { { records_processed: 100 } }
    end
    
    trait :failed do
      status { "failed" }
      completed_at { 2.minutes.from_now }
      duration_seconds { 120 }
      error_message { "Connection timeout" }
    end
    
    trait :running do
      status { "running" }
      completed_at { nil }
    end
    
    trait :cancelled do
      status { "cancelled" }
      completed_at { 1.minute.from_now }
      duration_seconds { 60 }
    end
  end
end