# frozen_string_literal: true

# Enhanced rate limiting configuration for security
class Rack::Attack
  ### Configure Cache ###
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  ### Throttle Configurations ###

  # General API rate limiting
  throttle('api/ip', limit: 300, period: 5.minutes) do |req|
    req.ip if req.path.start_with?('/api')
  end

  # Strict limit per user
  throttle('api/user', limit: 100, period: 1.minute) do |req|
    if req.path.start_with?('/api') && req.env['warden'].user
      req.env['warden'].user.id
    end
  end

  # Login attempts by IP
  throttle('logins/ip', limit: 5, period: 20.seconds) do |req|
    if req.path == '/users/sign_in' && req.post?
      req.ip
    end
  end

  # Login attempts by email
  throttle('logins/email', limit: 5, period: 20.seconds) do |req|
    if req.path == '/users/sign_in' && req.post?
      req.params['user']['email'].to_s.downcase.presence
    end
  end

  # Password reset requests
  throttle('password_reset/ip', limit: 5, period: 1.hour) do |req|
    if req.path == '/users/password' && req.post?
      req.ip
    end
  end

  # Sign up attempts
  throttle('signup/ip', limit: 3, period: 1.hour) do |req|
    if req.path == '/users' && req.post?
      req.ip
    end
  end

  # Data upload endpoints
  throttle('uploads/user', limit: 10, period: 10.minutes) do |req|
    if req.path.match?(/upload|import/) && req.post? && req.env['warden'].user
      req.env['warden'].user.id
    end
  end

  # Heavy endpoints (reports, exports)
  throttle('heavy_endpoints/user', limit: 5, period: 5.minutes) do |req|
    if req.path.match?(/export|report|download/) && req.env['warden'].user
      req.env['warden'].user.id
    end
  end

  # Search endpoints
  throttle('search/ip', limit: 30, period: 1.minute) do |req|
    if req.path.match?(/search/) && req.get?
      req.ip
    end
  end

  ### Safelist Configuration ###
  
  # Always allow requests from localhost in development
  if Rails.env.development?
    Rack::Attack.safelist('allow-localhost') do |req|
      req.ip == '127.0.0.1' || req.ip == '::1'
    end
  end

  # Allow health check endpoints
  Rack::Attack.safelist('allow-health-checks') do |req|
    req.path.match?(%r{^/(health|alive|ready)})
  end

  ### Blocklist Configuration ###

  # Block suspicious requests
  Rack::Attack.blocklist('block-bad-agents') do |req|
    # Block requests with suspicious user agents
    req.user_agent.to_s.match?(/bot|crawler|spider/i) && 
      !req.user_agent.to_s.match?(/googlebot|bingbot/i)
  end

  # Block requests with SQL injection patterns
  Rack::Attack.blocklist('block-sql-injection') do |req|
    req.query_string.match?(/(\%27)|(\')|(\-\-)|(\%23)|(#)/i) ||
      req.query_string.match?(/(union|select|insert|drop|update|delete|exec|script)/i)
  end

  # Block requests with XSS patterns
  Rack::Attack.blocklist('block-xss') do |req|
    req.query_string.match?(/<script|javascript:|onerror=|onload=/i)
  end

  ### Failed Attempts Tracking ###

  # Track failed login attempts
  Rack::Attack.track('login_attempts') do |req|
    if req.path == '/users/sign_in' && req.post?
      # Track if response is unauthorized
      req.env['rack.attack.login_track'] = true
      req.ip
    end
  end

  # Exponential backoff for repeated failures
  Rack::Attack.blocklist('block-repeated-failures') do |req|
    Rack::Attack::Allow2Ban.filter(req.ip, maxretry: 10, findtime: 10.minutes, bantime: 1.hour) do
      req.env['rack.attack.login_track'] && req.env['warden'].result == :failure
    end
  end

  ### Custom Response ###

  # Customize blocked response
  Rack::Attack.blocklisted_responder = lambda do |env|
    # Get matched rule
    matched = env['rack.attack.matched']
    
    # Log the attack
    Rails.logger.warn "Rack::Attack blocked request from #{env['REMOTE_ADDR']} - Rule: #{matched}"
    
    # Return appropriate response
    [
      429,
      {
        'Content-Type' => 'application/json',
        'Retry-After' => '3600'
      },
      [{ 
        error: 'Too Many Requests',
        message: 'Rate limit exceeded. Please try again later.',
        retry_after: 3600
      }.to_json]
    ]
  end

  # Customize throttled response
  Rack::Attack.throttled_responder = lambda do |env|
    matched = env['rack.attack.matched']
    now = Time.now.to_i
    match_data = env['rack.attack.match_data']
    
    # Calculate retry time
    retry_after = match_data[:period] - (now % match_data[:period])
    
    # Log the throttle
    Rails.logger.info "Rack::Attack throttled request from #{env['REMOTE_ADDR']} - Rule: #{matched}"
    
    [
      429,
      {
        'Content-Type' => 'application/json',
        'Retry-After' => retry_after.to_s
      },
      [{
        error: 'Rate Limited',
        message: "You have exceeded the rate limit for #{matched}.",
        retry_after: retry_after,
        limit: match_data[:limit],
        period: match_data[:period]
      }.to_json]
    ]
  end
end

# Enable notifications for monitoring
ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |name, start, finish, request_id, payload|
  Rails.logger.warn "Rate limit hit: #{payload[:request].env['rack.attack.matched']} for IP: #{payload[:request].ip}"
end

ActiveSupport::Notifications.subscribe("blocklist.rack_attack") do |name, start, finish, request_id, payload|
  Rails.logger.error "Blocked request: #{payload[:request].env['rack.attack.matched']} for IP: #{payload[:request].ip}"
end
