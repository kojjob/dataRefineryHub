class AnalyticsPolicy < ApplicationPolicy
  def index?
    user.present? && user.organization == record
  end

  def show?
    index?
  end

  private

  def record
    user.organization
  end
end
