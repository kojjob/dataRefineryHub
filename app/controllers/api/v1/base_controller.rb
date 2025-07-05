# API::V1::BaseController
# Base controller for API v1 endpoints with common functionality
class Api::V1::BaseController < ActionController::API
  include Pundit::Authorization

  before_action :authenticate_api_user!
  before_action :set_default_format
  before_action :track_api_usage

  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
  rescue_from Pundit::NotAuthorizedError, with: :forbidden
  rescue_from StandardError, with: :internal_server_error if Rails.env.production?

  private

  def authenticate_api_user!
    # Try JWT authentication first
    if authenticate_with_jwt
      return
    end

    # Fall back to API key authentication for backward compatibility
    authenticate_with_api_key
  end

  def authenticate_with_jwt
    auth_header = request.headers["Authorization"]
    return false unless auth_header&.start_with?("Bearer ")

    token = auth_header.split(" ").last

    begin
      # Check if token is revoked
      payload = JwtService.decode_token(token)
      if JwtService.token_revoked?(payload["jti"])
        render_error("Token has been revoked", :unauthorized)
        return true # Return true to indicate we tried JWT auth
      end

      # Authenticate the token
      result = JwtService.authenticate_token(token)
      @current_user = result[:user]
      @current_organization = result[:organization]
      @current_permissions = payload["permissions"] || []

      true
    rescue JwtService::TokenExpiredError => e
      render_error("Token has expired", :unauthorized)
      true
    rescue JwtService::TokenInvalidError => e
      render_error(e.message, :unauthorized)
      true
    rescue StandardError => e
      Rails.logger.error "JWT authentication error: #{e.message}"
      false # Fall back to API key auth
    end
  end

  def authenticate_with_api_key
    api_key = request.headers["X-API-Key"] || params[:api_key]

    if api_key.blank?
      render_error("Authentication required", :unauthorized)
      return
    end

    @api_key_record = ApiKey.active.find_by(key: api_key)

    if @api_key_record.nil?
      render_error("Invalid API key", :unauthorized)
      return
    end

    # Check rate limits
    if @api_key_record.rate_limit_exceeded?
      render_error("Rate limit exceeded", :too_many_requests)
      return
    end

    @current_organization = @api_key_record.organization
    @current_user = @api_key_record.user
    @current_permissions = [] # API keys have full permissions for now
  end

  def set_default_format
    request.format = :json
  end

  def track_api_usage
    return unless @current_user

    # Track API usage asynchronously
    TrackApiUsageJob.perform_later(
      user_id: @current_user.id,
      organization_id: @current_organization&.id,
      api_key_id: @api_key_record&.id,
      endpoint: request.path,
      method: request.method,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      authentication_type: @api_key_record ? "api_key" : "jwt"
    )
  end

  def current_organization
    @current_organization
  end

  def current_user
    @current_user
  end

  # Pagination helpers
  def paginate(scope)
    page = (params[:page] || 1).to_i
    per_page = [ (params[:per_page] || 25).to_i, 100 ].min

    scope.page(page).per(per_page)
  end

  def pagination_headers(collection)
    response.headers["X-Total-Count"] = collection.total_count.to_s
    response.headers["X-Page"] = collection.current_page.to_s
    response.headers["X-Per-Page"] = collection.limit_value.to_s
    response.headers["X-Total-Pages"] = collection.total_pages.to_s
  end

  # Error handling
  def render_error(message, status = :bad_request, details = nil)
    error = {
      error: {
        message: message,
        status: Rack::Utils.status_code(status)
      }
    }

    error[:error][:details] = details if details

    render json: error, status: status
  end

  def not_found(exception)
    render_error("Resource not found", :not_found, exception.message)
  end

  def unprocessable_entity(exception)
    render_error("Validation failed", :unprocessable_entity, exception.record.errors.full_messages)
  end

  def forbidden(exception)
    render_error("You are not authorized to perform this action", :forbidden)
  end

  def internal_server_error(exception)
    Rails.logger.error "API Error: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")

    render_error("An unexpected error occurred", :internal_server_error)
  end

  # Filtering helpers
  def filter_by_date_range(scope, date_field = :created_at)
    # Validate that date_field is a safe column name to prevent SQL injection
    allowed_date_fields = %i[created_at updated_at published_at scheduled_at executed_at]
    date_field = date_field.to_sym unless date_field.is_a?(Symbol)
    
    unless allowed_date_fields.include?(date_field)
      raise ArgumentError, "Invalid date field: #{date_field}"
    end

    if params[:start_date].present?
      scope = scope.where(date_field => Date.parse(params[:start_date]).beginning_of_day..)
    end

    if params[:end_date].present?
      scope = scope.where(date_field => ..Date.parse(params[:end_date]).end_of_day)
    end

    scope
  end

  def filter_by_status(scope)
    if params[:status].present?
      statuses = params[:status].split(",").map(&:strip)
      scope = scope.where(status: statuses)
    end

    scope
  end

  # Sorting helpers
  def apply_sorting(scope, allowed_fields = [])
    return scope unless params[:sort].present?

    field, direction = params[:sort].split(":")
    direction = direction&.downcase == "desc" ? "desc" : "asc"

    if allowed_fields.include?(field)
      scope.order(field => direction)
    else
      scope
    end
  end
end
