FactoryBot.define do
  factory :task do
    association :pipeline_execution
    name { Faker::Lorem.sentence(word_count: 3) }
    description { Faker::Lorem.paragraph }
    task_type { Task::TASK_TYPES.sample }
    execution_mode { 'automated' }
    status { 'pending' }
    priority { rand(0..10) }
    sequence(:position)
    configuration { {} }
    metadata { {} }
    error_message { nil }
    started_at { nil }
    completed_at { nil }
    retry_count { 0 }
    max_retries { 3 }
    timeout_seconds { 300 }
    assignee { nil }
    execution_id { SecureRandom.uuid }
    depends_on { [] }

    trait :manual do
      execution_mode { 'manual' }
    end

    trait :approval_required do
      execution_mode { 'approval_required' }
      status { 'waiting_approval' }
    end

    trait :hybrid do
      execution_mode { 'hybrid' }
    end

    trait :ready do
      status { 'ready' }
    end

    trait :in_progress do
      status { 'in_progress' }
      started_at { 1.minute.ago }
    end

    trait :completed do
      status { 'completed' }
      started_at { 10.minutes.ago }
      completed_at { 1.minute.ago }
    end

    trait :failed do
      status { 'failed' }
      started_at { 10.minutes.ago }
      completed_at { 1.minute.ago }
      error_message { 'Task execution failed' }
    end

    trait :with_assignee do
      association :assignee, factory: :user
    end

    trait :high_priority do
      priority { 10 }
    end

    trait :with_dependencies do
      depends_on { ['task1', 'task2'] }
    end

    trait :extraction do
      task_type { 'extraction' }
      configuration { { data_source_id: 1 } }
    end

    trait :transformation do
      task_type { 'transformation' }
      configuration { { data_source_id: 1, transformation_rules: {} } }
    end

    trait :validation do
      task_type { 'validation' }
      configuration { { data_source_id: 1, validation_rules: {} } }
    end
  end
end
