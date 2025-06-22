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
    # TODO: Implement billing dashboard
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
    # TODO: Implement API call tracking
    0
  end

  def calculate_storage_used
    # TODO: Implement storage calculation
    0
  end
end
