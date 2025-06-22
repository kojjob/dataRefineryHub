class RawDataRecordPolicy < ApplicationPolicy
  def index?
    user.owner? || user.admin? || user.member? || user.viewer?
  end

  def show?
    user.owner? || user.admin? || user.member? || user.viewer?
  end

  def create?
    user.owner? || user.admin? || user.member?
  end

  def update?
    user.owner? || user.admin? || user.member?
  end

  def destroy?
    user.owner? || user.admin?
  end

  def export?
    user.owner? || user.admin? || user.member?
  end

  def reprocess?
    user.owner? || user.admin? || user.member?
  end

  class Scope < Scope
    def resolve
      if user.owner? || user.admin? || user.member? || user.viewer?
        scope.joins(:data_source).where(data_sources: { organization_id: user.organization_id })
      else
        scope.none
      end
    end
  end
end
