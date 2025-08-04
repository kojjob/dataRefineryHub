# frozen_string_literal: true

# Middleware for comprehensive API rate limiting using Rails.cache (Solid Cache)
# Implements multiple strategies: sliding window, token bucket, and organization-based limits
class ApiRateLimiter
  # Rate limit configurations
  RATE_LIMITS = {
    # Public endpoints (no auth required)
    public: {
      requests_per_minute: 60,
      requests_per_hour: 1000,
      burst_size: 10
    },

    # Authenticated endpoints (with API key or JWT)
    authenticated: {
      requests_per_minute: 60,
      requests_per_hour: 1000,
      requests_per_day: 10_000,
      burst_size: 20
    },

    # Organization tier-based limits
    organization_tiers: {
      starter: {
        requests_per_minute: 60,
        requests_per_hour: 1000,
        requests_per_day: 10_000,
        concurrent_requests: 10
      },
      professional: {
        requests_per_minute: 300,
        requests_per_hour: 5000,
        requests_per_day: 50_000,
        concurrent_requests: 50
      },
      enterprise: {
        requests_per_minute: 1000,
        requests_per_hour: 20_000,
        requests_per_day: 200_000,
        concurrent_requests: 200
      }
    },

    # Endpoint-specific limits
    endpoints: {
      "/api/v1/data_sources/sync" => {
        requests_per_minute: 5,
        requests_per_hour: 50,
        cost_multiplier: 5
      },
      "/api/v1/analytics/generate" => {
        requests_per_minute: 10,
        requests_per_hour: 100,
        cost_multiplier: 3
      },
      "/api/v1/ai/query" => {
        requests_per_minute: 10,
        requests_per_hour: 100,
        cost_multiplier: 10
      }
    }
  }.freeze

  # Headers to include in rate limit responses
  RATE_LIMIT_HEADERS = {
    limit: "X-RateLimit-Limit",
    remaining: "X-RateLimit-Remaining",
    reset: "X-RateLimit-Reset",
    retry_after: "Retry-After"
  }.freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)

    # Skip rate limiting for internal health checks
    return @app.call(env) if skip_rate_limiting?(request)

    # Identify the request context
    context = identify_request_context(request)

    # Check concurrent request limits
    if exceeds_concurrent_limit?(context)
      return rate_limit_exceeded_response(request, context, "Concurrent request limit exceeded")
    end

    # Track concurrent request
    track_concurrent_request(context) do
      # Check rate limits
      rate_limit_check = check_rate_limits(request, context)

      if rate_limit_check[:limited]
        return rate_limit_exceeded_response(request, context, rate_limit_check[:reason])
      end

      # Add rate limit headers to response
      status, headers, response = @app.call(env)
      add_rate_limit_headers(headers, rate_limit_check[:limits])

      # Track successful request
      track_request(request, context)

      [ status, headers, response ]
    end
  rescue => e
    # If cache is down, allow the request but log the error
    Rails.logger.error "Rate limiter error: #{e.message}"
    @app.call(env)
  end

  private

  def skip_rate_limiting?(request)
    # Skip for health checks and internal endpoints
    request.path == "/health" ||
    request.path == "/metrics" ||
    request.path.start_with?("/rails/") ||
    # Skip for public landing page demo endpoints
    request.path.start_with?("/api/v1/public/") ||
    # Skip for landing page itself
    request.path == "/" ||
    Rails.env.test?
  end

  def identify_request_context(request)
    context = {
      ip: request.remote_ip,
      path: request.path,
      method: request.request_method
    }

    # Extract authentication information
    if request.headers["Authorization"]&.start_with?("Bearer ")
      context[:auth_type] = "jwt"
      context[:token] = request.headers["Authorization"].split(" ").last
      # Decode JWT to get user/org info (would need actual JWT decoding)
      context[:authenticated] = true
    elsif request.headers["X-API-Key"]
      context[:auth_type] = "api_key"
      context[:api_key] = request.headers["X-API-Key"]
      context[:authenticated] = true

      # Look up organization from API key
      if api_key = ApiKey.active.find_by(key: context[:api_key])
        context[:organization_id] = api_key.organization_id
        context[:organization_tier] = api_key.organization.subscription_tier
      end
    else
      context[:authenticated] = false
    end

    context
  end

  def exceeds_concurrent_limit?(context)
    return false unless context[:authenticated] && context[:organization_id]

    tier = context[:organization_tier] || "starter"
    limit = RATE_LIMITS[:organization_tiers][tier.to_sym][:concurrent_requests]

    key = "concurrent:#{context[:organization_id]}"
    current_count = Rails.cache.read(key).to_i
    current_count >= limit
  end

  def track_concurrent_request(context)
    if context[:authenticated] && context[:organization_id]
      key = "concurrent:#{context[:organization_id]}"

      # Increment concurrent count
      Rails.cache.increment(key, 1, expires_in: 5.minutes)

      begin
        yield
      ensure
        # Decrement concurrent count
        Rails.cache.decrement(key, 1)
      end
    else
      yield
    end
  end

  def check_rate_limits(request, context)
    limits = get_applicable_limits(request, context)
    results = {}

    # Check each time window
    [ :minute, :hour, :day ].each do |window|
      next unless limits["requests_per_#{window}".to_sym]

      key = rate_limit_key(context, window)
      current_count = Rails.cache.read(key).to_i
      limit = limits["requests_per_#{window}".to_sym]

      results[window] = {
        current: current_count,
        limit: limit,
        remaining: [ limit - current_count, 0 ].max,
        reset_at: reset_time(window)
      }

      if current_count >= limit
        return {
          limited: true,
          reason: "Rate limit exceeded: #{limit} requests per #{window}",
          limits: results
        }
      end
    end

    # Check burst limits using token bucket
    if limits[:burst_size]
      burst_check = check_burst_limit(context, limits[:burst_size])
      if burst_check[:limited]
        return burst_check.merge(limits: results)
      end
    end

    { limited: false, limits: results }
  end

  def get_applicable_limits(request, context)
    # Start with base limits
    limits = if context[:authenticated]
      RATE_LIMITS[:authenticated].dup
    else
      RATE_LIMITS[:public].dup
    end

    # Apply organization tier limits if available
    if context[:organization_tier]
      tier_limits = RATE_LIMITS[:organization_tiers][context[:organization_tier].to_sym]
      limits.merge!(tier_limits) if tier_limits
    end

    # Apply endpoint-specific limits
    endpoint_limits = RATE_LIMITS[:endpoints][request.path]
    if endpoint_limits
      # Use the more restrictive limit
      endpoint_limits.each do |key, value|
        if limits[key].nil? || value < limits[key]
          limits[key] = value
        end
      end
    end

    limits
  end

  def check_burst_limit(context, burst_size)
    key = "burst:#{context_key(context)}"
    tokens_key = "#{key}:tokens"
    last_refill_key = "#{key}:last_refill"

    # Get current tokens
    tokens = Rails.cache.read(tokens_key).to_i
    last_refill = Rails.cache.read(last_refill_key).to_i
    now = Time.now.to_i

    # Refill tokens (1 token per second up to burst_size)
    if last_refill > 0
      elapsed = now - last_refill
      tokens = [ tokens + elapsed, burst_size ].min
    else
      tokens = burst_size
    end

    # Check if request can proceed
    if tokens > 0
      Rails.cache.write(tokens_key, tokens - 1, expires_in: 1.hour)
      Rails.cache.write(last_refill_key, now, expires_in: 1.hour)

      { limited: false }
    else
      {
        limited: true,
        reason: "Burst limit exceeded. Please slow down your requests."
      }
    end
  end

  def track_request(request, context)
    # Track request counts for each window
    [ :minute, :hour, :day ].each do |window|
      key = rate_limit_key(context, window)
      Rails.cache.increment(key, 1, expires_in: window_duration(window))
    end

    # Track metrics for monitoring
    track_metrics(request, context)
  end

  def track_metrics(request, context)
    # Track request metrics for monitoring/alerting
    metric_key = "api_metrics:#{Date.today}:#{context[:organization_id] || 'anonymous'}"

    # Increment counters in cache
    Rails.cache.increment("#{metric_key}:total_requests", 1, expires_in: 7.days)
    Rails.cache.increment("#{metric_key}:#{request.request_method}_requests", 1, expires_in: 7.days)
    Rails.cache.increment("#{metric_key}:endpoint:#{request.path}", 1, expires_in: 7.days)

    # Track rate limit approaches
    if context[:authenticated] && context[:organization_id]
      check_rate_limit_warnings(context)
    end
  end

  def check_rate_limit_warnings(context)
    # Check if organization is approaching limits
    limits = get_applicable_limits(nil, context)

    [ :hour, :day ].each do |window|
      next unless limits["requests_per_#{window}".to_sym]

      key = rate_limit_key(context, window)
      current = Rails.cache.read(key).to_i
      limit = limits["requests_per_#{window}".to_sym]

      if current > limit * 0.8 && !warning_sent?(context, window)
        send_rate_limit_warning(context, window, current, limit)
      end
    end
  end

  def warning_sent?(context, window)
    key = "rate_limit_warning:#{context[:organization_id]}:#{window}:#{Date.today}"
    Rails.cache.exist?(key)
  end

  def send_rate_limit_warning(context, window, current, limit)
    # Queue job to send warning email
    RateLimitWarningJob.perform_later(
      organization_id: context[:organization_id],
      window: window,
      current_usage: current,
      limit: limit
    )

    # Mark warning as sent
    key = "rate_limit_warning:#{context[:organization_id]}:#{window}:#{Date.today}"
    Rails.cache.write(key, true, expires_in: 1.day)
  end

  def rate_limit_key(context, window)
    identifier = context_key(context)
    time_component = time_window_component(window)

    "rate_limit:#{identifier}:#{window}:#{time_component}"
  end

  def context_key(context)
    if context[:authenticated]
      if context[:organization_id]
        "org:#{context[:organization_id]}"
      elsif context[:api_key]
        "key:#{context[:api_key]}"
      else
        "auth:#{context[:ip]}"
      end
    else
      "ip:#{context[:ip]}"
    end
  end

  def time_window_component(window)
    case window
    when :minute
      Time.now.strftime("%Y%m%d%H%M")
    when :hour
      Time.now.strftime("%Y%m%d%H")
    when :day
      Time.now.strftime("%Y%m%d")
    end
  end

  def window_duration(window)
    case window
    when :minute
      60
    when :hour
      3600
    when :day
      86400
    end
  end

  def reset_time(window)
    case window
    when :minute
      Time.now.beginning_of_minute + 1.minute
    when :hour
      Time.now.beginning_of_hour + 1.hour
    when :day
      Time.now.beginning_of_day + 1.day
    end.to_i
  end

  def add_rate_limit_headers(headers, limits)
    # Use the most restrictive limit for headers
    primary_limit = limits[:hour] || limits[:minute] || limits[:day]
    return unless primary_limit

    headers[RATE_LIMIT_HEADERS[:limit]] = primary_limit[:limit].to_s
    headers[RATE_LIMIT_HEADERS[:remaining]] = primary_limit[:remaining].to_s
    headers[RATE_LIMIT_HEADERS[:reset]] = primary_limit[:reset_at].to_s
  end

  def rate_limit_exceeded_response(request, context, reason)
    # Find the next reset time
    limits = get_applicable_limits(request, context)
    next_reset = nil

    [ :minute, :hour, :day ].each do |window|
      if limits["requests_per_#{window}".to_sym]
        reset = reset_time(window)
        next_reset = reset if next_reset.nil? || reset < next_reset
      end
    end

    retry_after = next_reset ? next_reset - Time.now.to_i : 60

    headers = {
      "Content-Type" => "application/json",
      RATE_LIMIT_HEADERS[:retry_after] => retry_after.to_s,
      RATE_LIMIT_HEADERS[:reset] => next_reset.to_s
    }

    body = {
      error: {
        message: reason,
        code: "rate_limit_exceeded",
        retry_after: retry_after,
        reset_at: next_reset
      }
    }.to_json

    [ 429, headers, [ body ] ]
  end
end
