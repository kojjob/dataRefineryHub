class Api::V1::BaseController < ApplicationController
  # Skip CSRF protection for API requests
  skip_before_action :verify_authenticity_token

  # API-specific before actions
  before_action :authenticate_api_user!
  before_action :set_current_organization
  before_action :check_rate_limits

  # Set JSON as default response format
  respond_to :json

  protected

  def authenticate_api_user!
    # Try API key authentication first, then fallback to session
    unless authenticate_with_api_key || user_signed_in?
      render_unauthorized
    end
  end

  def authenticate_with_api_key
    api_key = request.headers["X-API-Key"] || params[:api_key]
    return false unless api_key

    # Find user by API key (implement API key model later)
    user = User.joins(:api_keys).where(api_keys: { key: api_key, active: true }).first
    if user
      sign_in(user, store: false)
      return true
    end

    false
  rescue StandardError
    false
  end

  def set_current_organization
    @current_organization = current_user&.organization
    unless @current_organization
      render json: { error: "Organization not found" }, status: :forbidden
    end
  end

  def check_rate_limits
    # Basic rate limiting - can be enhanced with Redis later
    cache_key = "rate_limit:#{current_user&.id || request.remote_ip}:#{Time.current.strftime('%Y%m%d%H%M')}"
    current_count = Rails.cache.read(cache_key) || 0

    # Allow 1000 requests per minute per user
    if current_count >= 1000
      render json: {
        error: "Rate limit exceeded",
        message: "Too many requests. Please try again in a minute."
      }, status: :too_many_requests
      return
    end

    Rails.cache.write(cache_key, current_count + 1, expires_in: 1.minute)
  end

  def render_unauthorized
    render json: {
      error: "Unauthorized",
      message: "Valid authentication required. Use X-API-Key header or sign in."
    }, status: :unauthorized
  end

  def render_forbidden
    render json: {
      error: "Forbidden",
      message: "You do not have permission to access this resource."
    }, status: :forbidden
  end

  def render_not_found(resource = "Resource")
    render json: {
      error: "Not Found",
      message: "#{resource} not found."
    }, status: :not_found
  end

  def render_validation_errors(record)
    render json: {
      error: "Validation Failed",
      message: "The request could not be completed due to validation errors.",
      errors: record.errors.full_messages,
      details: record.errors.details
    }, status: :unprocessable_entity
  end

  def render_success(data = {}, message = "Success", status = :ok)
    response = {
      success: true,
      message: message,
      data: data,
      meta: {
        timestamp: Time.current.iso8601,
        api_version: "v1"
      }
    }

    render json: response, status: status
  end

  def render_error(message, status = :bad_request, details = {})
    response = {
      success: false,
      error: status.to_s.humanize,
      message: message,
      details: details,
      meta: {
        timestamp: Time.current.iso8601,
        api_version: "v1"
      }
    }

    render json: response, status: status
  end

  # Global exception handling
  rescue_from StandardError do |exception|
    Rails.logger.error "API Error: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")

    render json: {
      success: false,
      error: "Internal Server Error",
      message: "An unexpected error occurred.",
      meta: {
        timestamp: Time.current.iso8601,
        api_version: "v1"
      }
    }, status: :internal_server_error
  end

  rescue_from ActiveRecord::RecordNotFound do |exception|
    render_not_found(exception.model.constantize.model_name.human)
  end

  rescue_from Pundit::NotAuthorizedError do
    render_forbidden
  end

  private

  def pagination_params
    {
      page: params[:page]&.to_i || 1,
      per_page: [ params[:per_page]&.to_i || 25, 100 ].min # Max 100 per page
    }
  end

  def date_range_params
    start_date = params[:start_date]&.to_date || 30.days.ago.to_date
    end_date = params[:end_date]&.to_date || Date.current

    # Ensure start_date is before end_date
    if start_date > end_date
      start_date, end_date = end_date, start_date
    end

    # Limit range to 2 years max
    if (end_date - start_date).days > 730
      start_date = end_date - 730.days
    end

    { start_date: start_date, end_date: end_date }
  end
end
