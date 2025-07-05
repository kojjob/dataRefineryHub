FactoryBot.define do
  factory :task_template do
    organization
    name { "Test Template #{SecureRandom.hex(4)}" }
    description { "A test task template" }
    task_type { "extraction" }
    execution_mode { "automated" }
    category { "extraction" }
    template_config { { test: true } }
    default_timeout { 300 }
    default_priority { 0 }
    default_weight { 1 }
    tags { "test, sample" }
    active { true }
  end
end
