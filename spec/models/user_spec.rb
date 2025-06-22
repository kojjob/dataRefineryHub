require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { should belong_to(:organization) }
    it { should belong_to(:invited_by).class_name('User').optional }
    it { should have_many(:audit_logs).dependent(:destroy) }
    it { should have_many(:sent_invitations).class_name('User').with_foreign_key('invited_by_id').dependent(:nullify) }
  end

  describe 'validations' do
    subject { build(:user) }

    it { should validate_presence_of(:email) }
    it { should validate_presence_of(:first_name) }
    it { should validate_presence_of(:last_name) }

    it 'validates role inclusion' do
      valid_roles = %w[owner admin member viewer]
      valid_roles.each do |role|
        organization = create(:organization)
        create(:user, organization: organization) # Ensure first user exists to avoid auto-owner assignment
        user = build(:user, role: role, organization: organization)
        expect(user).to be_valid
      end

      organization = create(:organization)
      create(:user, organization: organization) # Ensure first user exists
      user = build(:user, role: 'invalid_role', organization: organization)
      expect(user).not_to be_valid
      expect(user.errors[:role]).to include('is not included in the list')
    end

    it 'validates email uniqueness within organization' do
      organization = create(:organization)
      existing_user = create(:user, organization: organization)
      new_user = build(:user, email: existing_user.email, organization: organization)
      expect(new_user).not_to be_valid
      expect(new_user.errors[:email]).to include('has already been taken')
    end

    it 'allows same email in different organizations' do
      organization1 = create(:organization)
      organization2 = create(:organization)
      user1 = create(:user, email: 'test@example.com', organization: organization1)
      user2 = build(:user, email: 'test@example.com', organization: organization2, role: 'member')
      expect(user2).to be_valid
    end
  end

  describe 'scopes' do
    let(:organization1) { create(:organization) }
    let(:organization2) { create(:organization) }

    before do
      # Create users with different roles, avoiding conflicts with first-user-is-owner rule
      @owner = create(:user, role: 'owner', organization: organization1)
      @admin = create(:user, role: 'admin', organization: organization1)
      @member = create(:user, role: 'member', organization: organization1)
      @viewer = create(:user, role: 'viewer', organization: organization1)

      # Create separate users for confirmation tests in different org
      @confirmed_user = create(:user, organization: organization2, role: 'member')
      @confirmed_user.update_column(:confirmed_at, 1.day.ago)

      @pending_user = create(:user, organization: organization2, role: 'member')
      @pending_user.update_column(:confirmed_at, nil)
    end

    describe '.by_role' do
      it 'filters users by role' do
        expect(User.by_role('owner')).to include(@owner)
        expect(User.by_role('admin')).to include(@admin)
        expect(User.by_role('owner')).not_to include(@admin)
      end
    end

    describe '.confirmed' do
      it 'returns only confirmed users' do
        expect(User.confirmed).to include(@confirmed_user)
        expect(User.confirmed).not_to include(@pending_user)
      end
    end

    describe '.pending_confirmation' do
      it 'returns only unconfirmed users' do
        expect(User.pending_confirmation).to include(@pending_user)
        expect(User.pending_confirmation).not_to include(@confirmed_user)
      end
    end
  end

  describe 'callbacks' do
    describe '#set_default_role' do
      it 'sets default role to member for non-first users' do
        organization = create(:organization)
        create(:user, organization: organization) # Create first user

        user = build(:user, organization: organization, role: nil)
        user.valid?
        expect(user.role).to eq('member')
      end

      it 'sets first user in organization as owner' do
        organization = create(:organization)

        user = build(:user, organization: organization, role: nil)
        user.valid?
        expect(user.role).to eq('owner')
      end
    end

    describe '#normalize_email' do
      it 'normalizes email to lowercase' do
        user = build(:user, email: 'Test@Example.COM')
        user.valid?
        expect(user.email).to eq('test@example.com')
      end

      it 'strips whitespace from email' do
        user = build(:user, email: '  test@example.com  ')
        user.valid?
        expect(user.email).to eq('test@example.com')
      end
    end
  end

  describe 'instance methods' do
    let(:user) { create(:user) }

    describe '#full_name' do
      it 'returns first and last name combined' do
        user.first_name = 'John'
        user.last_name = 'Doe'
        expect(user.full_name).to eq('John Doe')
      end
    end

    describe '#initials' do
      it 'returns uppercased first letters of names' do
        user.first_name = 'john'
        user.last_name = 'doe'
        expect(user.initials).to eq('JD')
      end
    end

    describe 'role methods' do
      it 'correctly identifies owner role' do
        user.role = 'owner'
        expect(user.owner?).to be true
        expect(user.admin?).to be false
      end

      it 'correctly identifies admin role' do
        user.role = 'admin'
        expect(user.admin?).to be true
        expect(user.owner?).to be false
      end

      it 'correctly identifies member role' do
        user.role = 'member'
        expect(user.member?).to be true
        expect(user.viewer?).to be false
      end

      it 'correctly identifies viewer role' do
        user.role = 'viewer'
        expect(user.viewer?).to be true
        expect(user.member?).to be false
      end
    end

    describe '#confirmed?' do
      it 'returns true when confirmed_at is present' do
        user.confirmed_at = Time.current
        expect(user.confirmed?).to be true
      end

      it 'returns false when confirmed_at is nil' do
        user.confirmed_at = nil
        expect(user.confirmed?).to be false
      end
    end

    describe 'permission methods' do
      it 'allows organization management for owners and admins' do
        owner = build(:user, :owner)
        admin = build(:user, :admin)
        member = build(:user, :member)
        viewer = build(:user, :viewer)

        expect(owner.can_manage_organization?).to be true
        expect(admin.can_manage_organization?).to be true
        expect(member.can_manage_organization?).to be false
        expect(viewer.can_manage_organization?).to be false
      end

      it 'allows data source management for owners, admins, and members' do
        owner = build(:user, :owner)
        admin = build(:user, :admin)
        member = build(:user, :member)
        viewer = build(:user, :viewer)

        expect(owner.can_manage_data_sources?).to be true
        expect(admin.can_manage_data_sources?).to be true
        expect(member.can_manage_data_sources?).to be true
        expect(viewer.can_manage_data_sources?).to be false
      end

      it 'allows analytics viewing for all users' do
        %w[owner admin member viewer].each do |role|
          user = build(:user, role: role)
          expect(user.can_view_analytics?).to be true
        end
      end
    end

    describe '#role_hierarchy_level' do
      it 'returns correct hierarchy levels' do
        expect(build(:user, :owner).role_hierarchy_level).to eq(4)
        expect(build(:user, :admin).role_hierarchy_level).to eq(3)
        expect(build(:user, :member).role_hierarchy_level).to eq(2)
        expect(build(:user, :viewer).role_hierarchy_level).to eq(1)
      end
    end

    describe '#can_manage_user?' do
      let(:organization) { create(:organization) }
      let(:owner) { create(:user, :owner, organization: organization) }
      let(:admin) { create(:user, :admin, organization: organization) }
      let(:member) { create(:user, :member, organization: organization) }

      it 'allows higher role users to manage lower role users' do
        expect(owner.can_manage_user?(admin)).to be true
        expect(admin.can_manage_user?(member)).to be true
        expect(owner.can_manage_user?(member)).to be true
      end

      it 'prevents lower role users from managing higher role users' do
        expect(admin.can_manage_user?(owner)).to be false
        expect(member.can_manage_user?(admin)).to be false
      end

      it 'prevents users from managing themselves' do
        expect(owner.can_manage_user?(owner)).to be false
      end

      it 'prevents managing users from different organizations' do
        other_org_user = create(:user, organization: create(:organization))
        expect(owner.can_manage_user?(other_org_user)).to be false
      end
    end
  end
end
