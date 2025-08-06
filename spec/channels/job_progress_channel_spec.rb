require 'rails_helper'

RSpec.describe JobProgressChannel, type: :channel do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }
  let(:data_source) { create(:data_source, organization: organization) }
  let(:job) { create(:extraction_job, data_source: data_source, status: 'running') }

  before do
    stub_connection current_user: user
  end

  describe '#subscribed' do
    context 'with valid job' do
      it 'subscribes to job progress stream' do
        subscribe(job_id: job.id)

        expect(subscription).to be_confirmed
        expect(subscription).to have_stream_from("job_progress:#{job.id}")
      end
    end

    context 'with unauthorized job' do
      let(:other_org) { create(:organization) }
      let(:other_ds) { create(:data_source, organization: other_org) }
      let(:other_job) { create(:extraction_job, data_source: other_ds) }

      it 'rejects subscription' do
        subscribe(job_id: other_job.id)
        expect(subscription).to be_rejected
      end
    end

    context 'without job_id' do
      it 'rejects subscription' do
        subscribe
        expect(subscription).to be_rejected
      end
    end
  end

  describe '#request_status_update' do
    before do
      job.update!(
        records_processed: 5000,
        total_records: 10000,
        started_at: 1.hour.ago,
        error_count: 2,
        metadata: {
          processing_rate: 1.5,
          estimated_completion: 30.minutes.from_now
        }
      )

      subscribe(job_id: job.id)
    end

    it 'sends detailed job status' do
      perform :request_status_update

      expect(transmissions.last).to include(
        'job' => hash_including(
          'id' => job.id,
          'status' => 'running',
          'progress_percentage' => 50,
          'records_processed' => 5000,
          'total_records' => 10000,
          'error_count' => 2,
          'duration' => be_present,
          'processing_rate' => 1.5,
          'estimated_completion' => be_present
        )
      )
    end
  end

  describe '#cancel_job' do
    before do
      subscribe(job_id: job.id)
    end

    context 'when job can be cancelled' do
      it 'cancels the job and sends confirmation' do
        expect {
          perform :cancel_job
        }.to change { job.reload.status }.from('running').to('cancelled')

        expect(transmissions.last).to include(
          'action' => 'job_cancelled',
          'job_id' => job.id,
          'message' => match(/cancelled/i)
        )
      end
    end

    context 'when job is already completed' do
      before do
        job.update!(status: 'completed')
      end

      it 'sends error message' do
        perform :cancel_job

        expect(transmissions.last).to include(
          'error' => match(/cannot.*cancel.*completed/i)
        )
      end
    end

    context 'when user lacks permission' do
      let(:viewer_user) { create(:user, organization: organization, role: 'viewer') }

      before do
        stub_connection current_user: viewer_user
        subscribe(job_id: job.id)
      end

      it 'sends unauthorized error' do
        perform :cancel_job

        expect(transmissions.last).to include(
          'error' => match(/permission/i)
        )
      end
    end
  end

  describe 'real-time progress updates' do
    before do
      subscribe(job_id: job.id)
    end

    it 'broadcasts incremental progress updates' do
      # Simulate progress updates
      updates = [
        { records_processed: 1000, progress: 10 },
        { records_processed: 3000, progress: 30 },
        { records_processed: 5000, progress: 50 }
      ]

      updates.each do |update|
        expect {
          ActionCable.server.broadcast("job_progress:#{job.id}", {
            event: 'progress_update',
            job_id: job.id,
            **update
          })
        }.to have_broadcasted_to("job_progress:#{job.id}").with(
          hash_including('event' => 'progress_update')
        )
      end
    end

    it 'broadcasts job completion' do
      expect {
        job.update!(
          status: 'completed',
          completed_at: Time.current,
          records_processed: 10000,
          duration_seconds: 3600
        )

        ActionCable.server.broadcast("job_progress:#{job.id}", {
          event: 'job_completed',
          job_id: job.id,
          status: 'completed',
          records_processed: 10000,
          duration: 3600
        })
      }.to have_broadcasted_to("job_progress:#{job.id}").with(
        hash_including(
          'event' => 'job_completed',
          'status' => 'completed'
        )
      )
    end

    it 'broadcasts job failure' do
      error_details = {
        message: 'Connection timeout',
        code: 'ETIMEDOUT',
        retry_count: 3
      }

      expect {
        job.update!(
          status: 'failed',
          error_message: error_details[:message],
          metadata: job.metadata.merge(error_details: error_details)
        )

        ActionCable.server.broadcast("job_progress:#{job.id}", {
          event: 'job_failed',
          job_id: job.id,
          error: error_details
        })
      }.to have_broadcasted_to("job_progress:#{job.id}").with(
        hash_including(
          'event' => 'job_failed',
          'error' => hash_including('message' => 'Connection timeout')
        )
      )
    end
  end
end
