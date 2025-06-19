FactoryBot.define do
  factory :audit_log do
    organization { nil }
    user { nil }
    action { "MyString" }
    resource_type { "MyString" }
    resource_id { "MyString" }
    details { "" }
    ip_address { "MyString" }
    user_agent { "MyString" }
    performed_at { "2025-06-19 12:37:37" }
  end
end
