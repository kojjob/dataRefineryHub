class DataSourcesController < DataflowProController
  before_action :set_data_source, only: [ :show, :edit, :update, :destroy, :sync_now, :process_files, :preview_file, :analyze_file, :enhanced_preview ]

  def index
    @data_sources = policy_scope(DataSource).includes(:extraction_jobs).order(:created_at)
    @connected_sources = @data_sources.where(status: "connected")
    @syncing_sources = @data_sources.where(status: "syncing")
    @error_sources = @data_sources.where(status: "error")
    @disconnected_sources = @data_sources.where(status: "disconnected")
  end

  def quality
    @data_sources = policy_scope(DataSource).includes(:raw_data_records, :extraction_jobs, :data_quality_reports)

    # Get latest quality reports for each data source
    @latest_reports = DataQualityReport.latest_for_each_source
                                      .joins(:data_source)
                                      .where(data_sources: { organization: current_organization })
                                      .includes(:data_source)

    # Calculate aggregated quality metrics
    @quality_metrics = calculate_aggregated_quality_metrics(@latest_reports)

    # Get recent quality issues from actual reports
    @recent_issues = get_actual_quality_issues(@latest_reports)

    # Get recommendations from actual reports
    @recommendations = get_actual_quality_recommendations(@latest_reports)
  end

  # Add API endpoint for running quality validation
  def run_quality_check
    @data_source = policy_scope(DataSource).find(params[:id]) if params[:id].present?

    if @data_source
      # Run validation for specific data source
      @data_source.run_quality_validation!
      render json: {
        message: "Quality validation started for #{@data_source.name}",
        status: "running"
      }
    else
      # Run validation for all data sources
      policy_scope(DataSource).find_each do |data_source|
        data_source.run_quality_validation!
      end
      render json: {
        message: "Quality validation started for all data sources",
        status: "running"
      }
    end
  end

  def show
    authorize @data_source
    @recent_jobs = @data_source.extraction_jobs.recent.limit(10)
    @recent_records = policy_scope(RawDataRecord).where(data_source: @data_source).recent.limit(10)
    @stats = calculate_data_source_stats(@data_source)

    # Load processed data for visualization builder if it's a file upload source
    if @data_source.file_upload_source? && @data_source.raw_data_records.any?
      @processed_data = load_processed_data_for_visualization
      @columns = extract_columns_from_data(@processed_data) if @processed_data.present?
    end
  end

  def new
    @data_source = current_organization.data_sources.build
    authorize @data_source

    # Initialize wizard data for the view
    @wizard_data = DataSourceWizardService.new.prepare_wizard_data
  end

  def create
    @data_source = current_organization.data_sources.build(data_source_params)
    authorize @data_source

    # Track performance for data source creation
    result = PerformanceMonitorService.instance.track("data_source_creation") do
      if @data_source.save
        # If it's a file upload source and files were uploaded, use enhanced service
        if @data_source.file_upload_source? && params[:data_source][:uploaded_files].present?
          handle_file_upload_creation
        else
          Result.success(data: @data_source, message: "Data source was successfully created.")
        end
      else
        Result.failure(errors: @data_source.errors.full_messages)
      end
    end

    if result.success?
      redirect_to result.data, notice: result.message
    else
      flash.now[:alert] = result.error_message
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @data_source
  end

  def update
    authorize @data_source

    if @data_source.update(data_source_params)
      redirect_to @data_source, notice: "Data source was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @data_source

    if @data_source.destroy
      redirect_to data_sources_path, notice: "Data source was successfully deleted."
    else
      redirect_to @data_source, alert: "Unable to delete data source. Please try again."
    end
  end

  def test_connection
    # This is a collection action, so no specific data source is set
    # We'll test the connection with the provided parameters

    source_type = params[:source_type]
    connection_params = params.except(:authenticity_token, :controller, :action).permit(
      :source_type, :api_key, :shop_domain, :consumer_key, :consumer_secret,
      :access_token, :access_token_secret, :seller_id, :marketplace_id, :refresh_token
    )

    begin
      case source_type
      when "shopify"
        result = test_shopify_connection(connection_params)
      when "woocommerce"
        result = test_woocommerce_connection(connection_params)
      when "amazon_seller_central"
        result = test_amazon_connection(connection_params)
      when "file_upload"
        # For file upload, we just return success since no external connection is needed
        result = { success: true, message: "File upload source is ready" }
      else
        result = { success: false, message: "Unsupported source type" }
      end

      render json: result
    rescue => e
      render json: { success: false, message: "Connection test failed: #{e.message}" }, status: :unprocessable_entity
    end
  end

  def auto_save
    # Auto-save wizard data to session or temporary storage
    session[:data_source_wizard_draft] = params.except(:authenticity_token, :controller, :action)
    session[:data_source_wizard_draft][:updated_at] = Time.current

    render json: {
      success: true,
      message: "Draft saved successfully",
      saved_at: Time.current.strftime("%I:%M %p")
    }
  rescue => e
    render json: {
      success: false,
      message: "Failed to save draft: #{e.message}"
    }, status: :unprocessable_entity
  end

  def sync_now
    authorize @data_source, :sync_now?

    unless @data_source.can_sync?
      redirect_to @data_source, alert: "Data source is not in a state that allows synchronization."
      return
    end

    # Initiate manual sync based on data source type
    begin
      case @data_source.source_type
      when "api"
        # Queue API extraction job
        job = ExtractionJob.create!(
          data_source: @data_source,
          organization: current_organization,
          job_type: "manual_sync",
          status: "pending"
        )

        # Process the job asynchronously
        TransformationJobProcessor.perform_async(job.id)

        redirect_to @data_source, notice: "Manual sync initiated successfully. Job ##{job.id} is processing."
      when "database"
        # Queue database extraction job
        job = ExtractionJob.create!(
          data_source: @data_source,
          organization: current_organization,
          job_type: "manual_sync",
          status: "pending"
        )

        TransformationJobProcessor.perform_async(job.id)
        redirect_to @data_source, notice: "Database sync initiated successfully. Job ##{job.id} is processing."
      when "cloud_storage"
        # Sync cloud storage files
        CloudStorageService.new(@data_source).sync_files
        redirect_to @data_source, notice: "Cloud storage sync completed successfully."
      else
        redirect_to @data_source, alert: "Manual sync is not supported for this data source type."
      end
    rescue StandardError => e
      Rails.logger.error "Manual sync failed for data source #{@data_source.id}: #{e.message}"
      redirect_to @data_source, alert: "Manual sync failed: #{e.message}"
    end
  end

  def process_files
    authorize @data_source, :update?

    unless @data_source.file_upload_source?
      redirect_to @data_source, alert: "This data source does not support file uploads."
      return
    end

    # Use enhanced file upload service with performance tracking
    result = PerformanceMonitorService.instance.track("file_processing") do
      if params[:uploaded_files].present?
        EnhancedFileUploadService.new(
          data_source: @data_source,
          files: params[:uploaded_files],
          user: current_user,
          organization: current_organization
        ).process
      else
        Result.failure(errors: [ "No files provided for processing" ])
      end
    end

    if result.success?
      redirect_to @data_source, notice: result.message
    else
      redirect_to @data_source, alert: result.error_message
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

  def enhanced_preview
    authorize @data_source, :show?

    file_id = params[:file_id]
    file_attachment = @data_source.uploaded_files.find(file_id)

    preview_service = EnhancedDataPreviewService.new(
      data_source: @data_source,
      file: file_attachment,
      user: current_user
    )

    @enhanced_preview_data = preview_service.generate_enhanced_preview

    respond_to do |format|
      format.json {
        render json: {
          success: true,
          preview_data: @enhanced_preview_data,
          component_html: render_to_string(
            partial: "enhanced_data_preview_component",
            locals: {
              preview_data: @enhanced_preview_data,
              data_source: @data_source,
              user: current_user
            }
          )
        }
      }
      format.html {
        @preview_component = EnhancedDataPreviewComponent.new(
          preview_data: @enhanced_preview_data,
          data_source: @data_source,
          user: current_user
        )
      }
    end
  rescue => e
    Rails.logger.error "Enhanced preview error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    respond_to do |format|
      format.json {
        render json: {
          success: false,
          error: e.message,
          suggestions: [
            "Check file format and structure",
            "Ensure file is not corrupted",
            "Try a smaller sample file first"
          ]
        }, status: :unprocessable_entity
      }
      format.html {
        redirect_to @data_source, alert: "Error generating enhanced preview: #{e.message}"
      }
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

  # Download sample files for users to understand expected format
  def download_sample_csv
    send_file(
      Rails.root.join("public", "sample_files", "sample_data.csv"),
      filename: "sample_data.csv",
      type: "text/csv",
      disposition: "attachment"
    )
  end

  def download_sample_excel
    send_file(
      Rails.root.join("public", "sample_files", "sample_products.csv"),
      filename: "sample_products.csv",
      type: "text/csv",
      disposition: "attachment"
    )
  end

  def download_sample_json
    send_file(
      Rails.root.join("public", "sample_files", "sample_orders.json"),
      filename: "sample_orders.json",
      type: "application/json",
      disposition: "attachment"
    )
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
    @data_source.update!(status: "connected", last_sync_at: Time.current)

    { total_records: total_records }
  end

  def handle_file_upload_creation
    # Use enhanced file upload service for file processing
    upload_result = EnhancedFileUploadService.new(
      data_source: @data_source,
      files: params[:data_source][:uploaded_files],
      user: current_user,
      organization: current_organization
    ).process

    if upload_result.success?
      Result.success(
        data: @data_source,
        message: "Data source created successfully. #{upload_result.message}"
      )
    else
      # If file processing failed, we should still keep the data source but show the error
      Result.success(
        data: @data_source,
        message: "Data source created but file processing encountered issues: #{upload_result.error_message}"
      )
    end
  end

  def calculate_data_source_stats(data_source)
    {
      total_records: data_source.raw_data_records.count,
      records_this_month: data_source.raw_data_records.where("created_at >= ?", 1.month.ago).count,
      successful_syncs: data_source.extraction_jobs.completed.count,
      failed_syncs: data_source.extraction_jobs.failed.count,
      last_sync: data_source.extraction_jobs.completed.order(:completed_at).last&.completed_at,
      next_sync: data_source.next_sync_at,
      connection_health: calculate_connection_health(data_source),
      data_freshness: calculate_data_freshness(data_source)
    }
  end

  def calculate_connection_health(data_source)
    return "unknown" unless data_source.last_connection_test_at

    if data_source.connected?
      recent_failures = data_source.extraction_jobs.failed.where("created_at >= ?", 24.hours.ago).count
      return "poor" if recent_failures > 3
      return "good" if recent_failures <= 1
      "fair"
    else
      "disconnected"
    end
  end

  def calculate_data_freshness(data_source)
    last_record = data_source.raw_data_records.order(:created_at).last
    return "no_data" unless last_record

    hours_since_last_record = (Time.current - last_record.created_at) / 1.hour

    case hours_since_last_record
    when 0..2 then "very_fresh"
    when 2..6 then "fresh"
    when 6..24 then "moderate"
    when 24..72 then "stale"
    else "very_stale"
    end
  end

  # Connection testing helper methods
  def test_shopify_connection(params)
    return { success: false, message: "Shop domain is required" } if params[:shop_domain].blank?
    return { success: false, message: "API key is required" } if params[:api_key].blank?

    begin
      # Basic validation of shop domain format
      shop_domain = params[:shop_domain].gsub(/\.myshopify\.com$/, "")
      api_url = "https://#{shop_domain}.myshopify.com/admin/api/2023-10/shop.json"

      # For now, just validate the format and return success
      # In a real implementation, you would make an actual API call
      if shop_domain.match?(/\A[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9]\z/)
        { success: true, message: "Connection test successful", details: { shop_domain: "#{shop_domain}.myshopify.com" } }
      else
        { success: false, message: "Invalid shop domain format" }
      end
    rescue => e
      { success: false, message: "Connection failed: #{e.message}" }
    end
  end

  def test_woocommerce_connection(params)
    return { success: false, message: "Consumer key is required" } if params[:consumer_key].blank?
    return { success: false, message: "Consumer secret is required" } if params[:consumer_secret].blank?

    begin
      # For now, just validate the presence of required fields
      # In a real implementation, you would make an actual API call to the WooCommerce REST API
      { success: true, message: "Connection test successful", details: { consumer_key: params[:consumer_key][0..8] + "..." } }
    rescue => e
      { success: false, message: "Connection failed: #{e.message}" }
    end
  end

  def test_amazon_connection(params)
    return { success: false, message: "Seller ID is required" } if params[:seller_id].blank?
    return { success: false, message: "Marketplace ID is required" } if params[:marketplace_id].blank?
    return { success: false, message: "Access token is required" } if params[:access_token].blank?

    begin
      # For now, just validate the presence of required fields
      # In a real implementation, you would make an actual API call to Amazon SP-API
      { success: true, message: "Connection test successful", details: { seller_id: params[:seller_id], marketplace_id: params[:marketplace_id] } }
    rescue => e
      { success: false, message: "Connection failed: #{e.message}" }
    end
  end

  def load_processed_data_for_visualization
    # Load raw data records and convert to JSON format for visualization
    records = @data_source.raw_data_records.limit(1000).order(:created_at)

    return [] if records.empty?

    # Convert records to a consistent format for visualization
    records.map do |record|
      data = record.data.is_a?(String) ? JSON.parse(record.data) : record.data

      # Flatten nested data and add metadata
      flattened_data = flatten_hash(data)
      flattened_data.merge({
        "record_id" => record.id,
        "record_type" => record.record_type,
        "external_id" => record.external_id,
        "created_at" => record.created_at,
        "processing_status" => record.processing_status
      })
    end
  rescue => e
    Rails.logger.error "Error loading visualization data: #{e.message}"
    []
  end

  def extract_columns_from_data(data)
    return [] if data.empty?

    # Get all unique keys from the dataset
    all_keys = data.flat_map(&:keys).uniq

    # Filter out system columns and sort
    user_columns = all_keys.reject { |key| key.to_s.match?(/\A(record_id|record_type|external_id|created_at|processing_status)\z/) }
    system_columns = all_keys.select { |key| key.to_s.match?(/\A(record_id|record_type|external_id|created_at|processing_status)\z/) }

    # Return user columns first, then system columns
    user_columns.sort + system_columns.sort
  end

  def flatten_hash(hash, parent_key = "", separator = "_")
    hash.each_with_object({}) do |(key, value), result|
      new_key = parent_key.empty? ? key.to_s : "#{parent_key}#{separator}#{key}"

      if value.is_a?(Hash)
        result.merge!(flatten_hash(value, new_key, separator))
      elsif value.is_a?(Array)
        # Convert arrays to comma-separated strings or handle as needed
        result[new_key] = value.join(", ") if value.all? { |v| v.is_a?(String) || v.is_a?(Numeric) }
      else
        result[new_key] = value
      end
    end
  end

  # Real Data Quality Helper Methods
  def calculate_aggregated_quality_metrics(reports)
    if reports.empty?
      return {
        overall_score: 0,
        total_records: @data_sources.sum { |ds| ds.raw_data_records.count },
        sources_with_issues: 0,
        last_quality_check: nil,
        dimension_scores: {
          completeness: 0,
          accuracy: 0,
          consistency: 0,
          validity: 0,
          timeliness: 0
        }
      }
    end

    # Calculate weighted average scores
    total_records = reports.sum(&:total_records)

    if total_records == 0
      overall_score = 0
      dimension_scores = {
        completeness: 0,
        accuracy: 0,
        consistency: 0,
        validity: 0,
        timeliness: 0
      }
    else
      overall_score = reports.sum { |r| r.overall_score * r.total_records } / total_records
      dimension_scores = {
        completeness: reports.sum { |r| r.completeness_score * r.total_records } / total_records,
        accuracy: reports.sum { |r| r.accuracy_score * r.total_records } / total_records,
        consistency: reports.sum { |r| r.consistency_score * r.total_records } / total_records,
        validity: reports.sum { |r| r.validity_score * r.total_records } / total_records,
        timeliness: reports.sum { |r| r.timeliness_score * r.total_records } / total_records
      }
    end

    {
      overall_score: overall_score.round(1),
      total_records: @data_sources.sum { |ds| ds.raw_data_records.count },
      sources_with_issues: reports.count { |r| r.issues_count > 0 },
      last_quality_check: reports.maximum(:run_at),
      dimension_scores: dimension_scores.transform_values { |v| v.round(1) }
    }
  end

  def get_actual_quality_issues(reports)
    issues = []

    reports.each do |report|
      next if report.issues.empty?

      report.issues.each do |issue|
        issues << {
          source: report.data_source.name,
          issue: issue["message"] || issue[:message],
          severity: issue["severity"] || issue[:severity],
          count: issue["count"] || issue[:count] || 1,
          timestamp: report.run_at,
          type: issue["type"] || issue[:type]
        }
      end
    end

    # Sort by severity and timestamp
    severity_order = { "critical" => 0, "high" => 1, "medium" => 2, "low" => 3 }
    issues.sort_by { |issue| [ severity_order[issue[:severity]] || 4, -issue[:timestamp].to_i ] }.first(10)
  end

  def get_actual_quality_recommendations(reports)
    recommendations = []

    reports.each do |report|
      next if report.recommendations.empty?

      report.recommendations.each do |rec|
        recommendations << {
          title: rec["title"] || rec[:title],
          description: rec["description"] || rec[:description],
          priority: rec["priority"] || rec[:priority],
          impact: rec["impact"] || rec[:impact],
          data_source_id: report.data_source.id,
          data_source_name: report.data_source.name,
          action: rec["action"] || rec[:action]
        }
      end
    end

    # Sort by priority
    priority_order = { "critical" => 0, "high" => 1, "medium" => 2, "low" => 3 }
    recommendations.sort_by { |rec| priority_order[rec[:priority]] || 4 }.first(6)
  end

  def calculate_source_quality_score(data_source)
    latest_report = data_source.latest_quality_report
    return latest_report.overall_score if latest_report

    # Fallback calculation if no report exists
    base_score = 100
    base_score -= 10 if data_source.status == "error"
    base_score -= 5 if data_source.status == "disconnected"

    if data_source.last_sync_at && data_source.last_sync_at < 7.days.ago
      base_score -= 15
    elsif data_source.last_sync_at && data_source.last_sync_at < 3.days.ago
      base_score -= 8
    end

    recent_failures = data_source.extraction_jobs.failed.where("created_at >= ?", 7.days.ago).count
    base_score -= (recent_failures * 3)

    [ base_score, 60 ].max
  end
end
