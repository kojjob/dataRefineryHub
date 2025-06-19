FactoryBot.define do
  factory :extraction_job do
    data_source { nil }
    job_id { "MyString" }
    status { "MyString" }
    priority { "MyString" }
    started_at { "2025-06-19 12:48:48" }
    completed_at { "2025-06-19 12:48:48" }
    records_processed { 1 }
    records_failed { 1 }
    error_details { "" }
    retry_count { 1 }
    max_retries { 1 }
    next_retry_at { "2025-06-19 12:48:48" }
    extraction_metadata { "" }
  end
end
