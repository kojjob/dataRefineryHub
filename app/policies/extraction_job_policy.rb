# frozen_string_literal: true

class ExtractionJobPolicy < ApplicationPolicy
  def index?
    same_organization?
  end

  def show?
    same_organization?
  end

  def create?
    user.can_manage_data_sources?
  end

  def update?
    user.can_manage_data_sources?
  end

  def destroy?
    user.can_manage_data_sources?
  end

  def retry?
    user.can_manage_data_sources? && record.can_retry?
  end

  def cancel?
    user.can_manage_data_sources? && record.can_cancel?
  end

  class Scope < Scope
    def resolve
      if user.owner? || user.admin?
        scope.joins(:data_source).where(data_sources: { organization_id: user.organization_id })
      elsif user.member?
        scope.joins(:data_source).where(data_sources: { organization_id: user.organization_id })
      else
        scope.none
      end
    end
  end

  private

  def same_organization?
    return false unless user_signed_in?
    return false unless record.data_source&.organization_id

    user.organization_id == record.data_source.organization_id
  end
end
