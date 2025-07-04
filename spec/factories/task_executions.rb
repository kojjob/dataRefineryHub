FactoryBot.define do
  factory :task_execution do
    association :task
    execution_id { SecureRandom.uuid }
    status { 'pending' }
    started_at { nil }
    completed_at { nil }
    result { {} }
    error_message { nil }
    error_details { {} }
    executed_by { nil }
    duration_seconds { nil }
    metadata { {} }

    trait :running do
      status { 'running' }
      started_at { 1.minute.ago }
    end

    trait :completed do
      status { 'completed' }
      started_at { 10.minutes.ago }
      completed_at { 1.minute.ago }
      duration_seconds { 540 }
      result { { processed: 100, errors: 0 } }
    end

    trait :failed do
      status { 'failed' }
      started_at { 5.minutes.ago }
      completed_at { 1.minute.ago }
      duration_seconds { 240 }
      error_message { 'Execution failed' }
      error_details { { error_class: 'RuntimeError', backtrace: ['line1', 'line2'] } }
    end

    trait :with_user do
      association :executed_by, factory: :user
    end
  end
end
