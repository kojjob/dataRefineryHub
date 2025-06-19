# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  def index?
    can_manage?
  end

  def show?
    same_organization? && (user == record || can_manage?)
  end

  def create?
    can_manage?
  end

  def update?
    return true if user == record # Users can edit themselves
    return false unless same_organization?
    return false unless can_manage?
    
    # Can't manage users with same or higher role
    user.role_hierarchy_level > record.role_hierarchy_level
  end

  def destroy?
    return false if user == record # Can't delete yourself
    return false unless same_organization?
    return false unless can_manage?
    
    # Can't delete users with same or higher role
    user.role_hierarchy_level > record.role_hierarchy_level
  end

  def invite?
    can_manage?
  end

  def resend_invitation?
    can_manage?
  end

  def change_role?
    return false unless can_manage?
    return false unless same_organization?
    return false if user == record # Can't change own role
    
    # Can't manage users with same or higher role
    user.role_hierarchy_level > record.role_hierarchy_level
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user&.organization_id
      
      scope.where(organization_id: user.organization_id)
    end
  end
end