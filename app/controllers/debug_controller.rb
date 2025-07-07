# frozen_string_literal: true

class DebugController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :session_info ]

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
end
