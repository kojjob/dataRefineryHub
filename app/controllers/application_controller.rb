class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include RequestLogging
  include SecureInputHandling

  protect_from_forgery with: :exception
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :log_session_debug, if: -> { Rails.env.development? }
  before_action :set_system_status, unless: :devise_controller?
  before_action :set_manual_tasks_count, unless: :devise_controller?
  before_action :set_running_pipelines_count, unless: :devise_controller?
  after_action :set_security_headers

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def set_security_headers
    # Prevent MIME type sniffing
    response.headers["X-Content-Type-Options"] = "nosniff"

    # Prevent clickjacking attacks
    response.headers["X-Frame-Options"] = "SAMEORIGIN"

    # Enable XSS protection (though modern browsers have this by default)
    response.headers["X-XSS-Protection"] = "1; mode=block"

    # Force HTTPS for all future requests (only in production)
    if Rails.env.production?
      response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains; preload"
    end

    # Content Security Policy - adjust based on your needs
    response.headers["Content-Security-Policy"] = "default-src 'self'; script-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; font-src 'self' data:; img-src 'self' data: https:; connect-src 'self'"

    # Referrer Policy
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"

    # Permissions Policy (formerly Feature Policy)
    response.headers["Permissions-Policy"] = "geolocation=(), microphone=(), camera=()"
  end

  def structured_logger
    @structured_logger ||= StructuredLogger.new
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :first_name, :last_name ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :first_name, :last_name ])
  end

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_back(fallback_location: root_path)
  end

  def current_organization
    current_user&.organization
  end
  helper_method :current_organization

  def ensure_organization_member
    redirect_to new_user_session_path unless current_user&.organization
  end

  def log_session_debug
    return if devise_controller? # Skip for Devise controllers to avoid noise

    Rails.logger.debug "=== SESSION DEBUG ==="
    Rails.logger.debug "Controller: #{controller_name}##{action_name}"
    Rails.logger.debug "User signed in: #{user_signed_in?}"
    Rails.logger.debug "Current user: #{safe_current_user_email}"
    Rails.logger.debug "Session ID present: #{session.id.present? rescue 'N/A'}"
    Rails.logger.debug "Remember token cookie present: #{cookies[:remember_user_token].present?}"
    Rails.logger.debug "====================="
  end

  def safe_current_user_email
    user = current_user
    case user
    when User
      user.email
    when Array
      Rails.logger.error "CRITICAL: current_user returned an Array: #{user.inspect}"
      "[ERROR: current_user is Array]"
    when nil
      "[No user]"
    else
      Rails.logger.error "CRITICAL: current_user returned unexpected type #{user.class}: #{user.inspect}"
      "[ERROR: current_user is #{user.class}]"
    end
  rescue => e
    Rails.logger.error "Error getting current user email: #{e.message}"
    "[ERROR: #{e.message}]"
  end

  def set_system_status
    return unless current_user&.organization

    # Simplified system status for navigation
    begin
      total_jobs = current_user.organization.extraction_jobs.where("extraction_jobs.created_at >= ?", 24.hours.ago)
      running_jobs = total_jobs.running.count
      failed_jobs_rate = total_jobs.failed.count.to_f / [ total_jobs.count, 1 ].max

      # Calculate uptime based on success rate
      uptime = ((1 - failed_jobs_rate) * 100).round(1)

      # Calculate storage used (simplified)
      total_records = current_user.organization.raw_data_records.count
      estimated_storage_gb = (total_records * 0.0005).round(1) # More conservative estimate

      # Determine overall health
      health_status = case
      when uptime >= 99 && running_jobs < 10
                       { status: "healthy", color: "green", text: "Healthy" }
      when uptime >= 95 && running_jobs < 20
                       { status: "warning", color: "yellow", text: "Warning" }
      else
                       { status: "critical", color: "red", text: "Critical" }
      end

      @system_status = {
        health: health_status,
        uptime: "#{uptime}%",
        processing_jobs: running_jobs,
        storage_used: "#{estimated_storage_gb} GB",
        last_updated: Time.current
      }
    rescue => e
      Rails.logger.error "Error calculating system status: #{e.message}"
      # Fallback system status
      @system_status = {
        health: { status: "unknown", color: "gray", text: "Unknown" },
        uptime: "--",
        processing_jobs: 0,
        storage_used: "-- GB",
        last_updated: Time.current
      }
    end
  end

  def set_manual_tasks_count
    return unless current_user&.organization

    begin
      # Count pending manual tasks that are either unassigned or assigned to current user
      @manual_tasks_count = Task.joins(:pipeline_execution)
                                .where(pipeline_executions: { organization_id: current_organization.id })
                                .where(execution_mode: "manual", status: [ "ready", "waiting_approval" ])
                                .where("assignee_id IS NULL OR assignee_id = ?", current_user.id)
                                .count
    rescue => e
      Rails.logger.error "Error counting manual tasks: #{e.message}"
      @manual_tasks_count = 0
    end
  end

  def set_running_pipelines_count
    return unless current_user&.organization

    begin
      @running_pipelines_count = current_organization.pipeline_executions.running.count
    rescue => e
      Rails.logger.error "Error counting running pipelines: #{e.message}"
      @running_pipelines_count = 0
    end
  end
end
