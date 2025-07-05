# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProcessingMetricsService, type: :service do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }
  let(:data_source) { create(:data_source, organization: organization) }
  let(:service) { described_class.new(organization_id: organization.id) }

  describe '#generate_metrics_report' do
    context 'with recent extraction jobs' do
      let!(:completed_job) do
        create(:extraction_job,
          data_source: data_source,
          status: 'completed',
          records_processed: 1000,
          started_at: 1.hour.ago,
          completed_at: 30.minutes.ago
        )
      end

      let!(:failed_job) do
        create(:extraction_job,
          data_source: data_source,
          status: 'failed',
          error_message: 'Connection timeout',
          error_metadata: { error_category: 'timeout_error' }
        )
      end

      it 'generates comprehensive metrics report' do
        report = service.generate_metrics_report

        expect(report).to include(
          :processing_overview,
          :performance_metrics,
          :error_analytics,
          :data_quality_metrics,
          :resource_utilization,
          :circuit_breaker_status,
          :real_time_stats,
          :generated_at
        )
      end

      it 'calculates processing overview correctly' do
        overview = service.generate_metrics_report[:processing_overview]

        expect(overview[:total_jobs]).to eq(2)
        expect(overview[:completed_jobs]).to eq(1)
        expect(overview[:failed_jobs]).to eq(1)
        expect(overview[:success_rate]).to eq(50.0)
        expect(overview[:total_records_processed]).to eq(1000)
      end

      it 'analyzes error patterns' do
        error_analytics = service.generate_metrics_report[:error_analytics]

        expect(error_analytics[:total_errors]).to eq(1)
        expect(error_analytics[:error_rate]).to eq(50.0)
        expect(error_analytics[:error_categories]).to include('timeout_error' => 1)
      end
    end
  end

  describe '#log_processing_event' do
    it 'logs structured event data' do
      expect(Rails.logger).to receive(:info).with(/PROCESSING_METRICS/)

      service.log_processing_event('job_started', { job_id: 123 })
    end

    it 'caches events for real-time monitoring' do
      service.log_processing_event('job_completed', { job_id: 456 })

      cache_key = "processing_events:#{organization.id}:#{Date.current.strftime('%Y%m%d')}"
      cached_events = Rails.cache.read(cache_key)

      expect(cached_events).to be_present
      expect(cached_events.last[:event_type]).to eq('job_completed')
      expect(cached_events.last[:data][:job_id]).to eq(456)
    end
  end

  describe '.log_job_started' do
    let(:extraction_job) { create(:extraction_job, data_source: data_source) }

    it 'logs job start with correct data' do
      expect_any_instance_of(described_class).to receive(:log_processing_event)
        .with('job_started', hash_including(
          job_id: extraction_job.id,
          data_source_id: extraction_job.data_source_id
        ))

      described_class.log_job_started(organization.id, extraction_job)
    end
  end

  describe '.log_job_completed' do
    let(:extraction_job) do
      create(:extraction_job,
        data_source: data_source,
        started_at: 1.hour.ago,
        completed_at: Time.current
      )
    end

    let(:result) { { total_records: 500, processing_summary: { success_rate: 95.5 } } }

    it 'logs job completion with metrics' do
      expect_any_instance_of(described_class).to receive(:log_processing_event)
        .with('job_completed', hash_including(
          job_id: extraction_job.id,
          records_processed: 500,
          processing_time: be_within(1.second).of(3600)
        ))

      described_class.log_job_completed(organization.id, extraction_job, result)
    end
  end

  describe '.log_job_failed' do
    let(:extraction_job) { create(:extraction_job, data_source: data_source, retry_count: 2) }
    let(:error) { StandardError.new('Test error') }

    it 'logs job failure with error details' do
      expect_any_instance_of(described_class).to receive(:log_processing_event)
        .with('job_failed', hash_including(
          job_id: extraction_job.id,
          error_class: 'StandardError',
          error_message: 'Test error',
          retry_count: 2
        ))

      described_class.log_job_failed(organization.id, extraction_job, error)
    end
  end

  describe 'performance calculations' do
    let!(:jobs) do
      [
        create(:extraction_job,
          data_source: data_source,
          status: 'completed',
          records_processed: 1000,
          started_at: 2.hours.ago,
          completed_at: 1.hour.ago
        ),
        create(:extraction_job,
          data_source: data_source,
          status: 'completed',
          records_processed: 2000,
          started_at: 1.hour.ago,
          completed_at: 30.minutes.ago
        )
      ]
    end

    it 'calculates average processing time correctly' do
      performance = service.generate_metrics_report[:performance_metrics]

      expect(performance[:processing_times][:average]).to eq(2700.0) # 45 minutes average
    end

    it 'calculates throughput metrics' do
      performance = service.generate_metrics_report[:performance_metrics]

      expect(performance[:throughput][:records_per_minute][:average]).to be > 0
    end
  end
end
