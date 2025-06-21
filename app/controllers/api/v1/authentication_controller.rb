class Api::V1::AuthenticationController < Api::V1::BaseController
  skip_before_action :authenticate_api_user!, only: [:login]
  skip_before_action :set_current_organization, only: [:login]
  skip_before_action :check_rate_limits, only: [:login]
  
  # POST /api/v1/auth/login
  def login
    email = params[:email]
    password = params[:password]
    
    unless email.present? && password.present?
      return render_error('Email and password are required', :bad_request)
    end
    
    user = User.find_by(email: email.downcase.strip)
    
    if user&.valid_password?(password)
      if user.confirmed?
        # Generate API token (implement JWT or similar)
        token = generate_api_token(user)
        
        render_success({
          user: serialize_user(user),
          token: token,
          expires_at: 24.hours.from_now.iso8601,
          organization: serialize_organization(user.organization)
        }, 'Login successful')
      else
        render_error('Please confirm your email address before signing in', :unauthorized)
      end
    else
      render_error('Invalid email or password', :unauthorized)
    end
  end
  
  # DELETE /api/v1/auth/logout
  def logout
    # Invalidate the current token (implement token blacklist)
    invalidate_current_token
    
    render_success({}, 'Logout successful')
  end
  
  # POST /api/v1/auth/refresh
  def refresh
    # Refresh the current token
    new_token = generate_api_token(current_user)
    
    render_success({
      token: new_token,
      expires_at: 24.hours.from_now.iso8601,
      user: serialize_user(current_user)
    }, 'Token refreshed successfully')
  end
  
  # GET /api/v1/auth/me
  def me
    render_success({
      user: serialize_user(current_user, include_details: true),
      organization: serialize_organization(@current_organization, include_details: true),
      permissions: user_permissions,
      api_usage: api_usage_stats
    })
  end
  
  private
  
  def generate_api_token(user)
    # Simple token generation - in production, use JWT with proper signing
    payload = {
      user_id: user.id,
      organization_id: user.organization_id,
      issued_at: Time.current.to_i,
      expires_at: 24.hours.from_now.to_i
    }
    
    # For now, return a simple base64 encoded payload
    # In production, use JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
    Base64.strict_encode64(payload.to_json)
  end
  
  def invalidate_current_token
    # Implement token blacklist/invalidation
    # For now, this is a no-op
    true
  end
  
  def serialize_user(user, include_details: false)
    base_data = {
      id: user.id,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      full_name: user.full_name,
      role: user.role,
      confirmed: user.confirmed?,
      created_at: user.created_at.iso8601
    }
    
    if include_details
      base_data.merge!({
        last_sign_in_at: user.last_sign_in_at&.iso8601,
        sign_in_count: user.sign_in_count || 0,
        current_sign_in_ip: user.current_sign_in_ip,
        time_zone: user.time_zone || 'UTC',
        locale: user.locale || 'en'
      })
    end
    
    base_data
  end
  
  def serialize_organization(organization, include_details: false)
    return nil unless organization
    
    base_data = {
      id: organization.id,
      name: organization.name,
      plan: organization.plan,
      status: organization.status,
      created_at: organization.created_at.iso8601
    }
    
    if include_details
      base_data.merge!({
        max_users: organization.max_users,
        max_data_sources: organization.max_data_sources,
        max_monthly_records: organization.max_monthly_records,
        settings: organization.settings || {},
        usage_stats: {
          current_users: organization.users.count,
          current_data_sources: organization.data_sources.count,
          monthly_records: organization.raw_data_records
                                     .where('created_at >= ?', 1.month.ago)
                                     .count
        }
      })
    end
    
    base_data
  end
  
  def user_permissions
    # Calculate user permissions based on role and organization plan
    base_permissions = {
      can_read_data: true,
      can_export_data: true,
      can_manage_data_sources: false,
      can_manage_users: false,
      can_manage_organization: false,
      can_access_api: true,
      can_view_analytics: true
    }
    
    case current_user.role
    when 'owner'
      base_permissions.merge({
        can_manage_data_sources: true,
        can_manage_users: true,
        can_manage_organization: true,
        can_manage_billing: true
      })
    when 'admin'
      base_permissions.merge({
        can_manage_data_sources: true,
        can_manage_users: true
      })
    when 'member'
      base_permissions.merge({
        can_manage_data_sources: true
      })
    else # viewer
      base_permissions.merge({
        can_export_data: false
      })
    end
  end
  
  def api_usage_stats
    # Calculate API usage statistics for the current user/organization
    today = Date.current
    
    {
      requests_today: Rails.cache.read("api_usage:#{current_user.id}:#{today.strftime('%Y%m%d')}") || 0,
      requests_this_month: calculate_monthly_api_usage,
      rate_limit: {
        requests_per_minute: 1000,
        requests_per_day: 50000,
        requests_per_month: 1000000
      },
      plan_limits: organization_api_limits
    }
  end
  
  def calculate_monthly_api_usage
    # Placeholder - implement actual usage tracking
    0
  end
  
  def organization_api_limits
    case @current_organization.plan
    when 'free_trial'
      { requests_per_day: 1000, requests_per_month: 10000 }
    when 'starter'
      { requests_per_day: 10000, requests_per_month: 100000 }
    when 'growth'
      { requests_per_day: 50000, requests_per_month: 1000000 }
    when 'scale'
      { requests_per_day: 200000, requests_per_month: 5000000 }
    else
      { requests_per_day: Float::INFINITY, requests_per_month: Float::INFINITY }
    end
  end
end