class AuditLogPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.admin?
        scope.where(organization: user.organization)
      else
        scope.none
      end
    end
  end

  def index?
    user.admin? || user.manager?
  end

  def show?
    user.admin? || user.manager?
  end

  def create?
    false # Audit logs are created automatically
  end

  def update?
    false # Audit logs should not be updated
  end

  def destroy?
    false # Audit logs should not be deleted
  end
end