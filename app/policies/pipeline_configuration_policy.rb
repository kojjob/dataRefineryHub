class PipelineConfigurationPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    user.present? && record.organization == user.organization
  end

  def create?
    user.present? && (user.owner? || user.admin?)
  end

  def new?
    create?
  end

  def update?
    user.present? &&
    record.organization == user.organization &&
    (user.owner? || user.admin?)
  end

  def edit?
    update?
  end

  def destroy?
    user.present? &&
    record.organization == user.organization &&
    (user.owner? || user.admin?)
  end

  def execute?
    user.present? &&
    record.organization == user.organization &&
    (user.owner? || user.admin? || user.member?)
  end

  def test?
    execute?
  end

  def available_extractors?
    user.present?
  end

  def transformation_preview?
    user.present?
  end

  def validate_pipeline?
    user.present?
  end

  def export_pipeline?
    show?
  end

  def import_pipeline?
    create?
  end

  class Scope < Scope
    def resolve
      if user.present?
        scope.where(organization: user.organization)
      else
        scope.none
      end
    end
  end
end
