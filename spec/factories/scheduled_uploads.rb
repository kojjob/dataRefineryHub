FactoryBot.define do
  factory :scheduled_upload do
    association :data_source
    association :user
    
    sequence(:name) { |n| "Scheduled Upload #{n}" }
    description { "Automated data upload for #{name}" }
    frequency { 'daily' }
    active { true }
    file_pattern { '*.csv' }
    max_file_age_hours { 24 }
    delete_after_processing { false }
    retry_failed_files { true }
    notification_emails { 'admin@example.com' }
    webhook_url { nil }
    configuration { {} }
    
    trait :hourly do
      frequency { 'hourly' }
    end
    
    trait :weekly do
      frequency { 'weekly' }
    end
    
    trait :monthly do
      frequency { 'monthly' }
    end
    
    trait :inactive do
      active { false }
    end
    
    trait :with_webhook do
      webhook_url { 'https://example.com/webhook' }
    end
    
    trait :with_custom_config do
      configuration do
        {
          'source_directory' => '/uploads',
          'backup_enabled' => true,
          'validation_rules' => ['required_columns']
        }
      end
    end
  end
end