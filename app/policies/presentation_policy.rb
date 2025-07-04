# frozen_string_literal: true

class PresentationPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.organization_admin? || user.organization_owner?
        scope.where(organization: user.organization)
      else
        scope.none
      end
    end
  end

  def index?
    organization_member?
  end

  def show?
    organization_member? && record.organization == user.organization
  end

  def create?
    organization_member? && can_generate_presentations?
  end

  def new?
    create?
  end

  def generate?
    create?
  end

  def preview?
    organization_member?
  end

  def download?
    show? && record.completed?
  end

  def status?
    show?
  end

  def destroy?
    (organization_admin? || organization_owner?) && record.organization == user.organization
  end

  private

  def can_generate_presentations?
    # Check if user's organization plan allows presentation generation
    case user.organization.plan
    when 'free_trial'
      user.organization.presentations.where('created_at >= ?', 1.month.ago).count < 2
    when 'starter'
      user.organization.presentations.where('created_at >= ?', 1.month.ago).count < 10
    when 'growth'
      user.organization.presentations.where('created_at >= ?', 1.month.ago).count < 50
    when 'scale', 'enterprise'
      true
    else
      false
    end
  end
end