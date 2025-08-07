# frozen_string_literal: true

module OptimizedScopes
  extend ActiveSupport::Concern

  included do
    # Scope for eager loading latest extraction job
    scope :with_latest_extraction_job, -> {
      left_joins(:extraction_jobs)
        .select('data_sources.*, extraction_jobs.id as latest_job_id, extraction_jobs.status as latest_job_status')
        .where('extraction_jobs.id = (SELECT id FROM extraction_jobs WHERE data_source_id = data_sources.id ORDER BY created_at DESC LIMIT 1) OR extraction_jobs.id IS NULL')
    }

    # Scope for including quality reports
    scope :with_quality_reports, -> {
      left_joins(:data_quality_reports)
        .select('data_sources.*, data_quality_reports.overall_score, data_quality_reports.issues_count')
        .where('data_quality_reports.id = (SELECT id FROM data_quality_reports WHERE data_source_id = data_sources.id ORDER BY created_at DESC LIMIT 1) OR data_quality_reports.id IS NULL')
    }

    # Scope for sources with recent errors
    scope :with_recent_errors, -> {
      joins(:extraction_jobs)
        .where('extraction_jobs.status = ? AND extraction_jobs.created_at > ?', 'failed', 24.hours.ago)
        .distinct
    }

    # Optimized scope for dashboard
    scope :for_dashboard, -> {
      includes(:organization, :extraction_jobs, :data_quality_reports)
        .with_latest_extraction_job
        .order(updated_at: :desc)
    }

    # Scope with statistics
    scope :with_stats, -> {
      select('data_sources.*,
              COUNT(DISTINCT extraction_jobs.id) as total_jobs_count,
              COUNT(DISTINCT CASE WHEN extraction_jobs.status = \'completed\' THEN extraction_jobs.id END) as successful_jobs_count,
              COUNT(DISTINCT CASE WHEN extraction_jobs.status = \'failed\' THEN extraction_jobs.id END) as failed_jobs_count')
        .left_joins(:extraction_jobs)
        .group('data_sources.id')
    }

    # Scope for recently updated
    scope :recently_updated, ->(limit = 10) {
      order(updated_at: :desc).limit(limit)
    }

    # Scope for sources by type
    scope :by_source_type, ->(type) {
      where(source_type: type) if type.present?
    }

    # Scope for sources with specific sync frequency
    scope :by_sync_frequency, ->(frequency) {
      where(sync_frequency: frequency) if frequency.present?
    }

    # Complex scope for monitoring
    scope :for_monitoring, -> {
      select('data_sources.*,
              extraction_jobs.status as current_job_status,
              extraction_jobs.started_at as current_job_started_at,
              data_quality_reports.overall_score as current_quality_score')
        .left_joins(:extraction_jobs, :data_quality_reports)
        .where('extraction_jobs.id = (SELECT id FROM extraction_jobs WHERE data_source_id = data_sources.id ORDER BY created_at DESC LIMIT 1) OR extraction_jobs.id IS NULL')
        .where('data_quality_reports.id = (SELECT id FROM data_quality_reports WHERE data_source_id = data_sources.id ORDER BY created_at DESC LIMIT 1) OR data_quality_reports.id IS NULL')
    }
  end

  class_methods do
    # Class method for batch processing
    def process_in_batches(batch_size = 100)
      find_in_batches(batch_size: batch_size) do |batch|
        yield batch
      end
    end

    # Optimized count by status
    def count_by_status
      group(:status).count
    end

    # Get sources requiring attention
    def requiring_attention
      with_recent_errors
        .or(where('last_sync_at < ?', 7.days.ago))
        .or(where('data_quality_reports.overall_score < ?', 0.7).joins(:data_quality_reports))
        .distinct
    end

    # Search scope
    def search(query)
      return all if query.blank?
      
      where('name ILIKE ? OR description ILIKE ? OR source_type ILIKE ?',
            "%#{query}%", "%#{query}%", "%#{query}%")
    end

    # Filter scope
    def filter_by(filters = {})
      scope = all
      
      scope = scope.by_source_type(filters[:source_type]) if filters[:source_type].present?
      scope = scope.by_sync_frequency(filters[:sync_frequency]) if filters[:sync_frequency].present?
      scope = scope.where(status: filters[:status]) if filters[:status].present?
      scope = scope.where(organization_id: filters[:organization_id]) if filters[:organization_id].present?
      
      scope
    end
  end

  # Instance methods for optimization
  def latest_job_cached
    @latest_job_cached ||= extraction_jobs.order(created_at: :desc).first
  end

  def latest_quality_report_cached
    @latest_quality_report_cached ||= data_quality_reports.order(created_at: :desc).first
  end

  def sync_status_cached
    Rails.cache.fetch("data_source:#{id}:sync_status", expires_in: 5.minutes) do
      {
        status: status,
        last_sync: last_sync_at,
        next_sync: next_sync_at,
      is_syncing: extraction_jobs.where(status: 'processing').exists?
      }
    end
  end

  def clear_cached_data
    Rails.cache.delete("data_source:#{id}:sync_status")
    @latest_job_cached = nil
    @latest_quality_report_cached = nil
  end
end
