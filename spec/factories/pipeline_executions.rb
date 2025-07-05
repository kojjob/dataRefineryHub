FactoryBot.define do
  factory :pipeline_execution do
    association :data_source
    association :user
    execution_id { SecureRandom.uuid }
    pipeline_name { "#{Faker::Lorem.word}_pipeline" }
    status { 'pending' }
    started_at { Time.current }
    completed_at { nil }
    progress { 0 }
    current_stage { nil }
    error_message { nil }
    error_details { {} }
    parameters { {} }
    result_summary { {} }
    execution_mode { 'automatic' }
    manual_intervention_required { false }
    approval_status { nil }
    approved_by { nil }
    last_manual_task_at { nil }

    trait :running do
      status { 'running' }
      progress { 50 }
      current_stage { 'transformation' }
    end

    trait :completed do
      status { 'completed' }
      progress { 100 }
      completed_at { 1.hour.ago }
    end

    trait :failed do
      status { 'failed' }
      completed_at { 30.minutes.ago }
      error_message { 'Pipeline execution failed' }
      error_details { { error_class: 'StandardError', backtrace: [] } }
    end

    trait :manual do
      execution_mode { 'manual' }
    end

    trait :scheduled do
      execution_mode { 'scheduled' }
    end

    trait :triggered do
      execution_mode { 'triggered' }
    end

    trait :requiring_intervention do
      manual_intervention_required { true }
      last_manual_task_at { 5.minutes.ago }
    end

    trait :pending_approval do
      approval_status { 'pending' }
    end

    trait :approved do
      approval_status { 'approved' }
      association :approved_by, factory: :user
    end

    trait :rejected do
      approval_status { 'rejected' }
      status { 'cancelled' }
      association :approved_by, factory: :user
    end
  end
end
