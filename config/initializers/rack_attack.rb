# Rack::Attack configuration for rate limiting and security
# Prevents abuse and DoS attacks

class Rack::Attack
  # Configure cache store (uses Rails cache by default)
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  
  # Safelist: Always allow requests from localhost in development
  safelist('allow-localhost') do |req|
    Rails.env.development? && (req.ip == '127.0.0.1' || req.ip == '::1')
  end
  
  # Blocklist: Block suspicious requests
  
  # Block requests with suspicious user agents
  blocklist('bad-user-agents') do |req|
    # List of known bad user agents
    bad_agents = [
      /masscan/i,
      /nikto/i,
      /sqlmap/i,
      /benchmark/i,
      /havij/i,
      /acunetix/i,
      /nessus/i,
      /metasploit/i
    ]
    
    user_agent = req.user_agent.to_s
    bad_agents.any? { |pattern| user_agent.match?(pattern) }
  end
  
  # Block requests trying to access sensitive files
  blocklist('sensitive-files') do |req|
    sensitive_paths = [
      /\/\.env/,
      /\/\.git/,
      /\/config\/database\.yml/,
      /\/config\/credentials/,
      /\/config\/master\.key/,
      /wp-admin/,
      /wp-login/,
      /phpmyadmin/
    ]
    
    sensitive_paths.any? { |pattern| req.path.match?(pattern) }
  end
  
  # Throttle: Rate limiting rules
  
  # Limit all requests by IP (300 requests per 5 minutes)
  throttle('req/ip', limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?('/assets', '/health')
  end
  
  # Stricter limits for authentication endpoints
  throttle('logins/ip', limit: 5, period: 20.seconds) do |req|
    if req.path == '/users/sign_in' && req.post?
      req.ip
    end
  end
  
  throttle('logins/email', limit: 5, period: 20.seconds) do |req|
    if req.path == '/users/sign_in' && req.post?
      # Return the email if present in params
      req.params.dig('user', 'email').to_s.downcase.presence
    end
  end
  
  # Limit password reset requests
  throttle('password-reset/ip', limit: 5, period: 1.hour) do |req|
    if req.path == '/users/password' && req.post?
      req.ip
    end
  end
  
  throttle('password-reset/email', limit: 3, period: 1.hour) do |req|
    if req.path == '/users/password' && req.post?
      req.params.dig('user', 'email').to_s.downcase.presence
    end
  end
  
  # API rate limiting (100 requests per minute per API key)
  throttle('api/key', limit: 100, period: 1.minute) do |req|
    if req.path.start_with?('/api/')
      # Extract API key from header or params
      req.get_header('HTTP_X_API_KEY') || 
      req.params['api_key'] ||
      req.get_header('HTTP_AUTHORIZATION')&.gsub('Bearer ', '')
    end
  end
  
  # Limit ETL pipeline operations (expensive operations)
  throttle('etl/ip', limit: 10, period: 1.minute) do |req|
    if req.path.match?(/etl_pipeline_builders.*\/(execute|test)/) && req.post?
      req.ip
    end
  end
  
  # Limit file uploads
  throttle('uploads/ip', limit: 10, period: 5.minutes) do |req|
    if req.post? && req.path.match?(/upload|import/)
      req.ip
    end
  end
  
  # Limit data export operations
  throttle('exports/ip', limit: 5, period: 10.minutes) do |req|
    if req.path.match?(/export|download/) && req.get?
      req.ip
    end
  end

  # Throttle API requests by user
  throttle('api_requests_per_user', limit: 1000, period: 1.hour) do |req|
    if req.path.start_with?('/api/')
      req.env['warden']&.user&.id
    end
  end

  # Specific rate limits for notification endpoints
  throttle('notifications_per_user', limit: 200, period: 1.hour) do |req|
    if req.path.start_with?('/api/v1/notifications')
      req.env['warden']&.user&.id
    end
  end

  # Limit notification marking operations (prevent abuse)
  throttle('notification_mark_operations', limit: 100, period: 10.minutes) do |req|
    if req.path.match?(%r{/api/v1/notifications/.*/mark_as_(read|unread)$}) ||
       req.path == '/api/v1/notifications/mark_all_as_read'
      req.env['warden']&.user&.id
    end
  end

  # Limit notification deletion (prevent mass deletion abuse)
  throttle('notification_deletions', limit: 50, period: 1.hour) do |req|
    if req.path.match?(%r{/api/v1/notifications/\d+$}) && req.delete?
      req.env['warden']&.user&.id
    end
  end
  
  # Custom response for rate limited requests
  self.throttled_responder = lambda do |req|
    now = Time.now
    match_data = req.env['rack.attack.match_data']
    
    headers = {
      'Content-Type' => 'application/json',
      'X-RateLimit-Limit' => match_data[:limit].to_s,
      'X-RateLimit-Remaining' => '0',
      'X-RateLimit-Reset' => (now + (match_data[:period] - (now.to_i % match_data[:period]))).to_s
    }
    
    message = {
      error: 'Too Many Requests',
      message: 'Rate limit exceeded. Please try again later.',
      retry_after: headers['X-RateLimit-Reset']
    }
    
    [429, headers, [message.to_json]]
  end
  
  # Custom response for blocked requests
  self.blocklisted_responder = lambda do |req|
    headers = {
      'Content-Type' => 'application/json'
    }
    
    message = {
      error: 'Forbidden',
      message: 'Your request has been blocked for security reasons.'
    }
    
    [403, headers, [message.to_json]]
  end
  
  # Track suspicious activity (but don't block yet)
  track('suspicious-activity') do |req|
    # Track requests to non-existent routes that might indicate scanning
    req.path.match?(/\.(php|asp|aspx|jsp|cgi)$/)
  end
  
  # Log blocked and throttled requests
  ActiveSupport::Notifications.subscribe(/rack_attack/) do |name, start, finish, request_id, payload|
    req = payload[:request]
    
    case name
    when 'rack_attack.throttled'
      Rails.logger.warn "[Rack::Attack] Throttled request from #{req.ip} to #{req.path}"
    when 'rack_attack.blocklisted'
      Rails.logger.error "[Rack::Attack] Blocked request from #{req.ip} to #{req.path}"
    when 'rack_attack.track'
      Rails.logger.info "[Rack::Attack] Suspicious activity from #{req.ip} to #{req.path}"
    end
  end
end

# Enable Rack::Attack
Rails.application.config.middleware.use Rack::Attack