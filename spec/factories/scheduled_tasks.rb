FactoryBot.define do
  factory :scheduled_task do
    organization
    task_template
    created_by { association :user, organization: organization }
    name { "Scheduled Task #{SecureRandom.hex(4)}" }
    description { "A scheduled task for testing" }
    status { "active" }
    schedule_type { "daily" }
    time_of_day { Time.parse("09:00") }
    start_date { Date.current }
    next_run_at { 1.hour.from_now }
    configuration { { data_source_id: 1 } }
    task_overrides { {} }

    trait :once do
      schedule_type { "once" }
      scheduled_at { 1.day.from_now }
      time_of_day { nil }
    end

    trait :daily do
      schedule_type { "daily" }
      time_of_day { Time.parse("09:00") }
    end

    trait :weekly do
      schedule_type { "weekly" }
      time_of_day { Time.parse("09:00") }
      days_of_week { [ "monday", "wednesday", "friday" ] }
    end

    trait :monthly do
      schedule_type { "monthly" }
      time_of_day { Time.parse("09:00") }
      day_of_month { 15 }
    end

    trait :custom do
      schedule_type { "custom" }
      cron_expression { "0 9 * * *" }
      time_of_day { nil }
    end

    trait :paused do
      status { "paused" }
      paused_at { Time.current }
    end

    trait :expired do
      status { "expired" }
      end_date { 1.day.ago }
    end

    trait :with_max_runs do
      max_runs { 10 }
      run_count { 0 }
    end

    trait :completed do
      status { "completed" }
      completed_at { Time.current }
    end
  end
end
