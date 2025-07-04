class Users::SessionsController < Devise::SessionsController
  before_action :configure_sign_in_params, only: [:create]

  # POST /resource/sign_in
  def create
    Rails.logger.info "Session create attempt for email: #{params.dig(:user, :email)}"
    Rails.logger.info "Remember me: #{params.dig(:user, :remember_me)}"
    
    super do |resource|
      if resource.persisted?
        Rails.logger.info "User signed in successfully: #{resource.email}"
        Rails.logger.info "Session ID: #{session.id}" if session.respond_to?(:id)
        Rails.logger.info "Remember created at: #{resource.remember_created_at.present?}"
        
        # Log session configuration (removed manual session setting to avoid conflicts with Devise)
        Rails.logger.info "Session store: #{Rails.application.config.session_store}"
        Rails.logger.info "Session options: #{Rails.application.config.session_options}"
      else
        Rails.logger.warn "Sign in failed for email: #{params.dig(:user, :email)}"
        Rails.logger.warn "Errors: #{resource.errors.full_messages}" if resource.errors.any?
      end
    end
  end

  # DELETE /resource/sign_out
  def destroy
    Rails.logger.info "User signing out: #{current_user&.email}"
    super
  end

  protected

  def configure_sign_in_params
    devise_parameter_sanitizer.permit(:sign_in, keys: [:remember_me])
  end

  # Override after_sign_in_path to ensure proper redirection
  def after_sign_in_path_for(resource)
    Rails.logger.info "Redirecting after sign in to dashboard"
    stored_location_for(resource) || dashboard_path
  end

  # Override after_sign_out_path to ensure proper redirection  
  def after_sign_out_path_for(resource_or_scope)
    Rails.logger.info "Redirecting after sign out to login"
    new_user_session_path
  end
end