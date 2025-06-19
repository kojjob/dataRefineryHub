FactoryBot.define do
  factory :user do
    organization
    sequence(:email) { |n| "user#{n}@example.com" }
    encrypted_password { BCrypt::Password.create('password123') }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    role { 'member' }
    confirmed_at { 1.day.ago }
    sign_in_count { 0 }
    invited_by { nil }

    trait :owner do
      role { 'owner' }
    end

    trait :admin do
      role { 'admin' }
    end

    trait :member do
      role { 'member' }
    end

    trait :viewer do
      role { 'viewer' }
    end

    trait :unconfirmed do
      confirmed_at { nil }
    end

    trait :invited do
      invitation_token { SecureRandom.urlsafe_base64 }
      confirmed_at { nil }
      association :invited_by, factory: :user, strategy: :build
    end

    trait :with_login_history do
      sign_in_count { rand(1..50) }
      last_sign_in_at { rand(1.hour..1.week).seconds.ago }
      current_sign_in_at { rand(1.minute..1.hour).seconds.ago }
    end
  end
end
