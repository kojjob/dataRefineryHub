FactoryBot.define do
  factory :raw_data_record do
    organization { nil }
    data_source { nil }
    extraction_job { nil }
    record_type { "MyString" }
    external_id { "MyString" }
    raw_data { "MyText" }
    encrypted_payload { "MyText" }
    checksum { "MyString" }
    processing_status { "MyString" }
    processed_at { "2025-06-19 12:49:06" }
    validation_errors { "" }
  end
end
