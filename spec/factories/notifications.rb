FactoryBot.define do
  factory :notification do
    association :user
    association :organization
    title { "Test Notification" }
    message { "This is a test notification message" }
    notification_type { "data_sync_success" }
    read_at { nil }
    priority { 1 }
    metadata { {} }

    trait :unread do
      read_at { nil }
    end

    trait :read do
      read_at { 1.hour.ago }
    end

    trait :high_priority do
      priority { 2 }
      notification_type { "data_sync_failure" }
    end

    trait :urgent do
      priority { 3 }
      notification_type { "system_maintenance" }
    end

    trait :with_notifiable do
      association :notifiable, factory: :data_source
    end
  end
end
