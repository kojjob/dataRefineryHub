class Users::RegistrationsController < Devise::RegistrationsController
  protected

  def build_resource(hash = {})
    super(hash)
    
    # Create organization if organization_name is provided
    if params[:organization_name].present?
      begin
        organization = Organization.create!(
          name: params[:organization_name].strip,
          plan: 'free_trial'
        )
        resource.organization = organization
        # Role will be automatically set to 'owner' by the User model callback for first user
      rescue ActiveRecord::RecordInvalid => e
        # Handle organization creation errors
        resource.errors.add(:base, "Organization could not be created: #{e.message}")
      end
    else
      resource.errors.add(:organization_name, "can't be blank")
    end
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name])
  end
end