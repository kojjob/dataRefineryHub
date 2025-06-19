require 'rails_helper'

RSpec.describe OrganizationPolicy, type: :policy do
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }

  let(:owner) { create(:user, :owner, organization: organization) }
  let(:admin) { create(:user, :admin, organization: organization) }
  let(:member) { create(:user, :member, organization: organization) }
  let(:viewer) { create(:user, :viewer, organization: organization) }
  let(:other_org_user) { create(:user, organization: other_organization) }

  subject { described_class }

  describe 'Scope' do
    it 'returns only the users organization' do
      scope = Pundit.policy_scope(owner, Organization)
      expect(scope).to include(organization)
      expect(scope).not_to include(other_organization)
    end

    it 'returns empty scope for users without organization' do
      user = build(:user, organization: nil)
      scope = Pundit.policy_scope(user, Organization)
      expect(scope).to be_empty
    end
  end

  permissions :show? do
    it 'allows users to view their own organization' do
      expect(subject).to permit(owner, organization)
      expect(subject).to permit(admin, organization)
      expect(subject).to permit(member, organization)
      expect(subject).to permit(viewer, organization)
    end

    it 'denies viewing other organizations' do
      expect(subject).not_to permit(owner, other_organization)
    end
  end

  permissions :update? do
    it 'allows owners and admins to update their organization' do
      expect(subject).to permit(owner, organization)
      expect(subject).to permit(admin, organization)
    end

    it 'denies members and viewers from updating organization' do
      expect(subject).not_to permit(member, organization)
      expect(subject).not_to permit(viewer, organization)
    end

    it 'denies updating other organizations' do
      expect(subject).not_to permit(owner, other_organization)
    end
  end

  permissions :destroy? do
    it 'allows only owners to destroy their organization' do
      expect(subject).to permit(owner, organization)
    end

    it 'denies admins, members, and viewers from destroying organization' do
      expect(subject).not_to permit(admin, organization)
      expect(subject).not_to permit(member, organization)
      expect(subject).not_to permit(viewer, organization)
    end

    it 'denies destroying other organizations' do
      expect(subject).not_to permit(owner, other_organization)
    end
  end

  permissions :billing? do
    it 'allows owners and admins to access billing' do
      expect(subject).to permit(owner, organization)
      expect(subject).to permit(admin, organization)
    end

    it 'denies members and viewers from accessing billing' do
      expect(subject).not_to permit(member, organization)
      expect(subject).not_to permit(viewer, organization)
    end
  end

  permissions :usage_stats? do
    it 'allows all users to view usage stats of their organization' do
      expect(subject).to permit(owner, organization)
      expect(subject).to permit(admin, organization)
      expect(subject).to permit(member, organization)
      expect(subject).to permit(viewer, organization)
    end

    it 'denies viewing usage stats of other organizations' do
      expect(subject).not_to permit(owner, other_organization)
    end
  end

  permissions :audit_logs? do
    it 'allows owners and admins to access audit logs' do
      expect(subject).to permit(owner, organization)
      expect(subject).to permit(admin, organization)
    end

    it 'denies members and viewers from accessing audit logs' do
      expect(subject).not_to permit(member, organization)
      expect(subject).not_to permit(viewer, organization)
    end
  end
end