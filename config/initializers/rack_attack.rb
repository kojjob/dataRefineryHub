# frozen_string_literal: true

# Enhanced Rack::Attack configuration for comprehensive rate limiting and security
# Prevents abuse, DoS attacks, and various security threats

# Skip all Rack::Attack configuration in test environment
unless Rails.env.test?
  class Rack::Attack
  ### Configure Cache ###
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  ### Safelist Configuration ###

  # Disable rate limiting in test environment
  if Rails.env.test?
    Rack::Attack.safelist("allow-all-in-test") do |req|
      true
    end
  end

  # Always allow requests from localhost in development
  if Rails.env.development?
    Rack::Attack.safelist("allow-localhost") do |req|
      req.ip == "127.0.0.1" || req.ip == "::1"
    end
  end

  # Allow health check endpoints
  Rack::Attack.safelist("allow-health-checks") do |req|
    req.path.match?(%r{^/(health|alive|ready)}) || req.path.start_with?("/assets")
  end

  ### Blocklist Configuration ###

  # Block requests with suspicious user agents
  Rack::Attack.blocklist("block-bad-agents") do |req|
    bad_agents = [
      /masscan/i, /nikto/i, /sqlmap/i, /benchmark/i, /havij/i,
      /acunetix/i, /nessus/i, /metasploit/i, /burpsuite/i, /zaproxy/i
    ]

    user_agent = req.user_agent.to_s
    bad_agents.any? { |pattern| user_agent.match?(pattern) } ||
    # Block generic bots but allow legitimate crawlers
    (req.user_agent.to_s.match?(/bot|crawler|spider/i) &&
     !req.user_agent.to_s.match?(/googlebot|bingbot|facebookexternalhit/i))
  end

  # Block requests trying to access sensitive files
  Rack::Attack.blocklist("block-sensitive-files") do |req|
    sensitive_paths = [
      /\/\.env/, /\/\.git/, /\/config\/database\.yml/,
      /\/config\/credentials/, /\/config\/master\.key/,
      /wp-admin/, /wp-login/, /phpmyadmin/, /admin\.php/
    ]

    sensitive_paths.any? { |pattern| req.path.match?(pattern) }
  end

  # Block requests with SQL injection patterns
  Rack::Attack.blocklist("block-sql-injection") do |req|
    req.query_string.match?(/(\%27)|(\')|(\-\-)|(\%23)|(#)/i) ||
      req.query_string.match?(/(union|select|insert|drop|update|delete|exec|script)/i)
  end

  # Block requests with XSS patterns
  Rack::Attack.blocklist("block-xss") do |req|
    req.query_string.match?(/<script|javascript:|onerror=|onload=/i)
  end

  ### Throttle Configurations ###

  # General rate limiting by IP
  Rack::Attack.throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?("/assets", "/health")
  end

  # API rate limiting by IP
  Rack::Attack.throttle("api/ip", limit: 300, period: 5.minutes) do |req|
    req.ip if req.path.start_with?("/api")
  end

  # API rate limiting by user (more generous for authenticated users)
  Rack::Attack.throttle("api/user", limit: 1000, period: 1.hour) do |req|
    if req.path.start_with?("/api") && req.env["warden"]&.user
      req.env["warden"].user.id
    end
  end

  ### Authentication & Security Endpoints ###

  # Login attempts by IP
  Rack::Attack.throttle("logins/ip", limit: 5, period: 20.seconds) do |req|
    if req.path == "/users/sign_in" && req.post?
      req.ip
    end
  end

  # Login attempts by email
  Rack::Attack.throttle("logins/email", limit: 5, period: 20.seconds) do |req|
    if req.path == "/users/sign_in" && req.post?
      req.params.dig("user", "email").to_s.downcase.presence
    end
  end

  # Password reset requests by IP
  Rack::Attack.throttle("password_reset/ip", limit: 5, period: 1.hour) do |req|
    if req.path == "/users/password" && req.post?
      req.ip
    end
  end

  # Password reset requests by email
  Rack::Attack.throttle("password_reset/email", limit: 3, period: 1.hour) do |req|
    if req.path == "/users/password" && req.post?
      req.params.dig("user", "email").to_s.downcase.presence
    end
  end

  # Sign up attempts
  Rack::Attack.throttle("signup/ip", limit: 3, period: 1.hour) do |req|
    if req.path == "/users" && req.post?
      req.ip
    end
  end

  ### Application-Specific Endpoints ###

  # ETL pipeline operations (expensive operations)
  Rack::Attack.throttle("etl/ip", limit: 10, period: 1.minute) do |req|
    if req.path.match?(/etl_pipeline_builders.*\/(execute|test)/) && req.post?
      req.ip
    end
  end

  # File upload endpoints by IP
  Rack::Attack.throttle("uploads/ip", limit: 10, period: 5.minutes) do |req|
    if req.post? && req.path.match?(/upload|import/)
      req.ip
    end
  end

  # File upload endpoints by user
  Rack::Attack.throttle("uploads/user", limit: 20, period: 10.minutes) do |req|
    if req.path.match?(/upload|import/) && req.post? && req.env["warden"]&.user
      req.env["warden"].user.id
    end
  end

  # Data export operations
  Rack::Attack.throttle("exports/ip", limit: 5, period: 10.minutes) do |req|
    if req.path.match?(/export|download/) && req.get?
      req.ip
    end
  end

  # Heavy endpoints (reports, exports) by user
  Rack::Attack.throttle("heavy_endpoints/user", limit: 10, period: 5.minutes) do |req|
    if req.path.match?(/export|report|download/) && req.env["warden"]&.user
      req.env["warden"].user.id
    end
  end

  # Search endpoints
  Rack::Attack.throttle("search/ip", limit: 30, period: 1.minute) do |req|
    if req.path.match?(/search/) && req.get?
      req.ip
    end
  end

  ### Notification System Security (SECURITY HOTFIX) ###

  # Specific rate limits for notification endpoints
  Rack::Attack.throttle("notifications_per_user", limit: 200, period: 1.hour) do |req|
    if req.path.start_with?("/api/v1/notifications") && req.env["warden"]&.user
      req.env["warden"].user.id
    end
  end

  # Limit notification marking operations (prevent abuse)
  Rack::Attack.throttle("notification_mark_operations", limit: 100, period: 10.minutes) do |req|
    if (req.path.match?(%r{/api/v1/notifications/.*/mark_as_(read|unread)$}) ||
        req.path == "/api/v1/notifications/mark_all_as_read") && req.env["warden"]&.user
      req.env["warden"].user.id
    end
  end

  # Limit notification deletion (prevent mass deletion abuse)
  Rack::Attack.throttle("notification_deletions", limit: 50, period: 1.hour) do |req|
    if req.path.match?(%r{/api/v1/notifications/\d+$}) && req.delete? && req.env["warden"]&.user
      req.env["warden"].user.id
    end
  end

  ### Failed Attempts Tracking ###

  # Track failed login attempts for exponential backoff
  Rack::Attack.track("login_attempts") do |req|
    if req.path == "/users/sign_in" && req.post?
      req.env["rack.attack.login_track"] = true
      req.ip
    end
  end

  # Track suspicious activity (but don't block yet)
  Rack::Attack.track("suspicious-activity") do |req|
    # Track requests to non-existent routes that might indicate scanning
    req.path.match?(/\.(php|asp|aspx|jsp|cgi)$/)
  end

  ### Custom Response Configuration ###

  # Customize throttled response
  Rack::Attack.throttled_responder = lambda do |env|
    matched = env["rack.attack.matched"]
    now = Time.now.to_i
    match_data = env["rack.attack.match_data"]

    # Calculate retry time
    retry_after = match_data[:period] - (now % match_data[:period])

    # Log the throttle
    Rails.logger.info "Rack::Attack throttled request from #{env['REMOTE_ADDR']} - Rule: #{matched}"

    [
      429,
      {
        "Content-Type" => "application/json",
        "Retry-After" => retry_after.to_s,
        "X-RateLimit-Limit" => match_data[:limit].to_s,
        "X-RateLimit-Remaining" => "0",
        "X-RateLimit-Reset" => (now + retry_after).to_s
      },
      [ {
        error: "Rate Limited",
        message: "You have exceeded the rate limit for #{matched}.",
        retry_after: retry_after,
        limit: match_data[:limit],
        period: match_data[:period]
      }.to_json ]
    ]
  end

  # Customize blocked response
  Rack::Attack.blocklisted_responder = lambda do |env|
    matched = env["rack.attack.matched"]

    # Log the attack
    Rails.logger.warn "Rack::Attack blocked request from #{env['REMOTE_ADDR']} - Rule: #{matched}"

    [
      403,
      {
        "Content-Type" => "application/json",
        "Retry-After" => "3600"
      },
      [ {
        error: "Forbidden",
        message: "Your request has been blocked for security reasons.",
        rule: matched
      }.to_json ]
    ]
  end
  end

  ### Notification Subscriptions ###

# Log blocked and throttled requests
ActiveSupport::Notifications.subscribe(/rack_attack/) do |name, start, finish, request_id, payload|
  req = payload[:request]

  case name
  when "rack_attack.throttled"
    Rails.logger.warn "[Rack::Attack] Throttled request from #{req.ip} to #{req.path}"
  when "rack_attack.blocklisted"
    Rails.logger.error "[Rack::Attack] Blocked request from #{req.ip} to #{req.path}"
  when "rack_attack.track"
    Rails.logger.info "[Rack::Attack] Suspicious activity from #{req.ip} to #{req.path}"
  end
end

  # Enable enhanced monitoring
  ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |name, start, finish, request_id, payload|
    Rails.logger.warn "Rate limit hit: #{payload[:request].env['rack.attack.matched']} for IP: #{payload[:request].ip}"
  end

  ActiveSupport::Notifications.subscribe("blocklist.rack_attack") do |name, start, finish, request_id, payload|
    Rails.logger.error "Blocked request: #{payload[:request].env['rack.attack.matched']} for IP: #{payload[:request].ip}"
  end

  # Note: Rack::Attack middleware is loaded in config/application.rb
end
