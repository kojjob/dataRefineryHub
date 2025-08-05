class RootController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    if user_signed_in?
      # Redirect authenticated users to dashboard
      redirect_to dashboard_path
    else
      # Show landing page for unauthenticated users
      redirect_to landing_path
    end
  end
end
