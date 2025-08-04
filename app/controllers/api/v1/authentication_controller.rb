# API Authentication Controller
class Api::V1::AuthenticationController < Api::V1::BaseController
  skip_before_action :authenticate_api_user!, only: [ :login, :refresh ]

  # POST /api/v1/auth/login
  def login
    user = User.find_by(email: login_params[:email])

    if user&.valid_password?(login_params[:password])
      # Check if user account is active
      unless user.active_for_authentication?
        render_error("Account is locked or inactive", :unauthorized)
        return
      end

      # Generate tokens
      access_token = JwtService.generate_access_token(user, user.organization)
      refresh_token = JwtService.generate_refresh_token(user)

      # Update last sign in
      user.update_tracked_fields!(request)

      render json: {
        access_token: access_token,
        refresh_token: refresh_token,
        expires_in: JwtService::ACCESS_TOKEN_EXPIRY.to_i,
        token_type: "Bearer",
        user: {
          id: user.id,
          email: user.email,
          name: user.full_name,
          role: user.role
        },
        organization: user.organization ? {
          id: user.organization.id,
          name: user.organization.name,
          plan: user.organization.plan
        } : nil
      }
    else
      render_error("Invalid email or password", :unauthorized)
    end
  end

  # POST /api/v1/auth/logout
  def logout
    # Revoke the current token
    token = extract_token_from_header
    JwtService.revoke_token(token) if token

    render json: { message: "Successfully logged out" }
  end

  # POST /api/v1/auth/refresh
  def refresh
    refresh_token = refresh_params[:refresh_token]

    if refresh_token.blank?
      render_error("Refresh token is required", :bad_request)
      return
    end

    begin
      # Generate new access token
      access_token = JwtService.refresh_access_token(refresh_token)

      render json: {
        access_token: access_token,
        expires_in: JwtService::ACCESS_TOKEN_EXPIRY.to_i,
        token_type: "Bearer"
      }
    rescue JwtService::TokenError => e
      render_error(e.message, :unauthorized)
    end
  end

  # GET /api/v1/auth/me
  def me
    render json: {
      user: {
        id: current_user.id,
        email: current_user.email,
        name: current_user.full_name,
        role: current_user.role,
        created_at: current_user.created_at
      },
      organization: current_organization ? {
        id: current_organization.id,
        name: current_organization.name,
        plan: current_organization.plan,
        usage: {
          data_sources: current_organization.data_sources.count,
          pipelines: current_organization.pipelines.count,
          api_requests_today: current_user.api_requests_today
        }
      } : nil,
      permissions: @current_permissions
    }
  end

  # POST /api/v1/auth/revoke
  def revoke
    # Revoke specific token or all user tokens
    if revoke_params[:token]
      JwtService.revoke_token(revoke_params[:token])
      render json: { message: "Token revoked successfully" }
    elsif revoke_params[:revoke_all]
      # In a real implementation, you'd revoke all tokens for the user
      # This would require tracking issued tokens
      render json: { message: "All tokens revoked successfully" }
    else
      render_error("Token or revoke_all parameter required", :bad_request)
    end
  end

  private

  def login_params
    params.require(:auth).permit(:email, :password)
  end

  def refresh_params
    params.permit(:refresh_token)
  end

  def revoke_params
    params.permit(:token, :revoke_all)
  end

  def extract_token_from_header
    auth_header = request.headers["Authorization"]
    return nil unless auth_header&.start_with?("Bearer ")

    auth_header.split(" ").last
  end
end
