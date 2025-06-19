FactoryBot.define do
  factory :data_source do
    organization
    sequence(:name) { |n| "Data Source #{n}" }
    source_type { 'shopify' }
    config { { api_version: '2023-10', timeout: 30 } }
    credentials { { api_key: 'test_key', secret: 'test_secret', shop_domain: 'test-shop.myshopify.com' } }
    status { 'connected' }
    sync_frequency { 'daily' }
    last_sync_at { 1.hour.ago }
    next_sync_at { 23.hours.from_now }

    trait :shopify do
      source_type { 'shopify' }
      credentials { { api_key: 'sk_test_123', secret: 'secret_123', shop_domain: 'test-shop.myshopify.com' } }
    end

    trait :stripe do
      source_type { 'stripe' }
      credentials { { secret_key: 'sk_test_123', publishable_key: 'pk_test_123' } }
    end

    trait :google_analytics do
      source_type { 'google_analytics' }
      credentials { { property_id: 'GA4-123456789', service_account_json: '{}' } }
    end

    trait :quickbooks do
      source_type { 'quickbooks' }
      credentials { { access_token: 'token_123', refresh_token: 'refresh_123', company_id: 'comp_123' } }
    end

    trait :mailchimp do
      source_type { 'mailchimp' }
      credentials { { api_key: 'api_key_123', server_prefix: 'us1' } }
    end

    trait :disconnected do
      status { 'disconnected' }
      last_sync_at { nil }
      next_sync_at { nil }
    end

    trait :connected do
      status { 'connected' }
    end

    trait :syncing do
      status { 'syncing' }
    end

    trait :error do
      status { 'error' }
      error_message { 'API rate limit exceeded' }
    end

    trait :realtime_sync do
      sync_frequency { 'realtime' }
      next_sync_at { 5.minutes.from_now }
    end

    trait :hourly_sync do
      sync_frequency { 'hourly' }
      next_sync_at { 1.hour.from_now }
    end
  end
end
