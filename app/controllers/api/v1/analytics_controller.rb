class Api::V1::AnalyticsController < Api::V1::BaseController
  # GET /api/v1/analytics/dashboard_stats
  def dashboard_stats
    date_params = date_range_params

    stats = {
      overview: {
        total_data_sources: @current_organization.data_sources.count,
        connected_sources: @current_organization.data_sources.connected.count,
        active_syncs: @current_organization.extraction_jobs.running.count,
        total_records: @current_organization.raw_data_records.count
      },
      period_stats: calculate_period_stats(date_params),
      recent_activity: recent_activity_summary,
      sync_health: calculate_sync_health,
      growth_metrics: calculate_growth_metrics(date_params)
    }

    render_success({
      dashboard_stats: stats,
      date_range: date_params,
      generated_at: Time.current.iso8601
    })
  end

  # GET /api/v1/analytics/revenue_metrics
  def revenue_metrics
    date_params = date_range_params

    # Calculate revenue metrics from processed order data
    orders = @current_organization.processed_orders
                                  .where(order_date: date_params[:start_date]..date_params[:end_date])

    metrics = {
      total_revenue: orders.sum(:total_amount) || 0,
      order_count: orders.count,
      average_order_value: orders.average(:total_amount)&.round(2) || 0,
      revenue_by_platform: revenue_by_platform(orders),
      revenue_trend: revenue_over_time(orders, date_params),
      top_products: top_products_by_revenue(orders),
      revenue_by_status: revenue_by_order_status(orders)
    }

    render_success({
      revenue_metrics: metrics,
      date_range: date_params
    })
  end

  # GET /api/v1/analytics/customer_metrics
  def customer_metrics
    date_params = date_range_params

    customers = @current_organization.processed_customers
    new_customers = customers.where(created_at: date_params[:start_date]..date_params[:end_date])

    metrics = {
      total_customers: customers.count,
      new_customers: new_customers.count,
      customers_by_platform: customers.group(:platform).count,
      customer_acquisition_trend: customer_acquisition_over_time(date_params),
      customer_lifetime_value: calculate_customer_ltv,
      repeat_customer_rate: calculate_repeat_customer_rate,
      customer_segments: calculate_customer_segments
    }

    render_success({
      customer_metrics: metrics,
      date_range: date_params
    })
  end

  # GET /api/v1/analytics/product_metrics
  def product_metrics
    date_params = date_range_params

    products = @current_organization.processed_products
    orders = @current_organization.processed_orders
                                  .where(order_date: date_params[:start_date]..date_params[:end_date])

    metrics = {
      total_products: products.count,
      products_sold: orders.sum(:quantity) || 0,
      top_selling_products: top_selling_products(orders),
      product_performance: product_performance_metrics(orders),
      inventory_alerts: inventory_alerts,
      category_performance: category_performance_metrics(orders)
    }

    render_success({
      product_metrics: metrics,
      date_range: date_params
    })
  end

  # GET /api/v1/analytics/order_metrics
  def order_metrics
    date_params = date_range_params

    orders = @current_organization.processed_orders
                                  .where(order_date: date_params[:start_date]..date_params[:end_date])

    metrics = {
      total_orders: orders.count,
      orders_by_status: orders.group(:status).count,
      orders_by_platform: orders.group(:platform).count,
      average_processing_time: calculate_avg_processing_time(orders),
      order_frequency: calculate_order_frequency(date_params),
      fulfillment_metrics: calculate_fulfillment_metrics(orders),
      seasonal_trends: calculate_seasonal_trends(orders)
    }

    render_success({
      order_metrics: metrics,
      date_range: date_params
    })
  end

  # GET /api/v1/analytics/trend_analysis
  def trend_analysis
    date_params = date_range_params
    interval = params[:interval] || "daily" # daily, weekly, monthly

    trends = {
      revenue_trend: calculate_trend_data("revenue", date_params, interval),
      order_trend: calculate_trend_data("orders", date_params, interval),
      customer_trend: calculate_trend_data("customers", date_params, interval),
      product_trend: calculate_trend_data("products", date_params, interval),
      growth_rates: calculate_growth_rates(date_params, interval),
      seasonality_analysis: calculate_seasonality_analysis(date_params)
    }

    render_success({
      trend_analysis: trends,
      date_range: date_params,
      interval: interval
    })
  end

  # GET /api/v1/analytics/revenue_over_time
  def revenue_over_time
    date_params = date_range_params
    interval = params[:interval] || "daily"

    data = calculate_time_series_revenue(date_params, interval)

    render_success({
      revenue_over_time: data,
      date_range: date_params,
      interval: interval
    })
  end

  # GET /api/v1/analytics/orders_over_time
  def orders_over_time
    date_params = date_range_params
    interval = params[:interval] || "daily"

    data = calculate_time_series_orders(date_params, interval)

    render_success({
      orders_over_time: data,
      date_range: date_params,
      interval: interval
    })
  end

  # GET /api/v1/analytics/customers_over_time
  def customers_over_time
    date_params = date_range_params
    interval = params[:interval] || "daily"

    data = calculate_time_series_customers(date_params, interval)

    render_success({
      customers_over_time: data,
      date_range: date_params,
      interval: interval
    })
  end

  # POST /api/v1/analytics/export_report
  def export_report
    export_params = params.require(:export).permit(:report_type, :format, :date_range, :filters)

    # Queue export job
    job = ReportExportJob.perform_later(
      @current_organization.id,
      current_user.id,
      export_params.to_h
    )

    render_success({
      export_job_id: job.job_id,
      status: "queued",
      estimated_completion: 10.minutes.from_now,
      download_url: nil # Will be available after completion
    }, "Export job queued successfully")
  end

  # GET /api/v1/analytics/export_status/:job_id
  def export_status
    job_id = params[:job_id]

    # Check job status (implement job tracking)
    status = check_export_job_status(job_id)

    render_success({
      job_id: job_id,
      status: status[:status],
      progress: status[:progress],
      download_url: status[:download_url],
      error_message: status[:error_message],
      expires_at: status[:expires_at]
    })
  end

  # GET /api/v1/analytics/download_export/:job_id
  def download_export
    job_id = sanitize_job_id(params[:job_id])

    # Find and serve the export file
    export_file = find_export_file(job_id)

    if export_file && File.exist?(export_file[:path])
      begin
        # SECURITY FIX: Validate file path to prevent directory traversal
        safe_file_path = validate_export_file_path!(export_file[:path])
        safe_filename = sanitize_export_filename(export_file[:filename])
        
        send_file safe_file_path,
                  filename: safe_filename,
                  type: export_file[:content_type],
                  disposition: "attachment"
      rescue SecurityError => e
        Rails.logger.warn "Export file access denied: #{e.message}"
        render_forbidden("File access denied")
      rescue ArgumentError => e
        Rails.logger.warn "Invalid export file: #{e.message}"
        render_not_found("Export file")
      end
    else
      render_not_found("Export file")
    end
  end

  private

  def calculate_period_stats(date_params)
    {
      records_processed: @current_organization.raw_data_records
                                            .where(created_at: date_params[:start_date]..date_params[:end_date])
                                            .count,
      successful_syncs: @current_organization.extraction_jobs
                                           .completed
                                           .where(created_at: date_params[:start_date]..date_params[:end_date])
                                           .count,
      failed_syncs: @current_organization.extraction_jobs
                                       .failed
                                       .where(created_at: date_params[:start_date]..date_params[:end_date])
                                       .count,
      data_sources_added: @current_organization.data_sources
                                             .where(created_at: date_params[:start_date]..date_params[:end_date])
                                             .count
    }
  end

  def recent_activity_summary
    recent_jobs = @current_organization.extraction_jobs
                                     .includes(:data_source)
                                     .order(created_at: :desc)
                                     .limit(10)

    recent_jobs.map do |job|
      {
        id: job.id,
        data_source_name: job.data_source.name,
        status: job.status,
        records_processed: job.records_processed || 0,
        started_at: job.started_at&.iso8601,
        completed_at: job.completed_at&.iso8601
      }
    end
  end

  def calculate_sync_health
    recent_jobs = @current_organization.extraction_jobs.where("created_at >= ?", 24.hours.ago)

    return { status: "unknown", details: "No recent sync activity" } if recent_jobs.empty?

    success_rate = recent_jobs.completed.count.to_f / recent_jobs.count
    avg_duration = recent_jobs.completed.average("EXTRACT(EPOCH FROM (completed_at - started_at))")&.to_f

    {
      status: case success_rate
              when 0.95..1.0 then "excellent"
              when 0.85..0.94 then "good"
              when 0.70..0.84 then "fair"
              else "poor"
              end,
      success_rate: (success_rate * 100).round(1),
      avg_duration_seconds: avg_duration&.round(2),
      total_jobs_24h: recent_jobs.count,
      failed_jobs_24h: recent_jobs.failed.count
    }
  end

  def calculate_growth_metrics(date_params)
    # Compare current period with previous period of same length
    period_length = (date_params[:end_date] - date_params[:start_date]).days
    prev_start = date_params[:start_date] - period_length.days
    prev_end = date_params[:start_date] - 1.day

    current_records = @current_organization.raw_data_records
                                         .where(created_at: date_params[:start_date]..date_params[:end_date])
                                         .count

    previous_records = @current_organization.raw_data_records
                                          .where(created_at: prev_start..prev_end)
                                          .count

    growth_rate = previous_records > 0 ?
                 ((current_records - previous_records).to_f / previous_records * 100).round(2) :
                 0

    {
      records_growth_rate: growth_rate,
      current_period_records: current_records,
      previous_period_records: previous_records
    }
  end

  def revenue_by_platform(orders)
    orders.group(:platform).sum(:total_amount)
  end

  def revenue_over_time(orders, date_params)
    # Group by day and sum revenue
    orders.group_by_day(:order_date, range: date_params[:start_date]..date_params[:end_date])
          .sum(:total_amount)
          .map { |date, amount| { date: date.iso8601, revenue: amount } }
  end

  def top_products_by_revenue(orders)
    orders.joins(:processed_order_items)
          .group("processed_order_items.product_name")
          .sum("processed_order_items.line_total")
          .sort_by { |_, total| -total }
          .first(10)
          .map { |name, total| { product_name: name, revenue: total } }
  end

  def revenue_by_order_status(orders)
    orders.group(:status).sum(:total_amount)
  end

  def calculate_time_series_revenue(date_params, interval)
    case interval
    when "hourly"
      group_method = :group_by_hour
    when "daily"
      group_method = :group_by_day
    when "weekly"
      group_method = :group_by_week
    when "monthly"
      group_method = :group_by_month
    else
      group_method = :group_by_day
    end

    @current_organization.processed_orders
                        .where(order_date: date_params[:start_date]..date_params[:end_date])
                        .send(group_method, :order_date, range: date_params[:start_date]..date_params[:end_date])
                        .sum(:total_amount)
                        .map { |period, amount| { period: period.iso8601, revenue: amount } }
  end

  def calculate_time_series_orders(date_params, interval)
    case interval
    when "hourly"
      group_method = :group_by_hour
    when "daily"
      group_method = :group_by_day
    when "weekly"
      group_method = :group_by_week
    when "monthly"
      group_method = :group_by_month
    else
      group_method = :group_by_day
    end

    @current_organization.processed_orders
                        .where(order_date: date_params[:start_date]..date_params[:end_date])
                        .send(group_method, :order_date, range: date_params[:start_date]..date_params[:end_date])
                        .count
                        .map { |period, count| { period: period.iso8601, orders: count } }
  end

  def calculate_time_series_customers(date_params, interval)
    case interval
    when "hourly"
      group_method = :group_by_hour
    when "daily"
      group_method = :group_by_day
    when "weekly"
      group_method = :group_by_week
    when "monthly"
      group_method = :group_by_month
    else
      group_method = :group_by_day
    end

    @current_organization.processed_customers
                        .where(created_at: date_params[:start_date]..date_params[:end_date])
                        .send(group_method, :created_at, range: date_params[:start_date]..date_params[:end_date])
                        .count
                        .map { |period, count| { period: period.iso8601, customers: count } }
  end

  # Placeholder methods for advanced analytics (implement based on data models)
  def customer_acquisition_over_time(date_params)
    []
  end

  def calculate_customer_ltv
    0
  end

  def calculate_repeat_customer_rate
    0
  end

  def calculate_customer_segments
    {}
  end

  def top_selling_products(orders)
    []
  end

  def product_performance_metrics(orders)
    {}
  end

  def inventory_alerts
    []
  end

  def category_performance_metrics(orders)
    {}
  end

  def calculate_avg_processing_time(orders)
    0
  end

  def calculate_order_frequency(date_params)
    {}
  end

  def calculate_fulfillment_metrics(orders)
    {}
  end

  def calculate_seasonal_trends(orders)
    {}
  end

  def calculate_trend_data(metric, date_params, interval)
    []
  end

  def calculate_growth_rates(date_params, interval)
    {}
  end

  def calculate_seasonality_analysis(date_params)
    {}
  end

  def check_export_job_status(job_id)
    {
      status: "completed",
      progress: 100,
      download_url: nil,
      error_message: nil,
      expires_at: nil
    }
  end

  def find_export_file(job_id)
    nil
  end

  # SECURITY METHODS: File validation

  def sanitize_job_id(job_id)
    return nil if job_id.blank?
    
    # Allow only alphanumeric characters, hyphens and underscores
    job_id.to_s.gsub(/[^a-zA-Z0-9\-_]/, "").truncate(50)
  end

  def validate_export_file_path!(file_path)
    return nil if file_path.blank?

    # Define allowed directories for export files
    allowed_dirs = [
      Rails.root.join("tmp", "exports").to_s,
      Rails.root.join("storage", "exports").to_s,
      Rails.root.join("public", "exports").to_s
    ]

    # Resolve absolute path to prevent path traversal
    resolved_path = File.expand_path(file_path)

    # Check if path is within allowed directories
    unless allowed_dirs.any? { |dir| resolved_path.start_with?(File.expand_path(dir)) }
      raise SecurityError, "File access denied: path outside allowed directories"
    end

    # Check if file exists and is a regular file
    unless File.exist?(resolved_path) && File.file?(resolved_path)
      raise ArgumentError, "Invalid file: #{file_path}"
    end

    # Check file size (100MB limit for exports)
    if File.size(resolved_path) > 100.megabytes
      raise ArgumentError, "File too large: #{file_path}"
    end

    resolved_path
  end

  def sanitize_export_filename(filename)
    return "export.csv" if filename.blank?

    # Remove dangerous characters and normalize
    safe_name = filename.gsub(/[^a-zA-Z0-9\-_\.]/, "_")
    safe_name = safe_name.gsub(/_{2,}/, "_") # Remove multiple underscores
    safe_name.truncate(100)
  end
end
