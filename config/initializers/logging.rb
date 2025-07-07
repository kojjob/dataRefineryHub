# frozen_string_literal: true

# Configure Rails logging for structured logs
Rails.application.configure do
  # Use JSON formatter for production
  if Rails.env.production?
    config.log_formatter = proc do |severity, datetime, progname, msg|
      {
        timestamp: datetime.iso8601,
        severity: severity,
        progname: progname,
        message: msg,
        environment: Rails.env,
        host: Socket.gethostname
      }.to_json + "\n"
    end
  end

  # Configure log level
  config.log_level = ENV.fetch("LOG_LEVEL", "info").to_sym

  # Log tags for request tracking
  config.log_tags = [ :request_id, :remote_ip ]

  # Enable query logging in development
  if Rails.env.development?
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    # verbose_query_logs is not available in Rails 8
    # Query logging is handled differently now
  end

  # Silence noisy logs
  config.active_record.logger = nil if Rails.env.test?

  # Configure Solid Queue logging
  if defined?(SolidQueue)
    SolidQueue.logger = Rails.logger
  end
end

# Monkey patch ActiveSupport::Notifications to add structured logging
ActiveSupport::Notifications.subscribe("sql.active_record") do |name, start, finish, id, payload|
  duration = (finish - start) * 1000

  # Log slow queries
  if duration > 100 # More than 100ms
    structured_logger.warn("Slow database query detected",
      query: payload[:sql],
      duration_ms: duration.round(2),
      name: payload[:name],
      binds: payload[:binds]&.map { |b| [ b.name, b.value ] }.to_h
    )

    MetricsService.increment("database.queries.slow", tags: {
      operation: payload[:name] || "unknown"
    })
  end
end

# Subscribe to cache events
ActiveSupport::Notifications.subscribe(/cache_(read|write|delete|exist?)\.active_support/) do |name, start, finish, id, payload|
  duration = (finish - start) * 1000
  operation = name.split(".").first.split("_").last

  MetricsService.histogram("cache.operation.duration", duration, tags: {
    operation: operation,
    hit: payload[:hit] ? "hit" : "miss"
  })
end

# Subscribe to view rendering events
ActiveSupport::Notifications.subscribe("render_template.action_view") do |name, start, finish, id, payload|
  duration = (finish - start) * 1000

  if duration > 500 # More than 500ms
    structured_logger.warn("Slow view rendering detected",
      template: payload[:identifier],
      duration_ms: duration.round(2)
    )
  end
end

# Add request store middleware for request-scoped data
Rails.application.config.middleware.insert_after ActionDispatch::RequestId, RequestStore::Middleware
