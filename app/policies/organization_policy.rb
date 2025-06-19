# frozen_string_literal: true

class OrganizationPolicy < ApplicationPolicy
  def show?
    same_organization?
  end

  def update?
    same_organization? && can_manage?
  end

  def destroy?
    same_organization? && owner?
  end

  def billing?
    same_organization? && can_manage?
  end

  def usage_stats?
    same_organization?
  end

  def api_keys?
    same_organization? && can_manage?
  end

  def audit_logs?
    same_organization? && can_manage?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user&.organization_id
      
      scope.where(id: user.organization_id)
    end
  end
end