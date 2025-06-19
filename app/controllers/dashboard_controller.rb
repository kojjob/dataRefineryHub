class DashboardController < ApplicationController
  before_action :ensure_organization_member

  def index
    @organization = current_organization
    @data_sources = policy_scope(DataSource).includes(:extraction_jobs)
    @recent_jobs = policy_scope(ExtractionJob).recent.limit(10)
    @stats = calculate_dashboard_stats
  end

  private

  def calculate_dashboard_stats
    {
      total_data_sources: @data_sources.count,
      connected_sources: @data_sources.connected.count,
      total_records: policy_scope(RawDataRecord).count,
      last_sync: @recent_jobs.successful.first&.completed_at
    }
  end
end