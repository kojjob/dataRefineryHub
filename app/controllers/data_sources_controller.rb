class DataSourcesController < ApplicationController
  before_action :set_data_source, only: [:show, :edit, :update, :destroy, :test_connection, :sync_now]

  def index
    @data_sources = policy_scope(DataSource).includes(:extraction_jobs).order(:created_at)
    @connected_sources = @data_sources.where(status: 'connected')
    @syncing_sources = @data_sources.where(status: 'syncing')
    @error_sources = @data_sources.where(status: 'error')
    @disconnected_sources = @data_sources.where(status: 'disconnected')
  end

  def show
    authorize @data_source
    @recent_jobs = @data_source.extraction_jobs.recent.limit(10)
    @recent_records = policy_scope(RawDataRecord).where(data_source: @data_source).recent.limit(10)
    @stats = calculate_data_source_stats(@data_source)
  end

  def new
    @data_source = current_organization.data_sources.build
    authorize @data_source
  end

  def create
    @data_source = current_organization.data_sources.build(data_source_params)
    authorize @data_source

    if @data_source.save
      redirect_to @data_source, notice: 'Data source was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @data_source
  end

  def update
    authorize @data_source

    if @data_source.update(data_source_params)
      redirect_to @data_source, notice: 'Data source was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @data_source
    
    if @data_source.destroy
      redirect_to data_sources_path, notice: 'Data source was successfully deleted.'
    else
      redirect_to @data_source, alert: 'Unable to delete data source. Please try again.'
    end
  end

  def test_connection
    authorize @data_source, :test_connection?
    
    # TODO: Implement connection testing
    redirect_to @data_source, notice: 'Connection test feature coming soon.'
  end

  def sync_now
    authorize @data_source, :sync_now?
    
    unless @data_source.can_sync?
      redirect_to @data_source, alert: 'Data source is not in a state that allows synchronization.'
      return
    end

    # TODO: Implement manual sync functionality
    redirect_to @data_source, notice: 'Manual sync feature coming soon.'
  end

  private

  def set_data_source
    @data_source = policy_scope(DataSource).find(params[:id])
  end

  def data_source_params
    params.require(:data_source).permit(
      :name, :source_type, :status, :description, :sync_frequency,
      :next_sync_at,
      config: {}
    )
  end

  def calculate_data_source_stats(data_source)
    {
      total_records: data_source.raw_data_records.count,
      records_this_month: data_source.raw_data_records.where('created_at >= ?', 1.month.ago).count,
      successful_syncs: data_source.extraction_jobs.completed.count,
      failed_syncs: data_source.extraction_jobs.failed.count,
      last_sync: data_source.extraction_jobs.completed.order(:completed_at).last&.completed_at,
      next_sync: data_source.next_sync_at,
      connection_health: calculate_connection_health(data_source),
      data_freshness: calculate_data_freshness(data_source)
    }
  end

  def calculate_connection_health(data_source)
    return 'unknown' unless data_source.last_connection_test_at

    if data_source.connected?
      recent_failures = data_source.extraction_jobs.failed.where('created_at >= ?', 24.hours.ago).count
      return 'poor' if recent_failures > 3
      return 'good' if recent_failures <= 1
      'fair'
    else
      'disconnected'
    end
  end

  def calculate_data_freshness(data_source)
    last_record = data_source.raw_data_records.order(:created_at).last
    return 'no_data' unless last_record

    hours_since_last_record = (Time.current - last_record.created_at) / 1.hour
    
    case hours_since_last_record
    when 0..2 then 'very_fresh'
    when 2..6 then 'fresh'
    when 6..24 then 'moderate'
    when 24..72 then 'stale'
    else 'very_stale'
    end
  end
end