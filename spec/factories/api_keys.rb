FactoryBot.define do
  factory :api_key do
    organization
    user
    name { "Test API Key #{SecureRandom.hex(4)}" }
    key { SecureRandom.hex(32) }
    active { true }
    last_used_at { nil }
    usage_count { 0 }

    trait :inactive do
      active { false }
    end

    trait :recently_used do
      last_used_at { 1.hour.ago }
      usage_count { rand(10..100) }
    end
  end
end
