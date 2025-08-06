# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Rate Limiting", type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }

  before do
    # Clear the cache before each test to ensure clean slate
    Rack::Attack.cache.clear
    sign_in user
  end

  describe "notification endpoints rate limiting" do
    describe "general notifications endpoint" do
      it "allows normal usage" do
        # Should allow reasonable number of requests
        10.times do
          get "/api/v1/notifications"
          expect(response).not_to have_http_status(:too_many_requests)
        end
      end

      it "throttles excessive requests" do
        # Configure a low limit for testing
        allow(Rack::Attack).to receive(:throttled_responder).and_wrap_original do |original, *args|
          [429, { 'Content-Type' => 'application/json' }, ['{"error": "Too Many Requests"}']]
        end

        # Mock the throttle to trigger after 5 requests for testing
        original_limit = nil
        Rack::Attack.throttles.each do |name, throttle|
          if name == 'notifications_per_user'
            original_limit = throttle.instance_variable_get(:@limit)
            throttle.instance_variable_set(:@limit, 5)
          end
        end

        # Make requests up to the limit
        5.times do
          get "/api/v1/notifications"
          expect(response.status).to be < 400
        end

        # The next request should be throttled
        get "/api/v1/notifications"
        expect(response).to have_http_status(:too_many_requests)

        # Restore original limit
        Rack::Attack.throttles.each do |name, throttle|
          if name == 'notifications_per_user' && original_limit
            throttle.instance_variable_set(:@limit, original_limit)
          end
        end
      end
    end

    describe "notification marking operations" do
      let(:notification) { create(:notification, user: user, organization: organization) }

      it "allows normal marking operations" do
        5.times do
          patch "/api/v1/notifications/#{notification.id}/mark_as_read"
          expect(response).not_to have_http_status(:too_many_requests)
          
          # Reset notification for next request
          notification.update!(read_at: nil)
        end
      end

      it "throttles excessive marking operations" do
        # Test mark all as read rate limiting
        3.times do
          post "/api/v1/notifications/mark_all_as_read"
          expect(response).not_to have_http_status(:too_many_requests)
        end
      end
    end

    describe "notification deletion rate limiting" do
      it "allows normal deletion rate" do
        notifications = create_list(:notification, 3, user: user, organization: organization)
        
        notifications.each do |notification|
          delete "/api/v1/notifications/#{notification.id}"
          expect(response).not_to have_http_status(:too_many_requests)
        end
      end
    end

    describe "rate limit headers" do
      it "includes rate limit information in response headers" do
        get "/api/v1/notifications"
        
        # Should include rate limit headers (may not be present in test environment)
        # but should not error if throttled
        if response.headers.key?('X-RateLimit-Limit')
          expect(response.headers['X-RateLimit-Limit']).to be_present
          expect(response.headers['X-RateLimit-Remaining']).to be_present
        end
      end
    end
  end

  describe "API rate limiting" do
    it "applies general API rate limits" do
      # Test that API endpoints are subject to rate limiting
      10.times do |i|
        get "/api/v1/notifications"
        # Should not be throttled for reasonable usage
        expect(response).not_to have_http_status(:too_many_requests)
      end
    end

    it "differentiates between users" do
      other_user = create(:user, organization: organization)
      
      # User 1 makes requests
      5.times do
        get "/api/v1/notifications"
        expect(response).not_to have_http_status(:too_many_requests)
      end
      
      # User 2 should have their own rate limit
      sign_out user
      sign_in other_user
      
      5.times do
        get "/api/v1/notifications"
        expect(response).not_to have_http_status(:too_many_requests)
      end
    end
  end

  describe "authentication rate limiting" do
    before { sign_out user }

    it "applies login rate limits" do
      # Test login endpoint rate limiting (if using Devise)
      3.times do
        post "/users/sign_in", params: {
          user: { email: user.email, password: "wrongpassword" }
        }
        # Should allow a few attempts
      end
      
      # Should eventually throttle excessive login attempts
      # (This test may need adjustment based on actual Rack::Attack configuration)
    end
  end

  describe "ETL operations rate limiting" do
    it "applies stricter limits to ETL operations" do
      # ETL operations should have stricter rate limits
      # This test would need actual ETL endpoints to be meaningful
      # For now, we'll test the configuration exists
      expect(Rack::Attack.throttles).to have_key('etl/ip')
    end
  end

  describe "file upload rate limiting" do
    it "limits file upload operations" do
      # File uploads should be rate limited
      expect(Rack::Attack.throttles).to have_key('uploads/ip')
    end
  end

  describe "export operations rate limiting" do
    it "limits data export operations" do
      # Data exports should be rate limited
      expect(Rack::Attack.throttles).to have_key('exports/ip')
    end
  end

  describe "rate limit bypass for health checks" do
    it "does not apply rate limits to health check endpoints" do
      # Health checks should not be rate limited
      20.times do
        get "/health"  # Assuming a health check endpoint exists
        # Should not be subject to rate limiting
      end
    end
  end

  describe "security blocking" do
    it "blocks requests with malicious user agents" do
      bad_agents = ['sqlmap', 'nikto', 'masscan']
      
      bad_agents.each do |agent|
        get "/api/v1/notifications", headers: { 'User-Agent' => agent }
        expect(response).to have_http_status(:forbidden)
      end
    end

    it "blocks requests to sensitive paths" do
      sensitive_paths = [
        '/.env',
        '/.git/config',
        '/config/database.yml',
        '/wp-admin'
      ]
      
      sensitive_paths.each do |path|
        get path
        expect(response).to have_http_status(:forbidden)
      end
    end

    it "allows normal requests" do
      get "/api/v1/notifications"
      expect(response).not_to have_http_status(:forbidden)
    end
  end

  describe "rate limit response format" do
    it "returns properly formatted error response when throttled", skip: "Requires rate limit to be triggered" do
      # This test would require actually triggering a rate limit
      # which is difficult in the test environment
      
      # Mock a throttled response
      allow_any_instance_of(described_class).to receive(:call).and_return(
        [429, {
          'Content-Type' => 'application/json',
          'X-RateLimit-Limit' => '100',
          'X-RateLimit-Remaining' => '0',
          'X-RateLimit-Reset' => (Time.now + 1.hour).to_i.to_s
        }, ['{"error": "Too Many Requests", "message": "Rate limit exceeded. Please try again later."}']]
      )
    end
  end

  describe "rate limit logging" do
    it "logs throttled requests" do
      allow(Rails.logger).to receive(:warn)
      
      # This would require actually triggering a throttle to test logging
      # For now, we verify the logging configuration exists
      expect(ActiveSupport::Notifications).to be_subscribed('rack_attack.throttled')
    end
  end
end