FactoryBot.define do
  factory :extraction_job do
    data_source
    sequence(:job_id) { |n| "extract_test_#{SecureRandom.hex(4)}_#{n}" }
    status { 'queued' }
    priority { 'normal' }
    retry_count { 0 }
    max_retries { 3 }
    records_processed { 0 }
    records_failed { 0 }
    extraction_metadata { {} }

    trait :running do
      status { 'running' }
      started_at { 5.minutes.ago }
    end

    trait :completed do
      status { 'completed' }
      started_at { 10.minutes.ago }
      completed_at { 2.minutes.ago }
      records_processed { 100 }
      records_failed { 0 }
    end

    trait :failed do
      status { 'failed' }
      started_at { 10.minutes.ago }
      completed_at { 5.minutes.ago }
      records_processed { 50 }
      records_failed { 10 }
      error_details { { message: 'API rate limit exceeded', class: 'RateLimitError' } }
    end

    trait :high_priority do
      priority { 'high' }
    end

    trait :critical_priority do
      priority { 'critical' }
    end
  end
end
