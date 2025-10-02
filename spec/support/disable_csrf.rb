# Disable CSRF protection in request specs
# Request specs test at the Rack/HTTP level, not the controller level,
# so they don't automatically include CSRF tokens like controller specs do.
RSpec.configure do |config|
  config.before(:each, type: :request) do
    # Bypass CSRF protection for request specs
    allow_any_instance_of(ActionController::Base).to receive(:verify_authenticity_token).and_return(true)
  end
end
