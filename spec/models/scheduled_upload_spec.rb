require 'rails_helper'

RSpec.describe ScheduledUpload, type: :model do
  let(:organization) { create(:organization) }
  let(:data_source) { create(:data_source, organization: organization) }
  let(:user) { create(:user, organization: organization) }

  describe 'associations' do
    it { should belong_to(:data_source) }
    it { should belong_to(:user) }
    it { should have_many(:upload_logs).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:frequency) }
    it { should validate_inclusion_of(:frequency).in_array(%w[hourly daily weekly monthly]) }
    it { should validate_presence_of(:file_pattern) }
  end

  describe 'scopes' do
    let!(:active_upload) { create(:scheduled_upload, data_source: data_source, user: user, active: true) }
    let!(:inactive_upload) { create(:scheduled_upload, data_source: data_source, user: user, active: false) }
    let!(:due_upload) { create(:scheduled_upload, data_source: data_source, user: user, active: true, next_run_at: 1.hour.ago) }
    let!(:future_upload) { create(:scheduled_upload, data_source: data_source, user: user, active: true, next_run_at: 1.hour.from_now) }

    describe '.active' do
      it 'returns only active uploads' do
        expect(ScheduledUpload.active).to include(active_upload)
        expect(ScheduledUpload.active).not_to include(inactive_upload)
      end
    end

    describe '.due_for_execution' do
      it 'returns uploads that are due for execution' do
        expect(ScheduledUpload.due_for_execution).to include(due_upload)
        expect(ScheduledUpload.due_for_execution).not_to include(future_upload)
      end
    end
  end

  describe 'callbacks' do
    describe 'before_create :set_next_run_at' do
      it 'sets next_run_at when creating a new upload' do
        upload = build(:scheduled_upload, data_source: data_source, user: user)
        expect(upload.next_run_at).to be_nil
        upload.save!
        expect(upload.next_run_at).to be_present
      end
    end
  end

  describe 'instance methods' do
    let(:upload) { create(:scheduled_upload, data_source: data_source, user: user) }

    describe '#execute!' do
      it 'creates an upload log' do
        expect { upload.execute! }.to change(UploadLog, :count).by(1)
      end
    end
  end
end
