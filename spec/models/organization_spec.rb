require 'rails_helper'

RSpec.describe Organization, type: :model do
  subject { build(:organization) }

  describe 'associations' do
    it { should have_many(:users).dependent(:destroy) }
    it { should have_many(:audit_logs).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_least(2).is_at_most(100) }
    it { should validate_inclusion_of(:plan).in_array(Organization::PLANS) }
    it { should validate_inclusion_of(:status).in_array(Organization::STATUSES) }
  end

  describe 'scopes' do
    before { Organization.delete_all }

    let!(:active_org) { create(:organization, status: 'active', plan: 'growth') }
    let!(:trial_org) { create(:organization, status: 'trial', plan: 'free_trial') }
    let!(:starter_org) { create(:organization, plan: 'starter', status: 'suspended') }
    let!(:growth_org) { create(:organization, plan: 'growth', status: 'suspended') }

    it 'filters active organizations' do
      expect(Organization.active).to contain_exactly(active_org)
    end

    it 'filters by plan' do
      expect(Organization.by_plan('starter')).to contain_exactly(starter_org)
      expect(Organization.by_plan('growth')).to match_array([ active_org, growth_org ])
    end
  end

  describe 'plan predicate methods' do
    it 'correctly identifies starter plan' do
      org = build(:organization, plan: 'starter')
      expect(org).to be_starter_plan
      expect(org).not_to be_growth_plan
    end

    it 'correctly identifies growth plan' do
      org = build(:organization, plan: 'growth')
      expect(org).to be_growth_plan
      expect(org).not_to be_starter_plan
    end

    it 'correctly identifies scale plan' do
      org = build(:organization, plan: 'scale')
      expect(org).to be_scale_plan
      expect(org).not_to be_enterprise_plan
    end

    it 'correctly identifies enterprise plan' do
      org = build(:organization, plan: 'enterprise')
      expect(org).to be_enterprise_plan
      expect(org).not_to be_scale_plan
    end
  end

  describe 'status predicate methods' do
    it 'correctly identifies active status' do
      org = build(:organization, status: 'active')
      expect(org).to be_active
      expect(org).not_to be_trial
    end

    it 'correctly identifies trial status' do
      org = build(:organization, status: 'trial')
      expect(org).to be_trial
      expect(org).not_to be_active
    end
  end

  describe 'plan limits' do
    describe '#monthly_data_limit' do
      it 'returns correct limits for each plan' do
        expect(build(:organization, plan: 'starter').monthly_data_limit).to eq(100_000)
        expect(build(:organization, plan: 'growth').monthly_data_limit).to eq(500_000)
        expect(build(:organization, plan: 'scale').monthly_data_limit).to eq(2_000_000)
        expect(build(:organization, plan: 'enterprise').monthly_data_limit).to eq(Float::INFINITY)
      end
    end

    describe '#monthly_api_requests_limit' do
      it 'returns correct limits for each plan' do
        expect(build(:organization, plan: 'starter').monthly_api_requests_limit).to eq(10_000)
        expect(build(:organization, plan: 'growth').monthly_api_requests_limit).to eq(50_000)
        expect(build(:organization, plan: 'scale').monthly_api_requests_limit).to eq(200_000)
        expect(build(:organization, plan: 'enterprise').monthly_api_requests_limit).to eq(Float::INFINITY)
      end
    end

    describe '#max_users' do
      it 'returns correct limits for each plan' do
        expect(build(:organization, plan: 'starter').max_users).to eq(5)
        expect(build(:organization, plan: 'growth').max_users).to eq(20)
        expect(build(:organization, plan: 'scale').max_users).to eq(100)
        expect(build(:organization, plan: 'enterprise').max_users).to eq(Float::INFINITY)
      end
    end

    describe '#max_data_sources' do
      it 'returns correct limits for each plan' do
        expect(build(:organization, plan: 'starter').max_data_sources).to eq(5)
        expect(build(:organization, plan: 'growth').max_data_sources).to eq(15)
        expect(build(:organization, plan: 'scale').max_data_sources).to eq(50)
        expect(build(:organization, plan: 'enterprise').max_data_sources).to eq(Float::INFINITY)
      end
    end
  end

  describe 'capacity checks' do
    let(:organization) { create(:organization, plan: 'starter') }

    describe '#can_add_user?' do
      it 'returns true when under user limit' do
        create_list(:user, 3, organization: organization)
        expect(organization.can_add_user?).to be true
      end

      it 'returns false when at user limit' do
        create_list(:user, 5, organization: organization)
        expect(organization.can_add_user?).to be false
      end
    end
  end

  describe 'callbacks' do
    describe 'on create' do
      it 'sets default plan to free_trial' do
        org = Organization.create!(name: 'Test Org')
        expect(org.plan).to eq('free_trial')
      end

      it 'sets default status to trial' do
        org = Organization.create!(name: 'Test Org')
        expect(org.status).to eq('trial')
      end

      it 'initializes plan_limits and settings as empty hashes' do
        org = Organization.create!(name: 'Test Org')
        expect(org.plan_limits).to eq({})
        expect(org.settings).to eq({})
      end
    end

    describe 'name normalization' do
      it 'strips whitespace from name' do
        org = Organization.create!(name: '  Test Org  ')
        expect(org.name).to eq('Test Org')
      end
    end
  end
end
