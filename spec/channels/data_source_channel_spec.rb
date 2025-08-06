require 'rails_helper'

RSpec.describe DataSourceChannel, type: :channel do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }
  let(:data_source) { create(:data_source, organization: organization) }

  before do
    stub_connection current_user: user
  end

  describe '#subscribed' do
    context 'with valid data source' do
      it 'subscribes to data source stream' do
        subscribe(data_source_id: data_source.id)

        expect(subscription).to be_confirmed
        expect(subscription).to have_stream_from("data_source:#{data_source.id}")
      end
    end

    context 'with unauthorized data source' do
      let(:other_org) { create(:organization) }
      let(:other_data_source) { create(:data_source, organization: other_org) }

      it 'rejects subscription' do
        subscribe(data_source_id: other_data_source.id)
        expect(subscription).to be_rejected
      end
    end

    context 'without data_source_id' do
      it 'rejects subscription' do
        subscribe
        expect(subscription).to be_rejected
      end
    end
  end

  describe '#request_sync_status' do
    let!(:recent_jobs) do
      3.times.map do |i|
        create(:extraction_job,
          data_source: data_source,
          status: %w[completed failed running].sample,
          started_at: i.hours.ago,
          completed_at: i.hours.ago + 30.minutes
        )
      end
    end

    before do
      subscribe(data_source_id: data_source.id)
    end

    it 'sends recent sync history' do
      perform :request_sync_status

      expect(transmissions.last).to include(
        'recent_syncs' => be_an(Array),
        'sync_stats' => hash_including(
          'total_syncs',
          'successful_syncs',
          'failed_syncs',
          'average_duration'
        )
      )

      # Should include recent jobs
      sync_data = transmissions.last['recent_syncs']
      expect(sync_data.size).to eq(3)
      expect(sync_data.first).to include('id', 'status', 'started_at', 'duration')
    end
  end

  describe '#trigger_manual_sync' do
    before do
      subscribe(data_source_id: data_source.id)
    end

    context 'when sync can be triggered' do
      it 'enqueues sync job and sends confirmation' do
        expect {
          perform :trigger_manual_sync
        }.to change(ExtractionJob, :count).by(1)

        expect(transmissions.last).to include(
          'action' => 'sync_triggered',
          'job_id' => be_present,
          'message' => match(/sync.*initiated/i)
        )
      end
    end

    context 'when sync is already running' do
      before do
        create(:extraction_job, data_source: data_source, status: 'running')
      end

      it 'sends error message' do
        perform :trigger_manual_sync

        expect(transmissions.last).to include(
          'error' => match(/sync.*already.*progress/i)
        )
      end
    end

    context 'when user lacks permission' do
      let(:viewer_user) { create(:user, organization: organization, role: 'viewer') }

      before do
        stub_connection current_user: viewer_user
        subscribe(data_source_id: data_source.id)
      end

      it 'sends unauthorized error' do
        perform :trigger_manual_sync

        expect(transmissions.last).to include(
          'error' => match(/permission/i)
        )
      end
    end
  end

  describe 'real-time sync updates' do
    before do
      subscribe(data_source_id: data_source.id)
    end

    it 'broadcasts job progress updates' do
      job = create(:extraction_job, data_source: data_source, status: 'running')

      expect {
        ActionCable.server.broadcast("data_source:#{data_source.id}", {
          event: 'sync_progress',
          job_id: job.id,
          progress: 50,
          records_processed: 1000
        })
      }.to have_broadcasted_to("data_source:#{data_source.id}").with(
        hash_including(
          'event' => 'sync_progress',
          'progress' => 50
        )
      )
    end
  end
end
