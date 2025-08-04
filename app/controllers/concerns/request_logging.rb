# frozen_string_literal: true

# Concern for structured request logging in controllers
module RequestLogging
  extend ActiveSupport::Concern

  included do
    around_action :log_request
    before_action :set_request_id
  end

  private

  def log_request
    start_time = Time.current
    request_logger = structured_logger.with_context(
      request_id: request.request_id,
      user_id: current_user&.id,
      organization_id: current_organization&.id,
      session_id: session.id
    )

    # Log request start
    request_logger.info("Request started",
      request: {
        method: request.method,
        path: request.path,
        remote_ip: request.remote_ip,
        user_agent: request.user_agent,
        params: filtered_params
      }
    )

    # Track metrics
    MetricsService.increment("api.requests.total", tags: {
      method: request.method,
      path: sanitize_path_for_metrics(request.path),
      controller: controller_name,
      action: action_name
    })

    begin
      yield

      # Log successful response
      duration_ms = (Time.current - start_time) * 1000
      request_logger.info("Request completed",
        response: {
          status: response.status,
          duration_ms: duration_ms.round(2)
        }
      )

      # Track response metrics
      MetricsService.histogram("api.requests.duration", duration_ms, tags: {
        method: request.method,
        path: sanitize_path_for_metrics(request.path),
        status: response.status,
        controller: controller_name,
        action: action_name
      })

    rescue => e
      # Log error
      duration_ms = (Time.current - start_time) * 1000
      request_logger.error("Request failed", e,
        response: {
          status: response.status || 500,
          duration_ms: duration_ms.round(2)
        }
      )

      # Track error metrics
      MetricsService.increment("api.requests.errors", tags: {
        method: request.method,
        path: sanitize_path_for_metrics(request.path),
        error_class: e.class.name,
        controller: controller_name,
        action: action_name
      })

      raise
    end
  end

  def set_request_id
    RequestStore[:request_id] = request.request_id
  end

  def filtered_params
    # Filter sensitive parameters
    params.except(:password, :password_confirmation, :token, :api_key, :secret)
  end

  def sanitize_path_for_metrics(path)
    # Replace dynamic segments with placeholders for better metric grouping
    path
      .gsub(/\/\d+/, "/:id")
      .gsub(/\/[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}/, "/:uuid")
      .gsub(/\?.*/, "") # Remove query parameters
  end

  def current_organization
    # Override in application controller
    nil
  end
end
