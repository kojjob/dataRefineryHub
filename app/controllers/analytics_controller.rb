# Legacy Analytics Controller - Redirects to new modular structure
# This controller has been refactored into smaller, focused controllers under Analytics namespace
class AnalyticsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_organization_member

  def index
    # Redirect to the new analytics dashboard
    redirect_to analytics_dashboard_index_path
  end

  # Legacy method redirects
  def show
    redirect_to analytics_dashboard_index_path
  end

  private

  # Kept for potential legacy API compatibility
  def calculate_date_range(range)
    case range
    when "7_days"
      [7.days.ago.beginning_of_day, Time.current.end_of_day]
    when "30_days"
      [30.days.ago.beginning_of_day, Time.current.end_of_day]
    when "90_days"
      [90.days.ago.beginning_of_day, Time.current.end_of_day]
    when "1_year"
      [1.year.ago.beginning_of_day, Time.current.end_of_day]
    else
      [30.days.ago.beginning_of_day, Time.current.end_of_day]
    end
  end
end