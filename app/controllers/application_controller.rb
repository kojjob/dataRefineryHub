class ApplicationController < ActionController::Base
  include Pundit::Authorization

  protect_from_forgery with: :exception
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :log_session_debug, if: -> { Rails.env.development? }
  before_action :set_system_status, unless: :devise_controller?

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
      total_jobs = current_user.organization.extraction_jobs.where('created_at >= ?', 24.hours.ago)
      running_jobs = total_jobs.running.count
      failed_jobs_rate = total_jobs.failed.count.to_f / [total_jobs.count, 1].max
      
      # Calculate uptime based on success rate
      uptime = ((1 - failed_jobs_rate) * 100).round(1)
      
      # Calculate storage used (simplified)
      total_records = current_user.organization.raw_data_records.count
      estimated_storage_gb = (total_records * 0.0005).round(1) # More conservative estimate
      
      # Determine overall health
      health_status = case
                     when uptime >= 99 && running_jobs < 10
                       { status: 'healthy', color: 'green', text: 'Healthy' }
                     when uptime >= 95 && running_jobs < 20
                       { status: 'warning', color: 'yellow', text: 'Warning' }
                     else
                       { status: 'critical', color: 'red', text: 'Critical' }
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
        health: { status: 'unknown', color: 'gray', text: 'Unknown' },
        uptime: "--",
        processing_jobs: 0,
        storage_used: "-- GB",
        last_updated: Time.current
      }
    end
  end
end
