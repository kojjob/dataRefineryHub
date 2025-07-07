class Analytics::DashboardController < Analytics::BaseController
  def index
    authorize :analytics, :index?

    @date_range = params[:date_range] || "30_days"
    @start_date, @end_date = calculate_date_range(@date_range)

    # Calculate comprehensive e-commerce insights
    @ecommerce_insights = calculate_ecommerce_insights

    # Data source metrics
    @total_data_sources = current_organization.data_sources.count
    @active_data_sources = current_organization.data_sources.connected.count
    @syncing_data_sources = current_organization.data_sources.where(status: "syncing").count
    @error_data_sources = current_organization.data_sources.where(status: "error").count
    @data_sources_by_type = current_organization.data_sources.group(:source_type).count
    @data_sources_by_status = current_organization.data_sources.group(:status).count

    # Extraction job metrics
    extraction_jobs = extraction_jobs_scope
    @total_jobs = extraction_jobs.count
    @successful_jobs = extraction_jobs.completed.count
    @failed_jobs = extraction_jobs.failed.count
    @running_jobs = extraction_jobs.running.count
    @queued_jobs = extraction_jobs.where(status: "queued").count
    @success_rate = @total_jobs > 0 ? (@successful_jobs.to_f / @total_jobs * 100).round(1) : 0

    # Data volume metrics
    raw_data_records = raw_data_records_scope
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
      @job_duration_variance = calculate_variance(durations)
    else
      @avg_job_duration = 0
      @fastest_job_duration = 0
      @slowest_job_duration = 0
      @job_duration_variance = 0
    end

    # Error analysis
    failed_jobs = extraction_jobs.failed
    @common_errors = failed_jobs.group(:error_message).count.sort_by { |_k, v| -v }.first(5)
    @errors_by_source = failed_jobs.joins(:data_source).group("data_sources.source_type").count

    # Growth trends
    calculate_growth_trends

    # Top performing data sources
    @top_data_sources = current_organization.data_sources
      .joins(:raw_data_records)
      .where(raw_data_records: { created_at: @start_date..@end_date })
      .group("data_sources.name")
      .count("raw_data_records.id")
      .sort_by { |_k, v| -v }
      .first(5)

    # Daily activity trend
    @daily_activity = raw_data_records_scope
      .group_by_day(:created_at, range: @start_date..@end_date)
      .count

    # Recent errors
    @recent_errors = extraction_jobs
      .failed
      .includes(:data_source)
      .order(created_at: :desc)
      .limit(10)
  end

  private

  def calculate_ecommerce_insights
    insights = {
      revenue: {},
      orders: {},
      customers: {},
      products: {},
      inventory: {},
      platform_performance: {},
      fulfillment: {},
      acquisition: {},
      trends: {},
      growth: {},
      segments: {},
      funnels: {},
      risks: {},
      opportunities: {}
    }

    # Get all relevant records
    order_records = order_records_scope
    customer_records = customer_records_scope
    product_records = product_records_scope

    insights[:revenue] = calculate_revenue_metrics(order_records) if order_records.any?
    insights[:orders] = calculate_order_analytics(order_records) if order_records.any?
    insights[:customers] = calculate_customer_analytics(customer_records) if customer_records.any?
    insights[:products] = calculate_product_analytics(product_records) if product_records.any?

    insights
  end

  def calculate_revenue_metrics(order_records)
    {
      total: order_records.sum("CAST(raw_data::json->>'total_price' AS DECIMAL)"),
      average_order_value: order_records.average("CAST(raw_data::json->>'total_price' AS DECIMAL)"),
      currency: order_records.first&.raw_data&.dig("currency") || "USD"
    }
  end

  def calculate_order_analytics(order_records)
    {
      total_count: order_records.count,
      completed_count: order_records.where("raw_data::json->>'fulfillment_status' = ?", "fulfilled").count,
      pending_count: order_records.where("raw_data::json->>'fulfillment_status' IS NULL OR raw_data::json->>'fulfillment_status' = ?", "pending").count,
      cancelled_count: order_records.where("raw_data::json->>'cancelled_at' IS NOT NULL").count
    }
  end

  def calculate_customer_analytics(customer_records)
    {
      total_customers: customer_records.count,
      new_customers: customer_records.where("raw_data::json->>'created_at' >= ?", @start_date).count,
      returning_customers: customer_records.where("CAST(raw_data::json->>'orders_count' AS INTEGER) > 1").count
    }
  end

  def calculate_product_analytics(product_records)
    {
      total_products: product_records.count,
      published_products: product_records.where("raw_data::json->>'status' = ?", "active").count,
      out_of_stock: product_records.joins("JOIN LATERAL json_array_elements(raw_data::json->'variants') AS variant(data) ON true")
                                  .where("CAST(variant.data->>'inventory_quantity' AS INTEGER) <= 0").count
    }
  end

  def calculate_growth_trends
    # Calculate week-over-week and month-over-month growth
    current_week_start = 1.week.ago.beginning_of_week
    previous_week_start = 2.weeks.ago.beginning_of_week

    current_month_start = 1.month.ago.beginning_of_month
    previous_month_start = 2.months.ago.beginning_of_month

    # Weekly trends
    current_week_orders = order_records_scope.where(created_at: current_week_start..Time.current)
    previous_week_orders = order_records_scope.where(created_at: previous_week_start..current_week_start)

    @weekly_order_growth = calculate_percentage_change(
      previous_week_orders.count,
      current_week_orders.count
    )

    @weekly_revenue_growth = calculate_percentage_change(
      previous_week_orders.sum("CAST(raw_data::json->>'total_price' AS DECIMAL)"),
      current_week_orders.sum("CAST(raw_data::json->>'total_price' AS DECIMAL)")
    )

    # Monthly trends
    current_month_orders = order_records_scope.where(created_at: current_month_start..Time.current)
    previous_month_orders = order_records_scope.where(created_at: previous_month_start..current_month_start)

    @monthly_order_growth = calculate_percentage_change(
      previous_month_orders.count,
      current_month_orders.count
    )

    @monthly_revenue_growth = calculate_percentage_change(
      previous_month_orders.sum("CAST(raw_data::json->>'total_price' AS DECIMAL)"),
      current_month_orders.sum("CAST(raw_data::json->>'total_price' AS DECIMAL)")
    )
  end
end
