class AnalyticsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_organization_member

  def index
    authorize :analytics, :index?
    
    @date_range = params[:date_range] || '30_days'
    @start_date, @end_date = calculate_date_range(@date_range)
    
    # Data source metrics
    @total_data_sources = current_organization.data_sources.count
    @active_data_sources = current_organization.data_sources.connected.count
    @syncing_data_sources = current_organization.data_sources.where(status: 'syncing').count
    @error_data_sources = current_organization.data_sources.where(status: 'error').count
    @data_sources_by_type = current_organization.data_sources.group(:source_type).count
    @data_sources_by_status = current_organization.data_sources.group(:status).count
    
    # Extraction job metrics (accessed through data_sources)
    extraction_jobs = ExtractionJob.joins(:data_source)
      .where(data_sources: { organization_id: current_organization.id })
      .where(created_at: @start_date..@end_date)
    @total_jobs = extraction_jobs.count
    @successful_jobs = extraction_jobs.completed.count
    @failed_jobs = extraction_jobs.failed.count
    @running_jobs = extraction_jobs.running.count
    @queued_jobs = extraction_jobs.where(status: 'queued').count
    @success_rate = @total_jobs > 0 ? (@successful_jobs.to_f / @total_jobs * 100).round(1) : 0
    
    # Data volume metrics (accessed through data_sources)
    raw_data_records = RawDataRecord.joins(:data_source)
      .where(data_sources: { organization_id: current_organization.id })
      .where(created_at: @start_date..@end_date)
    @total_records = raw_data_records.count
    @processed_records = raw_data_records.processed.count
    @pending_records = raw_data_records.pending_processing.count
    @failed_records = raw_data_records.failed.count
    @processing_rate = @total_records > 0 ? (@processed_records.to_f / @total_records * 100).round(1) : 0
    @avg_records_per_job = @total_jobs > 0 ? (@total_records.to_f / @total_jobs).round : 0
    @records_processed = @processed_records
    
    # Performance metrics
    completed_jobs = extraction_jobs.completed.where.not(completed_at: nil, started_at: nil)
    if completed_jobs.any?
      durations = completed_jobs.map { |job| (job.completed_at - job.started_at) / 60.0 } # in minutes
      @avg_job_duration = durations.sum / durations.length
      @fastest_job_duration = durations.min
      @slowest_job_duration = durations.max
    else
      @avg_job_duration = @fastest_job_duration = @slowest_job_duration = 0
    end
    
    # Daily activity trends
    @daily_job_activity = extraction_jobs.group_by_day(:created_at).count
    @daily_record_activity = raw_data_records.group_by_day(:created_at).count
    @daily_activity = @daily_job_activity # For backward compatibility with the view
    @daily_success_rate = extraction_jobs.group_by_day(:created_at)
      .group(:status).count.transform_values do |day_data|
        total = day_data.values.sum
        completed = day_data['completed'] || 0
        total > 0 ? (completed.to_f / total * 100).round(1) : 0
      end
    
    # Top performing data sources (by record volume and success rate)
    @top_data_sources = current_organization.data_sources
      .joins(:extraction_jobs, :raw_data_records)
      .where(extraction_jobs: { created_at: @start_date..@end_date })
      .group('data_sources.id', 'data_sources.name')
      .select('data_sources.name, COUNT(DISTINCT extraction_jobs.id) as job_count, COUNT(raw_data_records.id) as record_count')
      .order('record_count DESC')
      .limit(5)
      .map { |ds| [ds.name, ds.record_count] }
    
    # Data source health metrics
    @priority_sources_health = current_organization.data_sources.priority_1
      .group(:status).count
    @sync_frequency_distribution = current_organization.data_sources
      .group(:sync_frequency).count
    
    # Error analysis
    @recent_errors = extraction_jobs.failed
      .where(created_at: @start_date..@end_date)
      .order(created_at: :desc)
      .limit(10)
      .includes(:data_source)
    
    # Record type distribution
    @records_by_type = raw_data_records.group(:record_type).count
    
    # Retry metrics
    @jobs_with_retries = extraction_jobs.where('retry_count > 0').count
    @avg_retry_count = extraction_jobs.where('retry_count > 0').average(:retry_count)&.round(1) || 0
    
    # System load indicators
    current_extraction_jobs = ExtractionJob.joins(:data_source)
      .where(data_sources: { organization_id: current_organization.id })
    @current_running_jobs = current_extraction_jobs.running.count
    @current_queued_jobs = current_extraction_jobs.where(status: 'queued').count
    @sources_needing_sync = current_organization.data_sources.needs_sync.count
  end

  private

  def calculate_date_range(range)
    case range
    when '7_days'
      [7.days.ago.beginning_of_day, Time.current.end_of_day]
    when '30_days'
      [30.days.ago.beginning_of_day, Time.current.end_of_day]
    when '90_days'
      [90.days.ago.beginning_of_day, Time.current.end_of_day]
    when '1_year'
      [1.year.ago.beginning_of_day, Time.current.end_of_day]
    else
      [30.days.ago.beginning_of_day, Time.current.end_of_day]
    end
  end
end