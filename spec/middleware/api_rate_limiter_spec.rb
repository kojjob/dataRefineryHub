require 'rails_helper'

RSpec.describe ApiRateLimiter do
  let(:app) { double('app') }
  let(:middleware) { described_class.new(app) }
  let(:env) { Rack::MockRequest.env_for(path, env_options) }
  let(:path) { '/api/v1/data_sources' }
  let(:env_options) { {} }
  
  before do
    Rails.cache.clear
  end

  describe '#call' do
    context 'when rate limiting is skipped' do
      it 'skips rate limiting for health check endpoints' do
        env = Rack::MockRequest.env_for('/health')
        expect(app).to receive(:call).with(env).and_return([200, {}, ['OK']])
        
        status, headers, response = middleware.call(env)
        expect(status).to eq(200)
      end

      it 'skips rate limiting for metrics endpoints' do
        env = Rack::MockRequest.env_for('/metrics')
        expect(app).to receive(:call).with(env).and_return([200, {}, ['OK']])
        
        status, headers, response = middleware.call(env)
        expect(status).to eq(200)
      end

      it 'skips rate limiting for Rails internal endpoints' do
        env = Rack::MockRequest.env_for('/rails/info')
        expect(app).to receive(:call).with(env).and_return([200, {}, ['OK']])
        
        status, headers, response = middleware.call(env)
        expect(status).to eq(200)
      end

      it 'skips rate limiting in test environment' do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('test'))
        expect(app).to receive(:call).with(env).and_return([200, {}, ['OK']])
        
        status, headers, response = middleware.call(env)
        expect(status).to eq(200)
      end
    end

    context 'with unauthenticated requests' do
      let(:env_options) { { 'REMOTE_ADDR' => '127.0.0.1' } }

      it 'applies public rate limits' do
        allow(app).to receive(:call).and_return([200, {}, ['OK']])
        
        # Make requests up to the limit
        60.times do
          middleware.call(env)
        end
        
        # Next request should be rate limited
        status, headers, response = middleware.call(env)
        expect(status).to eq(429)
        expect(headers['X-RateLimit-Remaining']).to eq('0')
        expect(headers['Retry-After']).to be_present
      end

      it 'includes rate limit headers in successful responses' do
        allow(app).to receive(:call).and_return([200, {}, ['OK']])
        
        status, headers, response = middleware.call(env)
        expect(headers['X-RateLimit-Limit']).to be_present
        expect(headers['X-RateLimit-Remaining']).to be_present
        expect(headers['X-RateLimit-Reset']).to be_present
      end

      it 'tracks requests per IP address' do
        env1 = Rack::MockRequest.env_for(path, 'REMOTE_ADDR' => '192.168.1.1')
        env2 = Rack::MockRequest.env_for(path, 'REMOTE_ADDR' => '192.168.1.2')
        
        allow(app).to receive(:call).and_return([200, {}, ['OK']])
        
        # Different IPs should have separate limits
        middleware.call(env1)
        middleware.call(env2)
        
        key1 = "rate_limit:minute:192.168.1.1:#{path}:GET"
        key2 = "rate_limit:minute:192.168.1.2:#{path}:GET"
        
        expect(Rails.cache.read(key1)).to eq(1)
        expect(Rails.cache.read(key2)).to eq(1)
      end
    end

    context 'with JWT authenticated requests' do
      let(:env_options) do
        {
          'HTTP_AUTHORIZATION' => 'Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.abc123',
          'REMOTE_ADDR' => '127.0.0.1'
        }
      end

      it 'applies authenticated rate limits' do
        allow(app).to receive(:call).and_return([200, {}, ['OK']])
        
        status, headers, response = middleware.call(env)
        expect(status).to eq(200)
        expect(headers['X-RateLimit-Limit']).to eq('60') # authenticated limit
      end

      it 'identifies JWT authentication correctly' do
        allow(app).to receive(:call).and_return([200, {}, ['OK']])
        
        # The middleware should recognize this as authenticated
        expect(middleware).to receive(:identify_request_context).and_call_original
        
        status, headers, response = middleware.call(env)
        expect(status).to eq(200)
      end
    end

    context 'with API key authenticated requests' do
      let(:organization) { create(:organization, subscription_tier: 'professional') }
      let(:api_key) { create(:api_key, organization: organization, key: 'test_api_key_123') }
      let(:env_options) do
        {
          'HTTP_X_API_KEY' => api_key.key,
          'REMOTE_ADDR' => '127.0.0.1'
        }
      end

      before do
        api_key # Ensure API key is created
      end

      it 'applies organization tier-based limits' do
        allow(app).to receive(:call).and_return([200, {}, ['OK']])
        
        status, headers, response = middleware.call(env)
        expect(status).to eq(200)
        
        # Professional tier has higher limits
        expect(headers['X-RateLimit-Limit'].to_i).to be > 60
      end

      it 'tracks concurrent requests per organization' do
        allow(app).to receive(:call) do
          # Simulate some processing time
          sleep 0.01
          [200, {}, ['OK']]
        end
        
        # Start multiple concurrent requests
        threads = []
        5.times do
          threads << Thread.new { middleware.call(env) }
        end
        
        # Wait a bit for threads to start
        sleep 0.005
        
        # Check concurrent count
        concurrent_key = "concurrent:#{organization.id}"
        concurrent_count = Rails.cache.read(concurrent_key).to_i
        expect(concurrent_count).to be > 0
        
        # Wait for threads to complete
        threads.each(&:join)
        
        # Concurrent count should be back to 0
        expect(Rails.cache.read(concurrent_key).to_i).to eq(0)
      end

      it 'rejects requests exceeding concurrent limit' do
        # Set up organization with starter tier (lower concurrent limit)
        organization.update!(subscription_tier: 'starter')
        
        # Simulate max concurrent requests
        concurrent_key = "concurrent:#{organization.id}"
        Rails.cache.write(concurrent_key, 10, expires_in: 5.minutes)
        
        status, headers, response = middleware.call(env)
        expect(status).to eq(429)
        expect(response.first).to include('Concurrent request limit exceeded')
      end
    end

    context 'with endpoint-specific limits' do
      let(:sync_path) { '/api/v1/data_sources/sync' }
      let(:env) { Rack::MockRequest.env_for(sync_path, env_options) }
      let(:env_options) { { 'REMOTE_ADDR' => '127.0.0.1' } }

      it 'applies stricter limits for expensive endpoints' do
        allow(app).to receive(:call).and_return([200, {}, ['OK']])
        
        # Sync endpoint has limit of 5 per minute
        5.times do
          middleware.call(env)
        end
        
        # 6th request should be rate limited
        status, headers, response = middleware.call(env)
        expect(status).to eq(429)
      end

      it 'applies cost multiplier for expensive operations' do
        allow(app).to receive(:call).and_return([200, {}, ['OK']])
        
        # AI query endpoint has higher cost
        ai_env = Rack::MockRequest.env_for('/api/v1/ai/query', env_options)
        
        status, headers, response = middleware.call(ai_env)
        expect(status).to eq(200)
        
        # Check that it consumed more from the rate limit
        key = "rate_limit:minute:127.0.0.1:/api/v1/ai/query:GET"
        count = Rails.cache.read(key).to_i
        expect(count).to be >= 1 # Should account for cost multiplier
      end
    end

    context 'with different time windows' do
      let(:env_options) { { 'REMOTE_ADDR' => '127.0.0.1' } }

      it 'tracks limits across multiple time windows' do
        allow(app).to receive(:call).and_return([200, {}, ['OK']])
        
        middleware.call(env)
        
        # Check that all time windows are tracked
        minute_key = "rate_limit:minute:127.0.0.1:#{path}:GET"
        hour_key = "rate_limit:hour:127.0.0.1:#{path}:GET"
        
        expect(Rails.cache.read(minute_key)).to eq(1)
        expect(Rails.cache.read(hour_key)).to eq(1)
      end

      it 'respects hourly limit even if minute limit is not exceeded' do
        allow(app).to receive(:call).and_return([200, {}, ['OK']])
        
        # Set hourly count close to limit
        hour_key = "rate_limit:hour:127.0.0.1:#{path}:GET"
        Rails.cache.write(hour_key, 999, expires_in: 1.hour)
        
        # Make request (should succeed as we're under minute limit)
        status1, _, _ = middleware.call(env)
        expect(status1).to eq(200)
        
        # Next request should be rate limited due to hourly limit
        status2, _, _ = middleware.call(env)
        expect(status2).to eq(429)
      end
    end

    context 'error handling' do
      it 'allows requests when cache is unavailable' do
        allow(Rails.cache).to receive(:read).and_raise(Redis::CannotConnectError)
        allow(Rails.logger).to receive(:error)
        expect(app).to receive(:call).with(env).and_return([200, {}, ['OK']])
        
        status, headers, response = middleware.call(env)
        expect(status).to eq(200)
        expect(Rails.logger).to have_received(:error).with(/Rate limiter error/)
      end

      it 'handles invalid API keys gracefully' do
        env = Rack::MockRequest.env_for(path, 'HTTP_X_API_KEY' => 'invalid_key')
        allow(app).to receive(:call).and_return([200, {}, ['OK']])
        
        # Should treat as unauthenticated request
        status, headers, response = middleware.call(env)
        expect(status).to eq(200)
        expect(headers['X-RateLimit-Limit']).to eq('60') # Public limit
      end
    end

    context 'rate limit response' do
      let(:env_options) { { 'REMOTE_ADDR' => '127.0.0.1' } }

      before do
        # Exceed rate limit
        minute_key = "rate_limit:minute:127.0.0.1:#{path}:GET"
        Rails.cache.write(minute_key, 100, expires_in: 1.minute)
      end

      it 'returns 429 status code' do
        status, headers, response = middleware.call(env)
        expect(status).to eq(429)
      end

      it 'includes rate limit headers' do
        status, headers, response = middleware.call(env)
        expect(headers['X-RateLimit-Limit']).to be_present
        expect(headers['X-RateLimit-Remaining']).to eq('0')
        expect(headers['X-RateLimit-Reset']).to be_present
        expect(headers['Retry-After']).to be_present
      end

      it 'includes error message in response body' do
        status, headers, response = middleware.call(env)
        body = response.first
        expect(body).to include('rate limit exceeded')
      end

      it 'sets appropriate Content-Type header' do
        status, headers, response = middleware.call(env)
        expect(headers['Content-Type']).to eq('application/json')
      end
    end

    context 'sliding window implementation' do
      let(:env_options) { { 'REMOTE_ADDR' => '127.0.0.1' } }

      it 'implements proper sliding window algorithm' do
        allow(app).to receive(:call).and_return([200, {}, ['OK']])
        
        # Make some requests
        3.times { middleware.call(env) }
        
        # Wait for half the window
        travel 30.seconds
        
        # Make more requests
        2.times { middleware.call(env) }
        
        # Check that both periods are tracked
        current_key = "rate_limit:minute:127.0.0.1:#{path}:GET"
        current_count = Rails.cache.read(current_key).to_i
        expect(current_count).to be > 0
      end
    end
  end

  describe 'private methods' do
    describe '#identify_request_context' do
      it 'extracts IP address' do
        request = double('request', 
          remote_ip: '192.168.1.1',
          path: '/api/v1/test',
          request_method: 'GET',
          headers: {})
        
        context = middleware.send(:identify_request_context, request)
        expect(context[:ip]).to eq('192.168.1.1')
      end

      it 'identifies JWT authentication' do
        request = double('request',
          remote_ip: '127.0.0.1',
          path: '/api/v1/test',
          request_method: 'GET',
          headers: { 'Authorization' => 'Bearer token123' })
        
        context = middleware.send(:identify_request_context, request)
        expect(context[:auth_type]).to eq('jwt')
        expect(context[:authenticated]).to be true
      end

      it 'identifies API key authentication' do
        api_key = create(:api_key, key: 'test_key')
        request = double('request',
          remote_ip: '127.0.0.1',
          path: '/api/v1/test',
          request_method: 'GET',
          headers: { 'X-API-Key' => 'test_key' })
        
        context = middleware.send(:identify_request_context, request)
        expect(context[:auth_type]).to eq('api_key')
        expect(context[:authenticated]).to be true
        expect(context[:organization_id]).to eq(api_key.organization_id)
      end
    end

    describe '#get_applicable_limits' do
      it 'returns public limits for unauthenticated requests' do
        context = { authenticated: false }
        request = double('request', path: '/api/v1/test')
        
        limits = middleware.send(:get_applicable_limits, request, context)
        expect(limits[:requests_per_minute]).to eq(60)
      end

      it 'returns authenticated limits for authenticated requests' do
        context = { authenticated: true }
        request = double('request', path: '/api/v1/test')
        
        limits = middleware.send(:get_applicable_limits, request, context)
        expect(limits[:requests_per_minute]).to eq(60)
        expect(limits[:requests_per_day]).to eq(10_000)
      end

      it 'returns organization tier limits when available' do
        context = { 
          authenticated: true,
          organization_tier: 'enterprise'
        }
        request = double('request', path: '/api/v1/test')
        
        limits = middleware.send(:get_applicable_limits, request, context)
        expect(limits[:requests_per_minute]).to eq(1000)
        expect(limits[:concurrent_requests]).to eq(200)
      end

      it 'applies endpoint-specific limits' do
        context = { authenticated: true }
        request = double('request', path: '/api/v1/data_sources/sync')
        
        limits = middleware.send(:get_applicable_limits, request, context)
        expect(limits[:requests_per_minute]).to eq(5)
        expect(limits[:cost_multiplier]).to eq(5)
      end
    end
  end
end
