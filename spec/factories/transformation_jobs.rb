FactoryBot.define do
  factory :transformation_job do
    organization { nil }
    job_id { "MyString" }
    transformation_type { "MyString" }
    input_records_count { 1 }
    output_records_count { 1 }
    status { "MyString" }
    started_at { "2025-06-19 12:52:04" }
    completed_at { "2025-06-19 12:52:04" }
    error_details { "" }
    transformation_rules { "" }
    data_quality_metrics { "" }
  end
end
