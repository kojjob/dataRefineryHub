# frozen_string_literal: true

# Service for structured logging with consistent format and metadata
class StructuredLogger
  SENSITIVE_FIELDS = %w[
    password password_confirmation token api_key secret_key
    access_token refresh_token credit_card ssn email phone
    credentials authorization
  ].freeze

  SEVERITY_LEVELS = {
    debug: 0,
    info: 1,
    warn: 2,
    error: 3,
    fatal: 4
  }.freeze

  attr_reader :logger, :context

  def initialize(context = {})
    @logger = Rails.logger
    @context = default_context.merge(context)
  end

  # Log methods for different severity levels
  def debug(message, metadata = {})
    log(:debug, message, metadata)
  end

  def info(message, metadata = {})
    log(:info, message, metadata)
  end

  def warn(message, metadata = {})
    log(:warn, message, metadata)
  end

  def error(message, error = nil, metadata = {})
    if error.is_a?(Hash)
      metadata = error
      error = nil
    end

    metadata[:error] = format_error(error) if error
    log(:error, message, metadata)
  end

  def fatal(message, error = nil, metadata = {})
    if error.is_a?(Hash)
      metadata = error
      error = nil
    end

    metadata[:error] = format_error(error) if error
    log(:fatal, message, metadata)
  end

  # Log with custom tags
  def tagged(*tags)
    logger.tagged(*tags) do
      yield self
    end
  end

  # Add context that persists for the logger instance
  def with_context(additional_context)
    self.class.new(context.merge(additional_context))
  end

  # Log a block with timing
  def measure(message, metadata = {})
    start_time = Time.current
    result = nil

    begin
      info("#{message} started", metadata.merge(status: "started"))
      result = yield

      duration = (Time.current - start_time) * 1000 # Convert to milliseconds
      info("#{message} completed", metadata.merge(
        status: "completed",
        duration_ms: duration.round(2)
      ))

      result
    rescue => e
      duration = (Time.current - start_time) * 1000
      error("#{message} failed", e, metadata.merge(
        status: "failed",
        duration_ms: duration.round(2)
      ))
      raise
    end
  end

  # Log API requests
  def log_api_request(request, response = nil, duration_ms = nil)
    metadata = {
      request: {
        method: request.request_method,
        path: request.path,
        remote_ip: request.remote_ip,
        user_agent: request.user_agent,
        request_id: request.request_id
      }
    }

    if response
      metadata[:response] = {
        status: response.status,
        duration_ms: duration_ms
      }
    end

    info("API Request", metadata)
  end

  # Log background job execution
  def log_job_execution(job_class, job_id, status, metadata = {})
    base_metadata = {
      job: {
        class: job_class,
        id: job_id,
        status: status,
        queue: metadata[:queue]
      }
    }

    case status
    when "started"
      info("Job execution started", base_metadata.merge(metadata))
    when "completed"
      info("Job execution completed", base_metadata.merge(metadata))
    when "failed"
      error("Job execution failed", base_metadata.merge(metadata))
    when "retrying"
      warn("Job execution retrying", base_metadata.merge(metadata))
    end
  end

  # Log data pipeline events
  def log_pipeline_event(pipeline_id, event, metadata = {})
    base_metadata = {
      pipeline: {
        id: pipeline_id,
        event: event
      }
    }.merge(metadata)

    case event
    when "extraction_started", "transformation_started", "loading_started"
      info("Pipeline #{event.humanize}", base_metadata)
    when "extraction_completed", "transformation_completed", "loading_completed"
      info("Pipeline #{event.humanize}", base_metadata)
    when "extraction_failed", "transformation_failed", "loading_failed"
      error("Pipeline #{event.humanize}", base_metadata)
    else
      info("Pipeline event: #{event}", base_metadata)
    end
  end

  # Log security events
  def log_security_event(event_type, user_id = nil, metadata = {})
    base_metadata = {
      security: {
        event_type: event_type,
        user_id: user_id,
        ip_address: metadata[:ip_address],
        timestamp: Time.current.iso8601
      }
    }

    case event_type
    when "login_success", "logout"
      info("Security: #{event_type.humanize}", base_metadata.merge(metadata))
    when "login_failed", "unauthorized_access", "suspicious_activity"
      warn("Security: #{event_type.humanize}", base_metadata.merge(metadata))
    when "security_breach", "data_leak_attempt"
      error("Security: #{event_type.humanize}", base_metadata.merge(metadata))
    end
  end

  # Log performance metrics
  def log_performance(operation, duration_ms, metadata = {})
    performance_metadata = {
      performance: {
        operation: operation,
        duration_ms: duration_ms,
        timestamp: Time.current.iso8601
      }
    }.merge(metadata)

    if duration_ms > 1000 # Log as warning if operation takes more than 1 second
      warn("Slow operation detected", performance_metadata)
    else
      info("Performance metric", performance_metadata)
    end
  end

  private

  def log(severity, message, metadata = {})
    log_entry = build_log_entry(severity, message, metadata)

    # Send to Rails logger
    logger.send(severity, log_entry.to_json)

    # Send to metrics/monitoring service
    send_to_metrics(severity, message, metadata)
  end

  def build_log_entry(severity, message, metadata)
    {
      timestamp: Time.current.iso8601,
      severity: severity.to_s.upcase,
      message: message,
      context: context,
      metadata: sanitize_metadata(metadata),
      environment: Rails.env,
      host: Socket.gethostname,
      pid: Process.pid,
      thread_id: Thread.current.object_id
    }
  end

  def default_context
    {
      application: "data_refinery_platform",
      version: "1.0.0",
      deployment_id: ENV["DEPLOYMENT_ID"],
      request_id: RequestStore[:request_id]
    }
  end

  def sanitize_metadata(metadata)
    deep_sanitize(metadata)
  end

  def deep_sanitize(obj)
    case obj
    when Hash
      obj.each_with_object({}) do |(key, value), result|
        if SENSITIVE_FIELDS.any? { |field| key.to_s.downcase.include?(field) }
          result[key] = "[FILTERED]"
        else
          result[key] = deep_sanitize(value)
        end
      end
    when Array
      obj.map { |item| deep_sanitize(item) }
    else
      obj
    end
  end

  def format_error(error)
    {
      class: error.class.name,
      message: error.message,
      backtrace: clean_backtrace(error.backtrace)
    }
  end

  def clean_backtrace(backtrace)
    return [] unless backtrace

    # Only include app-specific lines and limit to 10 lines
    backtrace
      .select { |line| line.include?(Rails.root.to_s) }
      .first(10)
      .map { |line| line.sub(Rails.root.to_s + "/", "") }
  end

  def send_to_metrics(severity, message, metadata)
    # Integration with metrics service (e.g., Prometheus, DataDog)
    MetricsService.increment(
      "logs.count",
      tags: {
        severity: severity,
        component: metadata[:component] || "general"
      }
    )
  rescue => e
    # Don't let metrics failures affect logging
    Rails.logger.error("Failed to send metrics: #{e.message}")
  end
end
