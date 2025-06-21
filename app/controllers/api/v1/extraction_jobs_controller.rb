class Api::V1::ExtractionJobsController < Api::V1::BaseController
  before_action :set_extraction_job, only: [:show, :retry, :cancel, :logs]
  before_action :set_data_source, only: [:index, :create], if: -> { params[:data_source_id].present? }
  
  # GET /api/v1/extraction_jobs
  # GET /api/v1/data_sources/:data_source_id/extraction_jobs
  def index
    @extraction_jobs = if @data_source
                        policy_scope(@data_source.extraction_jobs)
                      else
                        policy_scope(@current_organization.extraction_jobs)
                      end
    
    # Apply filtering
    @extraction_jobs = apply_filters(@extraction_jobs)
    
    # Apply sorting
    sort_by = params[:sort_by] || 'created_at'
    sort_order = params[:sort_order] || 'desc'
    @extraction_jobs = @extraction_jobs.order("#{sort_by} #{sort_order}")
    
    # Apply pagination
    page_params = pagination_params
    @extraction_jobs = @extraction_jobs.includes(:data_source)
                                      .page(page_params[:page])
                                      .per(page_params[:per_page])
    
    render_success({
      extraction_jobs: serialize_extraction_jobs(@extraction_jobs),
      pagination: pagination_meta(@extraction_jobs),
      filters_applied: applied_filters_summary
    })
  end
  
  # GET /api/v1/extraction_jobs/:id
  def show
    render_success({
      extraction_job: serialize_extraction_job(@extraction_job, include_details: true)
    })
  end
  
  # POST /api/v1/data_sources/:data_source_id/extraction_jobs
  def create
    @extraction_job = @data_source.extraction_jobs.build(extraction_job_params)
    @extraction_job.triggered_by = current_user
    authorize @extraction_job
    
    if @extraction_job.save
      # Queue the extraction job
      ExtractorJob.perform_later(@data_source.id, @extraction_job.id)
      
      render_success({
        extraction_job: serialize_extraction_job(@extraction_job)
      }, 'Extraction job created and queued successfully', :created)
    else
      render_validation_errors(@extraction_job)
    end
  end
  
  # DELETE /api/v1/extraction_jobs/:id
  def destroy
    if @extraction_job.can_be_deleted?
      @extraction_job.destroy!
      render_success({}, 'Extraction job deleted successfully')
    else
      render_error('Cannot delete a running extraction job', :unprocessable_entity)
    end
  end
  
  # POST /api/v1/extraction_jobs/:id/retry
  def retry
    if @extraction_job.can_be_retried?
      # Reset job status and queue for retry
      @extraction_job.update!(
        status: 'pending',
        error_message: nil,
        retry_count: (@extraction_job.retry_count || 0) + 1,
        started_at: nil,
        completed_at: nil
      )
      
      ExtractorJob.perform_later(@extraction_job.data_source_id, @extraction_job.id)
      
      render_success({
        extraction_job: serialize_extraction_job(@extraction_job)
      }, 'Extraction job queued for retry')
    else
      render_error('This extraction job cannot be retried', :unprocessable_entity)
    end
  end
  
  # POST /api/v1/extraction_jobs/:id/cancel
  def cancel
    if @extraction_job.can_be_cancelled?
      @extraction_job.update!(
        status: 'cancelled',
        completed_at: Time.current,
        error_message: 'Cancelled by user request'
      )
      
      # Attempt to cancel the background job if it's still running
      cancel_background_job(@extraction_job)
      
      render_success({
        extraction_job: serialize_extraction_job(@extraction_job)
      }, 'Extraction job cancelled successfully')
    else
      render_error('This extraction job cannot be cancelled', :unprocessable_entity)
    end
  end
  
  # GET /api/v1/extraction_jobs/:id/logs
  def logs
    logs = @extraction_job.execution_logs || []
    
    # Apply log filtering
    if params[:level].present?
      logs = logs.select { |log| log['level'] == params[:level] }
    end
    
    if params[:search].present?
      search_term = params[:search].downcase
      logs = logs.select { |log| log['message']&.downcase&.include?(search_term) }
    end
    
    # Apply pagination to logs
    page = (params[:page] || 1).to_i
    per_page = [(params[:per_page] || 50).to_i, 1000].min
    offset = (page - 1) * per_page
    
    paginated_logs = logs[offset, per_page] || []
    
    render_success({
      logs: paginated_logs,
      pagination: {
        current_page: page,
        per_page: per_page,
        total_logs: logs.size,
        total_pages: (logs.size.to_f / per_page).ceil
      },
      log_summary: generate_log_summary(logs)
    })
  end
  
  private
  
  def set_extraction_job
    @extraction_job = if params[:data_source_id].present?
                       @current_organization.data_sources
                                           .find(params[:data_source_id])
                                           .extraction_jobs
                                           .find(params[:id])
                     else
                       @current_organization.extraction_jobs.find(params[:id])
                     end
    authorize @extraction_job
  rescue ActiveRecord::RecordNotFound
    render_not_found('Extraction job')
  end
  
  def set_data_source
    @data_source = @current_organization.data_sources.find(params[:data_source_id])
    authorize @data_source
  rescue ActiveRecord::RecordNotFound
    render_not_found('Data source')
  end
  
  def extraction_job_params
    params.require(:extraction_job).permit(:job_type, :configuration, :priority)
  end
  
  def apply_filters(jobs)
    filtered_jobs = jobs
    
    # Status filter
    if params[:status].present?
      statuses = params[:status].is_a?(Array) ? params[:status] : [params[:status]]
      filtered_jobs = filtered_jobs.where(status: statuses)
    end
    
    # Date range filter
    if params[:start_date].present? || params[:end_date].present?
      date_params = date_range_params
      filtered_jobs = filtered_jobs.where(created_at: date_params[:start_date]..date_params[:end_date])
    end
    
    # Data source filter (when not already scoped)
    if params[:data_source_id].blank? && params[:data_source_ids].present?
      ds_ids = params[:data_source_ids].is_a?(Array) ? params[:data_source_ids] : [params[:data_source_ids]]
      filtered_jobs = filtered_jobs.where(data_source_id: ds_ids)
    end
    
    # Job type filter
    if params[:job_type].present?
      filtered_jobs = filtered_jobs.where(job_type: params[:job_type])
    end
    
    # Error filter (jobs with/without errors)
    case params[:has_errors]
    when 'true'
      filtered_jobs = filtered_jobs.where.not(error_message: [nil, ''])
    when 'false'
      filtered_jobs = filtered_jobs.where(error_message: [nil, ''])
    end
    
    filtered_jobs
  end
  
  def applied_filters_summary
    {
      status: params[:status],
      date_range: params[:start_date].present? || params[:end_date].present? ? date_range_params : nil,
      data_source_ids: params[:data_source_ids],
      job_type: params[:job_type],
      has_errors: params[:has_errors],
      sort_by: params[:sort_by] || 'created_at',
      sort_order: params[:sort_order] || 'desc'
    }.compact
  end
  
  def serialize_extraction_jobs(jobs)
    jobs.map { |job| serialize_extraction_job(job) }
  end
  
  def serialize_extraction_job(job, include_details: false)
    base_data = {
      id: job.id,
      data_source_id: job.data_source_id,
      data_source_name: job.data_source.name,
      data_source_platform: job.data_source.platform,
      status: job.status,
      job_type: job.job_type || 'full_sync',
      priority: job.priority || 'normal',
      records_processed: job.records_processed || 0,
      records_inserted: job.records_inserted || 0,
      records_updated: job.records_updated || 0,
      records_failed: job.records_failed || 0,
      retry_count: job.retry_count || 0,
      created_at: job.created_at.iso8601,
      started_at: job.started_at&.iso8601,
      completed_at: job.completed_at&.iso8601,
      duration_seconds: calculate_duration(job),
      progress_percentage: calculate_progress(job),
      has_errors: job.error_message.present?
    }
    
    if include_details
      base_data.merge!({
        configuration: job.configuration || {},
        error_message: job.error_message,
        error_details: job.error_details,
        triggered_by: job.triggered_by ? {
          id: job.triggered_by.id,
          name: job.triggered_by.full_name,
          email: job.triggered_by.email
        } : nil,
        execution_summary: generate_execution_summary(job),
        can_retry: job.can_be_retried?,
        can_cancel: job.can_be_cancelled?,
        can_delete: job.can_be_deleted?
      })
    end
    
    base_data
  end
  
  def calculate_duration(job)
    return nil unless job.started_at
    
    end_time = job.completed_at || Time.current
    (end_time - job.started_at).to_f.round(2)
  end
  
  def calculate_progress(job)
    case job.status
    when 'pending', 'queued'
      0
    when 'running'
      # Estimate progress based on records processed
      if job.estimated_total_records && job.estimated_total_records > 0
        [(job.records_processed.to_f / job.estimated_total_records * 100).round(1), 95].min
      else
        50 # Default for running jobs without estimates
      end
    when 'completed'
      100
    when 'failed', 'cancelled'
      (job.records_processed || 0) > 0 ? 
        [(job.records_processed.to_f / (job.estimated_total_records || job.records_processed) * 100).round(1), 95].min : 
        0
    else
      0
    end
  end
  
  def generate_execution_summary(job)
    {
      total_runtime: calculate_duration(job),
      throughput_per_second: calculate_throughput(job),
      error_rate: calculate_error_rate(job),
      data_quality_score: calculate_data_quality_score(job),
      memory_usage: job.peak_memory_usage,
      api_calls_made: job.api_calls_count
    }
  end
  
  def calculate_throughput(job)
    duration = calculate_duration(job)
    return nil unless duration && duration > 0
    
    ((job.records_processed || 0).to_f / duration).round(2)
  end
  
  def calculate_error_rate(job)
    total_records = (job.records_processed || 0)
    return 0 if total_records == 0
    
    error_records = (job.records_failed || 0)
    (error_records.to_f / total_records * 100).round(2)
  end
  
  def calculate_data_quality_score(job)
    # Placeholder for data quality scoring
    return nil unless job.completed?
    
    error_rate = calculate_error_rate(job)
    case error_rate
    when 0..1
      'excellent'
    when 1..5
      'good'
    when 5..15
      'fair'
    else
      'poor'
    end
  end
  
  def generate_log_summary(logs)
    summary = {
      total_entries: logs.size,
      by_level: logs.group_by { |log| log['level'] }.transform_values(&:size),
      error_count: logs.count { |log| log['level'] == 'error' },
      warning_count: logs.count { |log| log['level'] == 'warn' },
      recent_errors: logs.select { |log| log['level'] == 'error' }.last(5)
    }
    
    summary
  end
  
  def cancel_background_job(extraction_job)
    # Attempt to find and cancel the Solid Queue job
    # This would require implementing job tracking in the ExtractorJob
    begin
      # Placeholder for job cancellation logic
      Rails.logger.info "Attempting to cancel background job for extraction_job #{extraction_job.id}"
    rescue StandardError => e
      Rails.logger.error "Failed to cancel background job: #{e.message}"
    end
  end
  
  def pagination_meta(collection)
    {
      current_page: collection.current_page,
      total_pages: collection.total_pages,
      total_count: collection.total_count,
      per_page: collection.limit_value,
      has_next_page: collection.next_page.present?,
      has_prev_page: collection.prev_page.present?
    }
  end
end