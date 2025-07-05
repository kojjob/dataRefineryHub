class OrganizationsController < ApplicationController
  before_action :set_organization

  def show
    authorize @organization
    @users = policy_scope(User).where(organization: @organization)
    @data_sources = policy_scope(DataSource).where(organization: @organization)
  end

  def edit
    authorize @organization
  end

  def update
    authorize @organization

    if @organization.update(organization_params)
      redirect_to @organization, notice: "Organization updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def billing
    authorize @organization, :billing?

    # Calculate billing metrics
    @billing_data = {
      current_plan: @organization.subscription_plan || "free",
      monthly_cost: calculate_monthly_cost,
      usage_this_month: {
        api_calls: calculate_api_calls,
        storage_gb: calculate_storage_used,
        data_sources: policy_scope(DataSource).count,
        users: @organization.users.count
      },
      usage_limits: {
        api_calls: get_api_call_limit,
        storage_gb: get_storage_limit,
        data_sources: get_data_source_limit,
        users: get_user_limit
      },
      billing_history: get_billing_history,
      next_billing_date: calculate_next_billing_date
    }
  end

  def usage_stats
    authorize @organization, :usage_stats?

    @stats = {
      total_records: policy_scope(RawDataRecord).count,
      api_calls_this_month: calculate_api_calls,
      storage_used: calculate_storage_used,
      active_integrations: policy_scope(DataSource).connected.count
    }
  end

  def audit_logs
    authorize @organization, :audit_logs?
    @audit_logs = policy_scope(AuditLog).includes(:user).recent.page(params[:page])
  end

  private

  def set_organization
    @organization = current_organization
  end

  def organization_params
    params.require(:organization).permit(:name, :subdomain, :timezone, :phone, :address)
  end

  def calculate_api_calls
    # Calculate API calls for current month
    start_of_month = Date.current.beginning_of_month

    # Count extraction jobs as API calls
    api_calls = @organization.extraction_jobs
                             .where("extraction_jobs.created_at >= ?", start_of_month)
                             .where(job_type: [ "api_sync", "manual_sync" ])
                             .count

    # Add AI service calls if available
    ai_calls = @organization.ai_insights
                            .where("ai_insights.created_at >= ?", start_of_month)
                            .count

    api_calls + ai_calls
  end

  def calculate_storage_used
    # Calculate storage used in GB
    total_records = policy_scope(RawDataRecord).count

    # Estimate storage: average 1KB per record + file uploads
    estimated_data_size = total_records * 1024 # bytes

    # Add file upload sizes if available
    file_uploads_size = @organization.data_sources
                                    .where(source_type: "file_upload")
                                    .joins(:raw_data_records)
                                    .sum("LENGTH(raw_data_records.data)")

    total_bytes = estimated_data_size + file_uploads_size
    (total_bytes / 1024.0 / 1024.0 / 1024.0).round(2) # Convert to GB
  end

  def calculate_monthly_cost
    plan = @organization.subscription_plan || "free"
    case plan
    when "free" then 0
    when "starter" then 29
    when "professional" then 99
    when "enterprise" then 299
    else 0
    end
  end

  def get_api_call_limit
    plan = @organization.subscription_plan || "free"
    case plan
    when "free" then 1000
    when "starter" then 10000
    when "professional" then 100000
    when "enterprise" then 1000000
    else 1000
    end
  end

  def get_storage_limit
    plan = @organization.subscription_plan || "free"
    case plan
    when "free" then 1 # GB
    when "starter" then 10
    when "professional" then 100
    when "enterprise" then 1000
    else 1
    end
  end

  def get_data_source_limit
    plan = @organization.subscription_plan || "free"
    case plan
    when "free" then 3
    when "starter" then 10
    when "professional" then 50
    when "enterprise" then 999
    else 3
    end
  end

  def get_user_limit
    plan = @organization.subscription_plan || "free"
    case plan
    when "free" then 3
    when "starter" then 10
    when "professional" then 50
    when "enterprise" then 999
    else 3
    end
  end

  def get_billing_history
    # Return last 12 months of billing history
    # This would typically come from a billing service like Stripe
    (1..12).map do |months_ago|
      date = months_ago.months.ago.beginning_of_month
      {
        date: date,
        amount: calculate_monthly_cost,
        status: "paid",
        invoice_url: "#"
      }
    end.reverse
  end

  def calculate_next_billing_date
    # Calculate next billing date based on organization creation
    if @organization.subscription_plan.present?
      @organization.created_at.next_month.beginning_of_month
    else
      nil
    end
  end
end
