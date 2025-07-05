# ManualTaskPolicy
# Authorization policy for manual task operations
class ManualTaskPolicy < ApplicationPolicy
  def auto_assign?
    user.admin?
  end

  def manage?
    user.admin?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
