class ScheduledUploadPolicy < ApplicationPolicy
  def index?
    user.present? && (user.admin? || user.organization == record.data_source.organization)
  end

  def show?
    user.present? && (user.admin? || user.organization == record.data_source.organization)
  end

  def create?
    user.present? && (user.admin? || user.organization == record.data_source.organization)
  end

  def update?
    user.present? && (user.admin? || user.organization == record.data_source.organization)
  end

  def destroy?
    user.present? && (user.admin? || user.organization == record.data_source.organization)
  end

  def toggle_status?
    update?
  end

  def execute_now?
    user.present? && (user.admin? || user.organization == record.data_source.organization)
  end

  def logs?
    index?
  end

  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.joins(:data_source).where(data_sources: { organization: user.organization })
      end
    end
  end
end