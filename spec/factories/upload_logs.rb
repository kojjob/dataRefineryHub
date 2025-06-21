FactoryBot.define do
  factory :upload_log do
    association :scheduled_upload
    
    status { 'completed' }
    started_at { 1.hour.ago }
    completed_at { 30.minutes.ago }
    files_processed { 1 }
    files_failed { 0 }
    details { {} }
    error_message { nil }
    
    trait :pending do
      status { 'pending' }
      completed_at { nil }
    end
    
    trait :running do
      status { 'running' }
      completed_at { nil }
    end
    
    trait :failed do
      status { 'failed' }
      files_processed { 0 }
      files_failed { 1 }
      error_message { 'File processing failed' }
    end
    
    trait :completed_with_errors do
      status { 'completed_with_errors' }
      files_processed { 2 }
      files_failed { 1 }
      details do
        {
          'processed_files' => [
            { 'name' => 'file1.csv', 'records' => 100 },
            { 'name' => 'file2.csv', 'records' => 150 }
          ],
          'errors' => [
            { 'file' => 'file3.csv', 'error' => 'Invalid format' }
          ]
        }
      end
    end
    
    trait :with_processed_files do
      details do
        {
          'processed_files' => [
            { 'name' => 'customers.csv', 'records' => 500 },
            { 'name' => 'orders.csv', 'records' => 1200 }
          ]
        }
      end
    end
    
    trait :with_errors do
      details do
        {
          'errors' => [
            { 'file' => 'invalid.csv', 'error' => 'Missing required columns' },
            { 'file' => 'corrupt.csv', 'error' => 'File corrupted' }
          ]
        }
      end
    end
  end
end