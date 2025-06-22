class Api::V1::OrganizationsController < Api::V1::BaseController
  # GET /api/v1/organization
  def show
    render_success({
      organization: serialize_organization(@current_organization, include_details: true)
    })
  end

  # PATCH/PUT /api/v1/organization
  def update
    authorize @current_organization

    if @current_organization.update(organization_params)
      render_success({
        organization: serialize_organization(@current_organization, include_details: true)
      }, "Organization updated successfully")
    else
      render_validation_errors(@current_organization)
    end
  end

  # GET /api/v1/organization/usage_stats
  def usage_stats
    stats = calculate_usage_statistics

    render_success({
      usage_stats: stats,
      plan_limits: plan_limits,
      usage_warnings: usage_warnings(stats),
      billing_period: current_billing_period
    })
  end

  # GET /api/v1/organization/audit_logs
  def audit_logs
    page_params = pagination_params
    date_params = date_range_params

    # Get audit logs (implement audit logging system)
    logs = get_audit_logs(date_params, page_params)

    render_success({
      audit_logs: logs[:data],
      pagination: logs[:pagination],
      date_range: date_params,
      summary: audit_logs_summary(date_params)
    })
  end

  # GET /api/v1/organization/billing_info
  def billing_info
    authorize @current_organization, :manage_billing?

    billing_data = {
      current_plan: @current_organization.plan,
      plan_status: @current_organization.status,
      billing_cycle: "monthly", # or get from subscription
      next_billing_date: calculate_next_billing_date,
      current_usage: calculate_current_usage,
      plan_limits: plan_limits,
      billing_history: recent_billing_history,
      payment_method: current_payment_method,
      upcoming_charges: calculate_upcoming_charges
    }

    render_success({
      billing_info: billing_data
    })
  end

  private

  def organization_params
    params.require(:organization).permit(
      :name, :time_zone, :currency, :locale,
      settings: {}
    )
  end

  def serialize_organization(organization, include_details: false)
    base_data = {
      id: organization.id,
      name: organization.name,
      plan: organization.plan,
      status: organization.status,
      time_zone: organization.time_zone || "UTC",
      currency: organization.currency || "USD",
      locale: organization.locale || "en",
      created_at: organization.created_at.iso8601,
      updated_at: organization.updated_at.iso8601
    }

    if include_details
      base_data.merge!({
        settings: organization.settings || {},
        plan_limits: plan_limits,
        current_usage: calculate_current_usage,
        users_count: organization.users.count,
        data_sources_count: organization.data_sources.count,
        subscription_info: subscription_info
      })
    end

    base_data
  end

  def plan_limits
    case @current_organization.plan
    when "free_trial"
      {
        max_users: 3,
        max_data_sources: 2,
        max_monthly_records: 10000,
        max_api_calls_per_month: 10000,
        features: [ "basic_analytics", "email_support" ]
      }
    when "starter"
      {
        max_users: 10,
        max_data_sources: 5,
        max_monthly_records: 100000,
        max_api_calls_per_month: 100000,
        features: [ "advanced_analytics", "email_support", "integrations" ]
      }
    when "growth"
      {
        max_users: 50,
        max_data_sources: 20,
        max_monthly_records: 1000000,
        max_api_calls_per_month: 1000000,
        features: [ "advanced_analytics", "priority_support", "integrations", "custom_reports" ]
      }
    when "scale"
      {
        max_users: 200,
        max_data_sources: 100,
        max_monthly_records: 10000000,
        max_api_calls_per_month: 10000000,
        features: [ "advanced_analytics", "priority_support", "integrations", "custom_reports", "white_label" ]
      }
    when "enterprise"
      {
        max_users: Float::INFINITY,
        max_data_sources: Float::INFINITY,
        max_monthly_records: Float::INFINITY,
        max_api_calls_per_month: Float::INFINITY,
        features: [ "all_features", "dedicated_support", "custom_integrations", "sla" ]
      }
    else
      {
        max_users: 1,
        max_data_sources: 1,
        max_monthly_records: 1000,
        max_api_calls_per_month: 1000,
        features: [ "basic_analytics" ]
      }
    end
  end

  def calculate_current_usage
    current_month_start = Date.current.beginning_of_month

    {
      users: @current_organization.users.count,
      data_sources: @current_organization.data_sources.count,
      monthly_records: @current_organization.raw_data_records
                                         .where("created_at >= ?", current_month_start)
                                         .count,
      api_calls_this_month: calculate_api_calls_this_month,
      storage_used_bytes: calculate_storage_usage,
      extraction_jobs_this_month: @current_organization.extraction_jobs
                                                      .where("created_at >= ?", current_month_start)
                                                      .count
    }
  end

  def calculate_usage_statistics
    current_usage = calculate_current_usage
    limits = plan_limits

    usage_percentages = {}

    # Calculate usage percentages
    [ :users, :data_sources, :monthly_records, :api_calls_this_month ].each do |metric|
      current = current_usage[metric] || 0
      max_key = case metric
      when :api_calls_this_month then :max_api_calls_per_month
      else "max_#{metric}".to_sym
      end

      max_value = limits[max_key]

      if max_value == Float::INFINITY
        usage_percentages[metric] = 0
      else
        usage_percentages["#{metric}_percentage".to_sym] = (current.to_f / max_value * 100).round(2)
      end
    end

    current_usage.merge(usage_percentages).merge({
      plan_limits: limits,
      usage_health: calculate_usage_health(usage_percentages)
    })
  end

  def usage_warnings(stats)
    warnings = []

    # Check for usage warnings
    if stats[:users_percentage] && stats[:users_percentage] > 80
      warnings << {
        type: "users_limit",
        severity: stats[:users_percentage] > 95 ? "critical" : "warning",
        message: "Approaching user limit for your plan",
        current: stats[:users],
        limit: plan_limits[:max_users]
      }
    end

    if stats[:data_sources_percentage] && stats[:data_sources_percentage] > 80
      warnings << {
        type: "data_sources_limit",
        severity: stats[:data_sources_percentage] > 95 ? "critical" : "warning",
        message: "Approaching data sources limit for your plan",
        current: stats[:data_sources],
        limit: plan_limits[:max_data_sources]
      }
    end

    if stats[:monthly_records_percentage] && stats[:monthly_records_percentage] > 80
      warnings << {
        type: "records_limit",
        severity: stats[:monthly_records_percentage] > 95 ? "critical" : "warning",
        message: "Approaching monthly records limit for your plan",
        current: stats[:monthly_records],
        limit: plan_limits[:max_monthly_records]
      }
    end

    warnings
  end

  def calculate_usage_health(usage_percentages)
    max_percentage = usage_percentages.values.select { |v| v.is_a?(Numeric) }.max || 0

    case max_percentage
    when 0..60
      "healthy"
    when 60..80
      "moderate"
    when 80..95
      "high"
    else
      "critical"
    end
  end

  def current_billing_period
    {
      start_date: Date.current.beginning_of_month.iso8601,
      end_date: Date.current.end_of_month.iso8601,
      days_remaining: (Date.current.end_of_month - Date.current).to_i + 1
    }
  end

  def get_audit_logs(date_params, page_params)
    # Placeholder for audit logging system
    # In a real implementation, you'd have an audit_logs table
    {
      data: [],
      pagination: {
        current_page: page_params[:page],
        total_pages: 0,
        total_count: 0,
        per_page: page_params[:per_page]
      }
    }
  end

  def audit_logs_summary(date_params)
    {
      total_events: 0,
      events_by_type: {},
      events_by_user: {},
      security_events: 0
    }
  end

  def calculate_next_billing_date
    # Placeholder - would come from subscription system
    Date.current.end_of_month + 1.day
  end

  def recent_billing_history
    # Placeholder for billing history
    []
  end

  def current_payment_method
    # Placeholder for payment method info
    {
      type: "card",
      last_four: "****",
      expires: nil,
      status: "active"
    }
  end

  def calculate_upcoming_charges
    # Placeholder for upcoming charges calculation
    {
      base_plan: 0,
      overages: 0,
      total: 0,
      billing_date: calculate_next_billing_date
    }
  end

  def subscription_info
    {
      plan: @current_organization.plan,
      status: @current_organization.status,
      trial_ends_at: calculate_trial_end_date,
      subscription_id: nil, # Would come from payment processor
      cancel_at_period_end: false
    }
  end

  def calculate_trial_end_date
    return nil unless @current_organization.plan == "free_trial"

    # Assume 14-day trial from creation
    @current_organization.created_at + 14.days
  end

  def calculate_api_calls_this_month
    # Placeholder - would track actual API usage
    0
  end

  def calculate_storage_usage
    # Placeholder - would calculate actual storage usage
    0
  end
end
