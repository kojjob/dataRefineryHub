FactoryBot.define do
  factory :organization do
    sequence(:name) { |n| "Organization #{n}" }
    plan { 'starter' }
    status { 'active' }
    plan_limits { {} }
    settings { {} }
    stripe_customer_id { nil }

    trait :trial do
      status { 'trial' }
    end

    trait :growth_plan do
      plan { 'growth' }
    end

    trait :scale_plan do
      plan { 'scale' }
    end

    trait :enterprise_plan do
      plan { 'enterprise' }
    end

    trait :suspended do
      status { 'suspended' }
    end

    trait :with_stripe do
      stripe_customer_id { "cus_#{SecureRandom.alphanumeric(14)}" }
    end
  end
end
