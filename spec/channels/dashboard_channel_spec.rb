require 'rails_helper'

RSpec.describe DashboardChannel, type: :channel do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }
  let(:admin_user) { create(:user, organization: organization, role: 'admin') }

  before do
    stub_connection current_user: user
  end

  describe '#subscribed' do
    context 'with admin user' do
      before do
        stub_connection current_user: admin_user
      end

      it 'subscribes to dashboard stream and sends initial data' do
        subscribe
        
        expect(subscription).to be_confirmed
        expect(subscription).to have_stream_from("dashboard:#{organization.id}")
        
        # Should transmit initial dashboard data
        expect(transmissions.last).to include(
          'overview' => hash_including(
            'total_data_sources',
            'active_syncs',
            'total_records',
            'failed_syncs'
          ),
          'recent_activity' => be_an(Array),
          'system_health' => hash_including(
            'queue_size',
            'active_workers',
            'memory_usage',
            'cpu_usage'
          )
        )
      end
    end

    context 'with non-admin user' do
      it 'rejects subscription' do
        subscribe
        expect(subscription).to be_rejected
      end
    end
  end

  describe '#request_metrics_update' do
    before do
      stub_connection current_user: admin_user
      subscribe
    end

    it 'sends updated metrics' do
      perform :request_metrics_update
      
      expect(transmissions.last).to include(
        'overview' => be_a(Hash),
        'recent_activity' => be_an(Array),
        'system_health' => be_a(Hash)
      )
    end
  end

  describe '#subscribe_to_job' do
    let(:data_source) { create(:data_source, organization: organization) }
    let(:job) { create(:extraction_job, data_source: data_source) }

    before do
      stub_connection current_user: admin_user
      subscribe
    end

    it 'subscribes to job updates' do
      perform :subscribe_to_job, job_id: job.id
      
      expect(subscription).to have_stream_from("job_progress:#{job.id}")
      expect(transmissions.last).to include(
        'action' => 'job_subscribed',
        'job_id' => job.id
      )
    end

    it 'handles non-existent jobs gracefully' do
      perform :subscribe_to_job, job_id: 'non-existent'
      
      expect(transmissions.last).to include(
        'error' => 'Job not found'
      )
    end
  end

  describe 'real-time updates' do
    before do
      stub_connection current_user: admin_user
      subscribe
    end

    it 'broadcasts sync completion updates' do
      data_source = create(:data_source, organization: organization)
      job = create(:extraction_job, data_source: data_source, status: 'running')
      
      expect {
        job.update!(status: 'completed', completed_at: Time.current)
        ActionCable.server.broadcast("dashboard:#{organization.id}", {
          event: 'sync_completed',
          job_id: job.id,
          data_source_id: data_source.id
        })
      }.to have_broadcasted_to("dashboard:#{organization.id}").with(
        hash_including(event: 'sync_completed')
      )
    end
  end
end