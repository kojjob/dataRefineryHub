class UploadLogPolicy < ApplicationPolicy
  def index?
    user.present? && (user.admin? || user.organization == record.scheduled_upload.data_source.organization)
  end

  def show?
    user.present? && (user.admin? || user.organization == record.scheduled_upload.data_source.organization)
  end

  # Upload logs are read-only for users
  def create?
    false
  end

  def update?
    false
  end

  def destroy?
    user.present? && user.admin?
  end

  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.joins(scheduled_upload: :data_source)
             .where(scheduled_uploads: { data_sources: { organization: user.organization } })
      end
    end
  end
end