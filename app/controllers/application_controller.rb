class ApplicationController < ActionController::Base
  include Pundit::Authorization

  protect_from_forgery with: :exception
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :log_session_debug, if: -> { Rails.env.development? }

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

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
    Rails.logger.debug "Current user: #{current_user&.email}"
    Rails.logger.debug "Session ID present: #{session.id.present? rescue 'N/A'}"
    Rails.logger.debug "Remember token cookie present: #{cookies[:remember_user_token].present?}"
    Rails.logger.debug "====================="
  end
end
