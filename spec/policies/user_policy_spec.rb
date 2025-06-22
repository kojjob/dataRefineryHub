require 'rails_helper'

RSpec.describe UserPolicy, type: :policy do
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }

  let(:owner) { create(:user, :owner, organization: organization) }
  let(:admin) { create(:user, :admin, organization: organization) }
  let(:member) { create(:user, :member, organization: organization) }
  let(:viewer) { create(:user, :viewer, organization: organization) }
  let(:other_org_user) { create(:user, organization: other_organization) }

  subject { described_class }

  describe 'Scope' do
    let!(:org_users) { [ owner, admin, member, viewer ] }
    let!(:other_users) { [ other_org_user ] }

    it 'returns users from the same organization' do
      scope = Pundit.policy_scope(owner, User)
      expect(scope).to include(*org_users)
      expect(scope).not_to include(other_org_user)
    end

    it 'returns empty scope for users without organization' do
      user = build(:user, organization: nil)
      scope = Pundit.policy_scope(user, User)
      expect(scope).to be_empty
    end
  end

  permissions :index? do
    it 'allows owners and admins' do
      expect(subject).to permit(owner, User)
      expect(subject).to permit(admin, User)
    end

    it 'denies members and viewers' do
      expect(subject).not_to permit(member, User)
      expect(subject).not_to permit(viewer, User)
    end
  end

  permissions :show? do
    it 'allows users to view themselves' do
      expect(subject).to permit(member, member)
      expect(subject).to permit(viewer, viewer)
    end

    it 'allows owners and admins to view other users in same organization' do
      expect(subject).to permit(owner, member)
      expect(subject).to permit(admin, member)
    end

    it 'denies viewing users from different organizations' do
      expect(subject).not_to permit(owner, other_org_user)
    end

    it 'denies members viewing other users' do
      other_member = create(:user, :member, organization: organization)
      expect(subject).not_to permit(member, other_member)
    end
  end

  permissions :create? do
    it 'allows owners and admins' do
      expect(subject).to permit(owner, User)
      expect(subject).to permit(admin, User)
    end

    it 'denies members and viewers' do
      expect(subject).not_to permit(member, User)
      expect(subject).not_to permit(viewer, User)
    end
  end

  permissions :update? do
    it 'allows users to update themselves' do
      expect(subject).to permit(member, member)
      expect(subject).to permit(viewer, viewer)
    end

    it 'allows higher role users to update lower role users' do
      expect(subject).to permit(owner, admin)
      expect(subject).to permit(admin, member)
      expect(subject).to permit(owner, member)
    end

    it 'denies lower role users from updating higher role users' do
      expect(subject).not_to permit(admin, owner)
      expect(subject).not_to permit(member, admin)
    end

    it 'denies updating users from different organizations' do
      expect(subject).not_to permit(owner, other_org_user)
    end
  end

  permissions :destroy? do
    it 'prevents users from deleting themselves' do
      expect(subject).not_to permit(owner, owner)
      expect(subject).not_to permit(admin, admin)
    end

    it 'allows higher role users to delete lower role users' do
      expect(subject).to permit(owner, admin)
      expect(subject).to permit(admin, member)
    end

    it 'denies lower role users from deleting higher role users' do
      expect(subject).not_to permit(admin, owner)
      expect(subject).not_to permit(member, admin)
    end

    it 'denies deleting users from different organizations' do
      expect(subject).not_to permit(owner, other_org_user)
    end
  end

  permissions :change_role? do
    it 'prevents users from changing their own role' do
      expect(subject).not_to permit(owner, owner)
      expect(subject).not_to permit(admin, admin)
    end

    it 'allows higher role users to change lower role users' do
      expect(subject).to permit(owner, admin)
      expect(subject).to permit(admin, member)
    end

    it 'denies lower role users from changing higher role users' do
      expect(subject).not_to permit(admin, owner)
      expect(subject).not_to permit(member, admin)
    end

    it 'denies members and viewers from changing roles' do
      other_member = create(:user, :member, organization: organization)
      expect(subject).not_to permit(member, other_member)
      expect(subject).not_to permit(viewer, other_member)
    end
  end
end
