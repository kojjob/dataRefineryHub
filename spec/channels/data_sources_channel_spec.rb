require 'rails_helper'

RSpec.describe DataSourcesChannel, type: :channel do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }
  let!(:data_sources) { create_list(:data_source, 3, organization: organization) }

  before do
    stub_connection current_user: user
  end

  describe '#subscribed' do
    context 'without specific data source' do
      it 'subscribes to organization data sources stream' do
        subscribe
        
        expect(subscription).to be_confirmed
        expect(subscription).to have_stream_from("data_sources:organization:#{organization.id}")
      end
    end

    context 'with specific data source' do
      let(:data_source) { data_sources.first }

      it 'subscribes to both organization and specific data source streams' do
        subscribe(data_source_id: data_source.id)
        
        expect(subscription).to be_confirmed
        expect(subscription).to have_stream_from("data_sources:organization:#{organization.id}")
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
  end

  describe '#request_status_update' do
    before do
      # Create some jobs for the data sources
      data_sources.each do |ds|
        create(:extraction_job, data_source: ds, status: %w[completed failed running].sample)
      end
      
      subscribe
    end

    it 'sends status for all organization data sources' do
      perform :request_status_update
      
      expect(transmissions.last).to include(
        'data_sources' => be_an(Array)
      )
      
      sources_data = transmissions.last['data_sources']
      expect(sources_data.size).to eq(3)
      
      sources_data.each do |source|
        expect(source).to include(
          'id' => be_present,
          'name' => be_present,
          'connection_type' => be_present,
          'status' => be_present,
          'last_sync' => be_a(Hash),
          'sync_health' => match(/healthy|warning|critical/)
        )
      end
    end
  end

  describe '#subscribe_to_sync' do
    let(:data_source) { data_sources.first }
    let(:job) { create(:extraction_job, data_source: data_source) }

    before do
      subscribe
    end

    it 'subscribes to job progress stream' do
      perform :subscribe_to_sync, job_id: job.id
      
      expect(subscription).to have_stream_from("job_progress:#{job.id}")
      expect(transmissions.last).to include(
        'action' => 'sync_subscribed',
        'job_id' => job.id
      )
    end

    it 'handles jobs from other organizations' do
      other_org = create(:organization)
      other_ds = create(:data_source, organization: other_org)
      other_job = create(:extraction_job, data_source: other_ds)
      
      perform :subscribe_to_sync, job_id: other_job.id
      
      expect(transmissions.last).to include(
        'error' => match(/not found|unauthorized/i)
      )
    end
  end

  describe 'sync health calculation' do
    before do
      subscribe
    end

    it 'calculates health based on recent sync history' do
      ds = data_sources.first
      
      # All successful syncs = healthy
      3.times { create(:extraction_job, data_source: ds, status: 'completed', created_at: 1.hour.ago) }
      
      perform :request_status_update
      source_data = transmissions.last['data_sources'].find { |s| s['id'] == ds.id }
      expect(source_data['sync_health']).to eq('healthy')
      
      # Some failures = warning
      2.times { create(:extraction_job, data_source: ds, status: 'failed', created_at: 30.minutes.ago) }
      
      perform :request_status_update
      source_data = transmissions.last['data_sources'].find { |s| s['id'] == ds.id }
      expect(source_data['sync_health']).to eq('warning')
      
      # Many recent failures = critical
      5.times { create(:extraction_job, data_source: ds, status: 'failed', created_at: 10.minutes.ago) }
      
      perform :request_status_update
      source_data = transmissions.last['data_sources'].find { |s| s['id'] == ds.id }
      expect(source_data['sync_health']).to eq('critical')
    end
  end
end