require 'rails_helper'

RSpec.describe UploadLog, type: :model do
  let(:organization) { create(:organization) }
  let(:data_source) { create(:data_source, organization: organization) }
  let(:user) { create(:user, organization: organization) }
  let(:scheduled_upload) { create(:scheduled_upload, data_source: data_source, user: user) }

  describe 'associations' do
    it { should belong_to(:scheduled_upload) }
  end

  describe 'validations' do
    it { should validate_presence_of(:status) }
    it { should validate_inclusion_of(:status).in_array(%w[pending running completed completed_with_errors failed]) }
    it { should validate_presence_of(:started_at) }
  end

  describe 'scopes' do
    let!(:completed_log) { create(:upload_log, scheduled_upload: scheduled_upload, status: 'completed') }
    let!(:failed_log) { create(:upload_log, scheduled_upload: scheduled_upload, status: 'failed') }
    let!(:recent_log) { create(:upload_log, scheduled_upload: scheduled_upload, started_at: 1.hour.ago) }
    let!(:old_log) { create(:upload_log, scheduled_upload: scheduled_upload, started_at: 1.week.ago) }

    describe '.successful' do
      it 'returns only completed logs' do
        expect(UploadLog.successful).to include(completed_log)
        expect(UploadLog.successful).not_to include(failed_log)
      end
    end

    describe '.failed' do
      it 'returns only failed logs' do
        expect(UploadLog.failed).to include(failed_log)
        expect(UploadLog.failed).not_to include(completed_log)
      end
    end

    describe '.recent' do
      it 'returns logs from the last 30 days' do
        expect(UploadLog.recent).to include(recent_log)
        expect(UploadLog.recent).not_to include(old_log)
      end
    end
  end

  describe '#duration' do
    it 'calculates duration when completed_at is present' do
      log = create(:upload_log, 
        scheduled_upload: scheduled_upload,
        started_at: 1.hour.ago,
        completed_at: 30.minutes.ago
      )
      expect(log.duration).to eq(30.minutes)
    end

    it 'returns nil when completed_at is not present' do
      log = create(:upload_log, scheduled_upload: scheduled_upload, completed_at: nil)
      expect(log.duration).to be_nil
    end
  end

  describe '#success?' do
    it 'returns true for completed status' do
      log = create(:upload_log, scheduled_upload: scheduled_upload, status: 'completed')
      expect(log.success?).to be true
    end

    it 'returns true for completed_with_errors status' do
      log = create(:upload_log, scheduled_upload: scheduled_upload, status: 'completed_with_errors')
      expect(log.success?).to be true
    end

    it 'returns false for failed status' do
      log = create(:upload_log, scheduled_upload: scheduled_upload, status: 'failed')
      expect(log.success?).to be false
    end
  end

  describe '#failure?' do
    it 'returns true for failed status' do
      log = create(:upload_log, scheduled_upload: scheduled_upload, status: 'failed')
      expect(log.failure?).to be true
    end

    it 'returns false for completed status' do
      log = create(:upload_log, scheduled_upload: scheduled_upload, status: 'completed')
      expect(log.failure?).to be false
    end
  end

  describe '#running?' do
    it 'returns true for running status' do
      log = create(:upload_log, scheduled_upload: scheduled_upload, status: 'running')
      expect(log.running?).to be true
    end

    it 'returns false for completed status' do
      log = create(:upload_log, scheduled_upload: scheduled_upload, status: 'completed')
      expect(log.running?).to be false
    end
  end

  describe '#status_color' do
    it 'returns green for completed status' do
      log = create(:upload_log, scheduled_upload: scheduled_upload, status: 'completed')
      expect(log.status_color).to eq('green')
    end

    it 'returns yellow for completed_with_errors status' do
      log = create(:upload_log, scheduled_upload: scheduled_upload, status: 'completed_with_errors')
      expect(log.status_color).to eq('yellow')
    end

    it 'returns red for failed status' do
      log = create(:upload_log, scheduled_upload: scheduled_upload, status: 'failed')
      expect(log.status_color).to eq('red')
    end

    it 'returns blue for running status' do
      log = create(:upload_log, scheduled_upload: scheduled_upload, status: 'running')
      expect(log.status_color).to eq('blue')
    end

    it 'returns gray for pending status' do
      log = create(:upload_log, scheduled_upload: scheduled_upload, status: 'pending')
      expect(log.status_color).to eq('gray')
    end
  end

  describe '#processed_files_summary' do
    it 'returns summary of processed files' do
      details = {
        'processed_files' => [
          { 'name' => 'file1.csv', 'records' => 100 },
          { 'name' => 'file2.csv', 'records' => 200 }
        ]
      }
      log = create(:upload_log, scheduled_upload: scheduled_upload, details: details)
      summary = log.processed_files_summary
      expect(summary).to include('file1.csv (100 records)')
      expect(summary).to include('file2.csv (200 records)')
    end

    it 'returns empty array when no processed files' do
      log = create(:upload_log, scheduled_upload: scheduled_upload, details: {})
      expect(log.processed_files_summary).to eq([])
    end
  end

  describe '#error_summary' do
    it 'returns summary of errors' do
      details = {
        'errors' => [
          { 'file' => 'file1.csv', 'error' => 'Invalid format' },
          { 'file' => 'file2.csv', 'error' => 'Missing columns' }
        ]
      }
      log = create(:upload_log, scheduled_upload: scheduled_upload, details: details)
      summary = log.error_summary
      expect(summary).to include('file1.csv: Invalid format')
      expect(summary).to include('file2.csv: Missing columns')
    end

    it 'returns empty array when no errors' do
      log = create(:upload_log, scheduled_upload: scheduled_upload, details: {})
      expect(log.error_summary).to eq([])
    end
  end
end