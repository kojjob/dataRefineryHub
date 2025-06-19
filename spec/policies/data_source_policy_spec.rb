require 'rails_helper'

RSpec.describe DataSourcePolicy, type: :policy do
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }

  let(:owner) { create(:user, :owner, organization: organization) }
  let(:admin) { create(:user, :admin, organization: organization) }
  let(:member) { create(:user, :member, organization: organization) }
  let(:viewer) { create(:user, :viewer, organization: organization) }

  let(:data_source) { create(:data_source, organization: organization) }
  let(:other_org_data_source) { create(:data_source, organization: other_organization) }

  subject { described_class }

  describe 'Scope' do
    let!(:org_data_sources) { [data_source] }
    let!(:other_data_sources) { [other_org_data_source] }

    it 'returns data sources from the same organization' do
      scope = Pundit.policy_scope(owner, DataSource)
      expect(scope).to include(data_source)
      expect(scope).not_to include(other_org_data_source)
    end

    it 'returns empty scope for users without organization' do
      user = build(:user, organization: nil)
      scope = Pundit.policy_scope(user, DataSource)
      expect(scope).to be_empty
    end
  end

  permissions :index?, :show? do
    it 'allows all users to view data sources in their organization' do
      expect(subject).to permit(owner, data_source)
      expect(subject).to permit(admin, data_source)
      expect(subject).to permit(member, data_source)
      expect(subject).to permit(viewer, data_source)
    end

    it 'denies viewing data sources from other organizations' do
      expect(subject).not_to permit(owner, other_org_data_source)
    end
  end

  permissions :create?, :update?, :destroy? do
    it 'allows owners, admins, and members to manage data sources' do
      expect(subject).to permit(owner, data_source)
      expect(subject).to permit(admin, data_source)
      expect(subject).to permit(member, data_source)
    end

    it 'denies viewers from managing data sources' do
      expect(subject).not_to permit(viewer, data_source)
    end

    it 'denies managing data sources from other organizations' do
      expect(subject).not_to permit(owner, other_org_data_source)
    end
  end

  permissions :test_connection?, :sync_now? do
    it 'allows owners, admins, and members to test and sync data sources' do
      expect(subject).to permit(owner, data_source)
      expect(subject).to permit(admin, data_source)
      expect(subject).to permit(member, data_source)
    end

    it 'denies viewers from testing and syncing data sources' do
      expect(subject).not_to permit(viewer, data_source)
    end
  end

  permissions :view_credentials? do
    it 'allows only owners and admins to view credentials' do
      expect(subject).to permit(owner, data_source)
      expect(subject).to permit(admin, data_source)
    end

    it 'denies members and viewers from viewing credentials' do
      expect(subject).not_to permit(member, data_source)
      expect(subject).not_to permit(viewer, data_source)
    end
  end
end