class Api::V1::DataSourcesController < Api::V1::BaseController
  before_action :set_data_source, only: [ :show, :update, :destroy, :test_connection, :sync_now, :sync_status, :sync_history, :metrics ]

  # GET /api/v1/data_sources
  def index
    @data_sources = policy_scope(DataSource)
                   .includes(:extraction_jobs)
                   .order(:created_at)

    # Apply filtering
    @data_sources = @data_sources.where(platform: params[:platform]) if params[:platform].present?
    @data_sources = @data_sources.where(status: params[:status]) if params[:status].present?

    # Apply pagination
    page_params = pagination_params
    @data_sources = @data_sources.page(page_params[:page]).per(page_params[:per_page])

    render_success({
      data_sources: serialize_data_sources(@data_sources),
      pagination: pagination_meta(@data_sources)
    })
  end

  # GET /api/v1/data_sources/:id
  def show
    render_success({
      data_source: serialize_data_source(@data_source, include_details: true)
    })
  end

  # POST /api/v1/data_sources
  def create
    @data_source = @current_organization.data_sources.build(data_source_params)
    authorize @data_source

    if @data_source.save
      # Trigger initial sync job
      ExtractorJob.perform_later(@data_source.id)

      render_success({
        data_source: serialize_data_source(@data_source)
      }, "Data source created successfully", :created)
    else
      render_validation_errors(@data_source)
    end
  end

  # PATCH/PUT /api/v1/data_sources/:id
  def update
    if @data_source.update(data_source_params)
      render_success({
        data_source: serialize_data_source(@data_source)
      }, "Data source updated successfully")
    else
      render_validation_errors(@data_source)
    end
  end

  # DELETE /api/v1/data_sources/:id
  def destroy
    @data_source.destroy!
    render_success({}, "Data source deleted successfully")
  end

  # POST /api/v1/data_sources/:id/test_connection
  def test_connection
    # Test connection using the appropriate adapter
    begin
      adapter = EcommerceExtractor.create_adapter(@data_source.platform, @data_source.configuration)
      result = adapter.test_connection

      if result[:success]
        render_success({
          connection_status: "success",
          message: result[:message] || "Connection successful",
          details: result[:details]
        })
      else
        render_error(
          result[:error] || "Connection failed",
          :unprocessable_entity,
          result[:details]
        )
      end
    rescue StandardError => e
      render_error("Connection test failed: #{e.message}", :unprocessable_entity)
    end
  end

  # POST /api/v1/data_sources/:id/sync_now
  def sync_now
    # Trigger immediate sync
    job = ExtractorJob.perform_later(@data_source.id)

    render_success({
      sync_job_id: job.job_id,
      message: "Sync job queued successfully",
      estimated_completion: 5.minutes.from_now
    })
  end

  # GET /api/v1/data_sources/:id/sync_status
  def sync_status
    recent_jobs = @data_source.extraction_jobs
                             .order(created_at: :desc)
                             .limit(10)

    current_job = recent_jobs.find(&:running?)
    last_successful = recent_jobs.find(&:completed?)

    render_success({
      current_sync: current_job ? serialize_extraction_job(current_job) : nil,
      last_successful_sync: last_successful ? serialize_extraction_job(last_successful) : nil,
      sync_frequency: @data_source.sync_frequency || "manual",
      next_scheduled_sync: @data_source.next_sync_at,
      recent_jobs: recent_jobs.map { |job| serialize_extraction_job(job) }
    })
  end

  # GET /api/v1/data_sources/:id/sync_history
  def sync_history
    page_params = pagination_params
    date_params = date_range_params

    jobs = @data_source.extraction_jobs
                      .where(created_at: date_params[:start_date]..date_params[:end_date])
                      .order(created_at: :desc)
                      .page(page_params[:page])
                      .per(page_params[:per_page])

    render_success({
      sync_history: jobs.map { |job| serialize_extraction_job(job) },
      pagination: pagination_meta(jobs),
      date_range: date_params
    })
  end

  # GET /api/v1/data_sources/:id/metrics
  def metrics
    date_params = date_range_params

    # Calculate metrics for the data source
    metrics = {
      total_records: @data_source.raw_data_records.count,
      records_this_period: @data_source.raw_data_records
                                      .where(created_at: date_params[:start_date]..date_params[:end_date])
                                      .count,
      successful_syncs: @data_source.extraction_jobs
                                   .where(status: "completed")
                                   .where(created_at: date_params[:start_date]..date_params[:end_date])
                                   .count,
      failed_syncs: @data_source.extraction_jobs
                               .where(status: "failed")
                               .where(created_at: date_params[:start_date]..date_params[:end_date])
                               .count,
      avg_sync_duration: @data_source.extraction_jobs
                                    .completed
                                    .where(created_at: date_params[:start_date]..date_params[:end_date])
                                    .average("EXTRACT(EPOCH FROM (completed_at - started_at))")&.to_f&.round(2),
      last_sync_at: @data_source.extraction_jobs.completed.maximum(:completed_at),
      connection_health: calculate_connection_health(@data_source)
    }

    render_success({
      metrics: metrics,
      date_range: date_params
    })
  end

  private

  def set_data_source
    @data_source = @current_organization.data_sources.find(params[:id])
    authorize @data_source
  rescue ActiveRecord::RecordNotFound
    render_not_found("Data source")
  end

  def data_source_params
    params.require(:data_source).permit(
      :name, :platform, :status, :sync_frequency,
      configuration: {}
    )
  end

  def serialize_data_sources(data_sources)
    data_sources.map { |ds| serialize_data_source(ds) }
  end

  def serialize_data_source(data_source, include_details: false)
    base_data = {
      id: data_source.id,
      name: data_source.name,
      platform: data_source.platform,
      status: data_source.status,
      sync_frequency: data_source.sync_frequency,
      created_at: data_source.created_at.iso8601,
      updated_at: data_source.updated_at.iso8601,
      last_sync_at: data_source.extraction_jobs.completed.maximum(:completed_at)&.iso8601,
      total_records: data_source.raw_data_records.count,
      connection_health: calculate_connection_health(data_source)
    }

    if include_details
      base_data.merge!({
        configuration: data_source.configuration&.except("api_key", "access_token", "password"),
        extraction_jobs_count: data_source.extraction_jobs.count,
        recent_activity: data_source.extraction_jobs
                                   .order(created_at: :desc)
                                   .limit(5)
                                   .map { |job| serialize_extraction_job(job) }
      })
    end

    base_data
  end

  def serialize_extraction_job(job)
    {
      id: job.id,
      status: job.status,
      records_processed: job.records_processed || 0,
      records_inserted: job.records_inserted || 0,
      records_updated: job.records_updated || 0,
      error_message: job.error_message,
      started_at: job.started_at&.iso8601,
      completed_at: job.completed_at&.iso8601,
      duration_seconds: job.completed_at && job.started_at ?
                       (job.completed_at - job.started_at).to_f.round(2) : nil
    }
  end

  def calculate_connection_health(data_source)
    recent_jobs = data_source.extraction_jobs.where("created_at >= ?", 7.days.ago)
    return "unknown" if recent_jobs.empty?

    success_rate = recent_jobs.completed.count.to_f / recent_jobs.count

    case success_rate
    when 0.9..1.0 then "excellent"
    when 0.7..0.89 then "good"
    when 0.5..0.69 then "fair"
    else "poor"
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
