# frozen_string_literal: true

class DebugController < ApplicationController
  include EnhancedFlashHelper
  skip_before_action :authenticate_user!, only: [ :session_info, :test_flash ]

  def session_info
    debug_info = {
      authenticated: user_signed_in?,
      current_user_id: current_user&.id,
      current_user_email: current_user&.email,
      session_data: {
        session_id: (session.id.present? rescue "N/A"),
        user_id: session[:user_id],
        organization_id: session[:organization_id]
      },
      cookies: {
        remember_user_token: cookies[:remember_user_token].present?,
        session_cookie: cookies["_data_refinery_platform_session"].present?
      },
      devise_info: current_user ? {
        remember_created_at: current_user.remember_created_at,
        current_sign_in_at: current_user.current_sign_in_at,
        sign_in_count: current_user.sign_in_count
      } : nil
    }

    render json: debug_info
  end

  def test_flash
    case params[:type]
    when "short"
      flash[:success] = "Short message (12 seconds)"
    when "medium"
      flash[:info] = "This is a medium length message that should take a bit longer to read and understand. (approximately 15 seconds)"
    when "long"
      flash[:warning] = "This is a very long flash message that contains a lot of information and should definitely take more time to read. It includes multiple sentences and detailed information that users need time to process and understand fully. This message will display for up to 20 seconds to give you adequate reading time."
    when "error"
      flash[:error] = "An error occurred while processing your request. Please check your input and try again. (approximately 14 seconds)"
    when "enhanced"
      flash_success("Enhanced flash message with progress bar and extended timing", {
        title: "Success!",
        action_text: "View Details",
        action_url: "#"
      })
    when "persistent"
      flash_success("This message won't auto-dismiss - click X to close", {
        title: "Persistent Message",
        persistent: true
      })
    when "action"
      flash_info("Your report is ready for download", {
        title: "Report Generated",
        action_text: "Download",
        action_url: "#download"
      })
    when "undo"
      flash_with_undo(:success, "Record deleted successfully", "#undo")
    when "custom_timing"
      flash_timed(:warning, "This message displays for exactly 8 seconds", 8000)
    when "validation"
      # Simulate validation errors
      flash_error("Please fix the following errors before continuing:", {
        title: "Validation Failed",
        persistent: true
      })
    when "all_types"
      flash_success("Success message")
      flash_error("Error message")
      flash_warning("Warning message")
      flash_info("Info message")
    else
      flash[:notice] = "Default test message with new 12-second timing"
    end

    redirect_to request.referer || root_path
  end
end
