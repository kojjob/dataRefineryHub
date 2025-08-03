FactoryBot.define do
  factory :delivery_preference do
    user { nil }
    organization { nil }
    report_type { "MyString" }
    channel { "MyString" }
    format { "MyString" }
    schedule { "" }
    options { "" }
    active { false }
  end
end
