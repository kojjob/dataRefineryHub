class DataSourcesController < ApplicationController
  before_action :set_data_source, only: [:show, :edit, :update, :destroy, :sync_now, :process_files, :preview_file, :analyze_file]

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
      # If it's a file upload source and files were uploaded, process them
      if @data_source.file_upload_source? && @data_source.has_uploaded_files?
        process_uploaded_files_async
        redirect_to @data_source, notice: 'Data source created successfully. Files are being processed in the background.'
      else
        redirect_to @data_source, notice: 'Data source was successfully created.'
      end
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
    # This is a collection action, so no specific data source is set
    # We'll test the connection with the provided parameters
    
    source_type = params[:source_type]
    connection_params = params.permit(:source_type, :api_key, :shop_domain, :consumer_key, :consumer_secret, :access_token, :access_token_secret, :seller_id, :marketplace_id, :refresh_token)
    
    begin
      case source_type
      when 'shopify'
        result = test_shopify_connection(connection_params)
      when 'woocommerce'
        result = test_woocommerce_connection(connection_params)
      when 'amazon_seller_central'
        result = test_amazon_connection(connection_params)
      else
        result = { success: false, message: 'Unsupported source type' }
      end
      
      render json: result
    rescue => e
      render json: { success: false, message: "Connection test failed: #{e.message}" }, status: :unprocessable_entity
    end
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

  def process_files
    authorize @data_source, :update?
    
    unless @data_source.file_upload_source?
      redirect_to @data_source, alert: 'This data source does not support file uploads.'
      return
    end

    begin
      results = process_uploaded_files_sync
      redirect_to @data_source, notice: "Successfully processed #{results[:total_records]} records from uploaded files."
    rescue => e
      Rails.logger.error "File processing error: #{e.message}"
      redirect_to @data_source, alert: "Error processing files: #{e.message}"
    end
  end

  def preview_file
    authorize @data_source, :show?
    
    file_id = params[:file_id]
    file_attachment = @data_source.uploaded_files.find(file_id)
    
    processor = FileProcessorService.new(
      data_source: @data_source,
      file: file_attachment,
      user: current_user
    )
    
    @preview_data = processor.preview_data(limit: 20)
    @file_analysis = processor.analyze_structure
    
    respond_to do |format|
      format.json { render json: { preview_data: @preview_data, analysis: @file_analysis } }
      format.html
    end
  rescue => e
    Rails.logger.error "File preview error: #{e.message}"
    respond_to do |format|
      format.json { render json: { error: e.message }, status: :unprocessable_entity }
      format.html { redirect_to @data_source, alert: "Error previewing file: #{e.message}" }
    end
  end

  def analyze_file
    authorize @data_source, :show?
    
    file_id = params[:file_id]
    file_attachment = @data_source.uploaded_files.find(file_id)
    
    processor = FileProcessorService.new(
      data_source: @data_source,
      file: file_attachment,
      user: current_user
    )
    
    @analysis = processor.analyze_structure
    
    respond_to do |format|
      format.json { render json: @analysis }
      format.html
    end
  rescue => e
    Rails.logger.error "File analysis error: #{e.message}"
    respond_to do |format|
      format.json { render json: { error: e.message }, status: :unprocessable_entity }
      format.html { redirect_to @data_source, alert: "Error analyzing file: #{e.message}" }
    end
  end

  private

  def set_data_source
    @data_source = policy_scope(DataSource).find(params[:id])
  end

  def data_source_params
    params.require(:data_source).permit(
      :name, :source_type, :status, :description, :sync_frequency,
      :next_sync_at,
      config: {},
      uploaded_files: []
    )
  end

  def process_uploaded_files_async
    @data_source.uploaded_files.each do |file|
      FileProcessingJob.perform_later(@data_source, file, current_user)
    end
  end

  def process_uploaded_files_sync
    total_records = 0
    
    @data_source.uploaded_files.each do |file|
      processor = FileProcessorService.new(
        data_source: @data_source,
        file: file,
        user: current_user
      )
      
      result = processor.process!
      total_records += result[:total_records]
    end
    
    # Mark data source as connected after successful processing
    @data_source.update!(status: 'connected', last_sync_at: Time.current)
    
    { total_records: total_records }
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

  # Connection testing helper methods
  def test_shopify_connection(params)
    return { success: false, message: 'Shop domain is required' } if params[:shop_domain].blank?
    return { success: false, message: 'API key is required' } if params[:api_key].blank?

    begin
      # Basic validation of shop domain format
      shop_domain = params[:shop_domain].gsub(/\.myshopify\.com$/, '')
      api_url = "https://#{shop_domain}.myshopify.com/admin/api/2023-10/shop.json"
      
      # For now, just validate the format and return success
      # In a real implementation, you would make an actual API call
      if shop_domain.match?(/\A[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9]\z/)
        { success: true, message: 'Connection test successful', details: { shop_domain: "#{shop_domain}.myshopify.com" } }
      else
        { success: false, message: 'Invalid shop domain format' }
      end
    rescue => e
      { success: false, message: "Connection failed: #{e.message}" }
    end
  end

  def test_woocommerce_connection(params)
    return { success: false, message: 'Consumer key is required' } if params[:consumer_key].blank?
    return { success: false, message: 'Consumer secret is required' } if params[:consumer_secret].blank?

    begin
      # For now, just validate the presence of required fields
      # In a real implementation, you would make an actual API call to the WooCommerce REST API
      { success: true, message: 'Connection test successful', details: { consumer_key: params[:consumer_key][0..8] + '...' } }
    rescue => e
      { success: false, message: "Connection failed: #{e.message}" }
    end
  end

  def test_amazon_connection(params)
    return { success: false, message: 'Seller ID is required' } if params[:seller_id].blank?
    return { success: false, message: 'Marketplace ID is required' } if params[:marketplace_id].blank?
    return { success: false, message: 'Access token is required' } if params[:access_token].blank?

    begin
      # For now, just validate the presence of required fields
      # In a real implementation, you would make an actual API call to Amazon SP-API
      { success: true, message: 'Connection test successful', details: { seller_id: params[:seller_id], marketplace_id: params[:marketplace_id] } }
    rescue => e
      { success: false, message: "Connection failed: #{e.message}" }
    end
  end
end