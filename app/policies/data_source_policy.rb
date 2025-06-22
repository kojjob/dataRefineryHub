# frozen_string_literal: true

class DataSourcePolicy < ApplicationPolicy
  def index?
    same_organization?
  end

  def show?
    same_organization?
  end

  def create?
    same_organization? && can_edit?
  end

  def update?
    same_organization? && can_edit?
  end

  def destroy?
    same_organization? && can_edit?
  end

  def test_connection?
    same_organization? && can_edit?
  end

  def sync_now?
    same_organization? && can_edit?
  end

  def view_credentials?
    same_organization? && can_manage?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user&.organization_id

      scope.where(organization_id: user.organization_id)
    end
  end
end
