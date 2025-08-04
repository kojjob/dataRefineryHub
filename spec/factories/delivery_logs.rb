FactoryBot.define do
  factory :delivery_log do
    user { nil }
    organization { nil }
    channel { "MyString" }
    status { "MyString" }
    report_type { "MyString" }
    metadata { "" }
    delivered_at { "2025-08-03 17:14:35" }
    error_message { "MyText" }
  end
end
