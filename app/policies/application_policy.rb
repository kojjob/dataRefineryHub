# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    user_signed_in?
  end

  def show?
    user_signed_in? && same_organization?
  end

  def create?
    user_signed_in?
  end

  def new?
    create?
  end

  def update?
    user_signed_in? && same_organization?
  end

  def edit?
    update?
  end

  def destroy?
    user_signed_in? && same_organization?
  end

  protected

  def user_signed_in?
    user.present?
  end

  def same_organization?
    return true unless record.respond_to?(:organization_id)
    record.organization_id == user.organization_id
  end

  def owner?
    user&.owner?
  end

  def admin?
    user&.admin?
  end

  def member?
    user&.member?
  end

  def viewer?
    user&.viewer?
  end

  def can_manage?
    owner? || admin?
  end

  def can_edit?
    owner? || admin? || member?
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      if user&.organization_id
        scope.where(organization_id: user.organization_id)
      else
        scope.none
      end
    end

    private

    attr_reader :user, :scope
  end
end
