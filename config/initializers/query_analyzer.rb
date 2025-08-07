# frozen_string_literal: true

# Configure Query Analyzer for performance monitoring
if defined?(QueryAnalyzer)
  QueryAnalyzer.configure do |config|
    # Enable in development and staging
    config.enabled = Rails.env.development? || Rails.env.staging?
    
    # Set threshold for slow queries (in milliseconds)
    config.slow_query_threshold = Rails.env.production? ? 200 : 100
    
    # Use Rails logger
    config.logger = Rails.logger
  end

  # Add middleware for request-level analysis
  if Rails.env.development?
    Rails.application.config.middleware.use QueryAnalyzerMiddleware
  end
end

# Initialize CacheManager
if defined?(CacheManager)
  Rails.application.config.after_initialize do
    # Warm up cache with frequently accessed data
    if Rails.env.production?
      Rails.logger.info "Warming up cache..."
      CacheManager.warmup
    end
  end
end
