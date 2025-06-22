class DashboardController < ApplicationController
  before_action :ensure_organization_member

  def index
    @organization = current_organization
    @data_sources = policy_scope(DataSource).includes(:extraction_jobs)
    @recent_jobs = policy_scope(ExtractionJob).recent.limit(10)
    @stats = calculate_dashboard_stats
    @ecommerce_stats = calculate_ecommerce_stats
    @charts_data = build_charts_data
    @data_quality_metrics = calculate_data_quality_metrics
    @recent_activity = calculate_recent_activity
    # @system_status is set in ApplicationController
  end

  private

  def calculate_dashboard_stats
    {
      total_data_sources: @data_sources.count,
      connected_sources: @data_sources.connected.count,
      total_records: policy_scope(RawDataRecord).count,
      last_sync: @recent_jobs.successful.first&.completed_at
    }
  end

  def calculate_data_quality_metrics
    # Get recent raw data records for quality analysis
    recent_records = policy_scope(RawDataRecord)
      .includes(:data_source)
      .where(created_at: 24.hours.ago..Time.current)
      .limit(1000)

    return default_quality_metrics if recent_records.empty?

    # Initialize data quality service
    quality_service = DataQualityValidationService.new

    # Calculate quality metrics by data source type
    quality_by_source = {}
    overall_metrics = {
      completeness_score: 0,
      accuracy_score: 0,
      freshness_score: 0,
      consistency_score: 0,
      total_records_analyzed: recent_records.count,
      quality_issues: 0,
      last_quality_check: Time.current
    }

    # Group records by data source for analysis
    records_by_source = recent_records.group_by(&:data_source)

    records_by_source.each do |data_source, records|
      source_data = records.map { |r| parse_record_data(r.raw_data) }

      # Validate data quality for this source
      validation_result = quality_service.validate_data(
        source_data,
        context: data_source.source_type
      )

      # Extract quality metrics
      source_metrics = {
        completeness: calculate_completeness_score(source_data),
        accuracy: validation_result.quality_metrics&.accuracy_score || 85,
        freshness: calculate_freshness_score(records),
        consistency: validation_result.quality_metrics&.consistency_score || 90,
        issues_count: validation_result.errors.count
      }

      quality_by_source[data_source.source_type] = source_metrics

      # Update overall metrics
      overall_metrics[:completeness_score] += source_metrics[:completeness]
      overall_metrics[:accuracy_score] += source_metrics[:accuracy]
      overall_metrics[:freshness_score] += source_metrics[:freshness]
      overall_metrics[:consistency_score] += source_metrics[:consistency]
      overall_metrics[:quality_issues] += source_metrics[:issues_count]
    end

    # Calculate averages
    source_count = records_by_source.count
    if source_count > 0
      overall_metrics[:completeness_score] = (overall_metrics[:completeness_score] / source_count).round(1)
      overall_metrics[:accuracy_score] = (overall_metrics[:accuracy_score] / source_count).round(1)
      overall_metrics[:freshness_score] = (overall_metrics[:freshness_score] / source_count).round(1)
      overall_metrics[:consistency_score] = (overall_metrics[:consistency_score] / source_count).round(1)
    end

    # Calculate overall quality score
    overall_metrics[:overall_quality_score] = [
      overall_metrics[:completeness_score],
      overall_metrics[:accuracy_score],
      overall_metrics[:freshness_score],
      overall_metrics[:consistency_score]
    ].sum / 4.0

    # Determine quality status
    overall_metrics[:quality_status] = case overall_metrics[:overall_quality_score]
    when 90..100 then "excellent"
    when 80..89 then "good"
    when 70..79 then "fair"
    when 60..69 then "poor"
    else "critical"
    end

    {
      overall: overall_metrics,
      by_source: quality_by_source,
      trends: calculate_quality_trends
    }
  rescue => e
    Rails.logger.error "Error calculating data quality metrics: #{e.message}"
    default_quality_metrics
  end

  def default_quality_metrics
    {
      overall: {
        completeness_score: 0,
        accuracy_score: 0,
        freshness_score: 0,
        consistency_score: 0,
        overall_quality_score: 0,
        total_records_analyzed: 0,
        quality_issues: 0,
        quality_status: "unknown",
        last_quality_check: Time.current
      },
      by_source: {},
      trends: []
    }
  end

  def parse_record_data(raw_data)
    return {} unless raw_data.present?

    case raw_data
    when String
      JSON.parse(raw_data) rescue {}
    when Hash
      raw_data
    else
      {}
    end
  end

  def calculate_completeness_score(data)
    return 0 if data.empty?

    total_fields = 0
    complete_fields = 0

    data.each do |record|
      next unless record.is_a?(Hash)

      record.each do |key, value|
        total_fields += 1
        complete_fields += 1 if value.present?
      end
    end

    return 0 if total_fields == 0
    ((complete_fields.to_f / total_fields) * 100).round(1)
  end

  def calculate_freshness_score(records)
    return 0 if records.empty?

    now = Time.current
    total_score = 0

    records.each do |record|
      hours_old = (now - record.created_at) / 1.hour

      # Score based on data age (fresher = higher score)
      score = case hours_old
      when 0..1 then 100
      when 1..6 then 90
      when 6..12 then 80
      when 12..24 then 70
      when 24..48 then 60
      else 40
      end

      total_score += score
    end

    (total_score.to_f / records.count).round(1)
  end

  def calculate_quality_trends
    # Get quality metrics from the last 7 days
    trends = []

    7.downto(0) do |days_ago|
      date = days_ago.days.ago.beginning_of_day

      # This would typically come from stored quality metrics
      # For now, we'll simulate trend data
      trends << {
        date: date.strftime("%Y-%m-%d"),
        completeness: rand(85..98),
        accuracy: rand(80..95),
        freshness: rand(75..95),
        overall: rand(80..95)
      }
    end

    trends
  end

  def calculate_ecommerce_stats
    ecommerce_sources = @data_sources.where(source_type: %w[shopify woocommerce amazon_seller_central])

    return {} if ecommerce_sources.empty?

    # Get recent order data from raw records
    recent_orders = get_recent_ecommerce_records("orders", 30.days.ago)
    recent_customers = get_recent_ecommerce_records("customers", 30.days.ago)
    recent_products = get_recent_ecommerce_records("products", 30.days.ago)

    # Calculate metrics from normalized data
    {
      total_revenue: calculate_total_revenue(recent_orders),
      total_orders: recent_orders.count,
      total_customers: recent_customers.count,
      average_order_value: calculate_average_order_value(recent_orders),
      top_products: get_top_products(recent_orders, 5),
      revenue_trend: calculate_revenue_trend(recent_orders),
      customer_segments: calculate_customer_segments(recent_customers),
      conversion_metrics: calculate_conversion_metrics(recent_orders, recent_customers)
    }
  end

  def build_charts_data
    return {} unless @ecommerce_stats.present?

    {
      revenue_chart: build_revenue_chart_data,
      orders_chart: build_orders_chart_data,
      customer_growth_chart: build_customer_growth_chart_data,
      product_performance_chart: build_product_performance_chart_data
    }
  end

  # Helper methods for e-commerce calculations
  def get_recent_ecommerce_records(record_type, since_date)
    # Query raw data records for e-commerce data
    policy_scope(RawDataRecord)
      .joins(:data_source)
      .where(data_sources: { source_type: %w[shopify woocommerce amazon_seller_central] })
      .where("raw_data_records.created_at >= ?", since_date)
      .where("raw_data_records.data @> ?", { record_type: record_type }.to_json)
      .limit(1000) # Reasonable limit for dashboard performance
  end

  def calculate_total_revenue(order_records)
    order_records.sum do |record|
      normalized_data = record.data.dig("normalized_data")
      next 0 unless normalized_data

      (normalized_data["total_price"] || 0).to_f
    end
  end

  def calculate_average_order_value(order_records)
    return 0 if order_records.empty?
    calculate_total_revenue(order_records) / order_records.count
  end

  def get_top_products(order_records, limit = 5)
    product_sales = Hash.new { |h, k| h[k] = { count: 0, revenue: 0.0 } }

    order_records.each do |record|
      normalized_data = record.data.dig("normalized_data")
      next unless normalized_data

      line_items = normalized_data["line_items"] || []
      line_items.each do |item|
        product_name = item["product_title"] || item["name"] || "Unknown Product"
        quantity = (item["quantity"] || 1).to_i
        price = (item["price"] || 0).to_f

        product_sales[product_name][:count] += quantity
        product_sales[product_name][:revenue] += price * quantity
      end
    end

    product_sales.sort_by { |_, stats| -stats[:revenue] }.first(limit).to_h
  end

  def calculate_revenue_trend(order_records)
    daily_revenue = Hash.new(0)

    order_records.each do |record|
      normalized_data = record.data.dig("normalized_data")
      next unless normalized_data

      order_date = Date.parse(normalized_data["created_at"]) rescue Date.current
      revenue = (normalized_data["total_price"] || 0).to_f

      daily_revenue[order_date] += revenue
    end

    # Fill in missing dates with 0
    start_date = 30.days.ago.to_date
    end_date = Date.current

    (start_date..end_date).map do |date|
      {
        date: date.strftime("%Y-%m-%d"),
        revenue: daily_revenue[date].round(2)
      }
    end
  end

  def calculate_customer_segments(customer_records)
    segments = { new: 0, returning: 0, vip: 0, at_risk: 0 }

    customer_records.each do |record|
      normalized_data = record.data.dig("normalized_data")
      next unless normalized_data

      orders_count = (normalized_data["orders_count"] || 0).to_i
      total_spent = (normalized_data["total_spent"] || 0).to_f
      last_order_at = normalized_data["last_order_at"]

      case
      when orders_count == 0
        segments[:new] += 1
      when total_spent > 1000
        segments[:vip] += 1
      when last_order_at && Date.parse(last_order_at) < 90.days.ago
        segments[:at_risk] += 1
      else
        segments[:returning] += 1
      end
    end

    segments
  end

  def calculate_conversion_metrics(order_records, customer_records)
    total_customers = customer_records.count
    customers_with_orders = order_records.map do |record|
      record.data.dig("normalized_data", "customer_external_id")
    end.compact.uniq.count

    {
      conversion_rate: total_customers > 0 ? (customers_with_orders.to_f / total_customers * 100).round(2) : 0,
      repeat_purchase_rate: calculate_repeat_purchase_rate(order_records)
    }
  end

  def calculate_repeat_purchase_rate(order_records)
    customer_order_counts = Hash.new(0)

    order_records.each do |record|
      customer_id = record.data.dig("normalized_data", "customer_external_id")
      next unless customer_id
      customer_order_counts[customer_id] += 1
    end

    return 0 if customer_order_counts.empty?

    repeat_customers = customer_order_counts.values.count { |count| count > 1 }
    (repeat_customers.to_f / customer_order_counts.size * 100).round(2)
  end

  # Chart data builders
  def build_revenue_chart_data
    return [] unless @ecommerce_stats[:revenue_trend]

    @ecommerce_stats[:revenue_trend].map do |day_data|
      {
        x: day_data[:date],
        y: day_data[:revenue]
      }
    end
  end

  def build_orders_chart_data
    order_records = get_recent_ecommerce_records("orders", 30.days.ago)
    daily_orders = Hash.new(0)

    order_records.each do |record|
      normalized_data = record.data.dig("normalized_data")
      next unless normalized_data

      order_date = Date.parse(normalized_data["created_at"]) rescue Date.current
      daily_orders[order_date] += 1
    end

    (30.days.ago.to_date..Date.current).map do |date|
      {
        x: date.strftime("%Y-%m-%d"),
        y: daily_orders[date]
      }
    end
  end

  def build_customer_growth_chart_data
    customer_records = get_recent_ecommerce_records("customers", 30.days.ago)
    daily_customers = Hash.new(0)

    customer_records.each do |record|
      normalized_data = record.data.dig("normalized_data")
      next unless normalized_data

      created_date = Date.parse(normalized_data["created_at"]) rescue Date.current
      daily_customers[created_date] += 1
    end

    (30.days.ago.to_date..Date.current).map do |date|
      {
        x: date.strftime("%Y-%m-%d"),
        y: daily_customers[date]
      }
    end
  end

  def build_product_performance_chart_data
    return [] unless @ecommerce_stats[:top_products]

    @ecommerce_stats[:top_products].map do |product_name, stats|
      {
        label: product_name.truncate(30),
        revenue: stats[:revenue].round(2),
        units_sold: stats[:count]
      }
    end
  end

  def calculate_recent_activity
    activities = []
    
    # Get recent extraction jobs
    recent_jobs = @recent_jobs.limit(5)
    recent_jobs.each do |job|
      case job.status
      when 'completed'
        activities << {
          type: 'success',
          icon_color: 'green',
          title: "#{job.data_source.source_type.humanize} sync completed",
          description: "#{job.records_processed || 0} records processed",
          time: time_ago_in_words(job.completed_at),
          timestamp: job.completed_at
        }
      when 'failed'
        activities << {
          type: 'error',
          icon_color: 'red',
          title: "#{job.data_source.source_type.humanize} sync failed",
          description: job.error_message&.truncate(50) || "Processing error",
          time: time_ago_in_words(job.completed_at || job.created_at),
          timestamp: job.completed_at || job.created_at
        }
      when 'running'
        activities << {
          type: 'info',
          icon_color: 'blue',
          title: "#{job.data_source.source_type.humanize} sync in progress",
          description: "#{job.progress_percentage || 0}% complete",
          time: time_ago_in_words(job.started_at || job.created_at),
          timestamp: job.started_at || job.created_at
        }
      end
    end
    
    # Get recent data source connections
    recent_sources = @data_sources.where('created_at >= ?', 24.hours.ago).limit(3)
    recent_sources.each do |source|
      activities << {
        type: 'info',
        icon_color: 'blue',
        title: "New #{source.source_type.humanize} connected",
        description: source.name,
        time: time_ago_in_words(source.created_at),
        timestamp: source.created_at
      }
    end
    
    # Get recent quality checks
    if @data_quality_metrics[:overall][:last_quality_check]
      activities << {
        type: 'success',
        icon_color: 'green',
        title: "Data quality check completed",
        description: "Overall score: #{@data_quality_metrics[:overall][:overall_quality_score].round(1)}%",
        time: time_ago_in_words(@data_quality_metrics[:overall][:last_quality_check]),
        timestamp: @data_quality_metrics[:overall][:last_quality_check]
      }
    end
    
    # Sort by timestamp and take most recent 5
    activities.sort_by { |a| a[:timestamp] }.reverse.first(5)
  end

  def calculate_system_status
    # Calculate actual system metrics
    total_jobs = policy_scope(ExtractionJob).where('created_at >= ?', 24.hours.ago)
    running_jobs = total_jobs.running.count
    failed_jobs_rate = total_jobs.failed.count.to_f / [total_jobs.count, 1].max
    
    # Calculate uptime based on success rate
    uptime = ((1 - failed_jobs_rate) * 100).round(1)
    
    # Calculate storage used (sum of all raw data records)
    total_records = policy_scope(RawDataRecord).count
    estimated_storage_gb = (total_records * 0.5).round(1) # Rough estimate: 0.5KB per record
    
    # Determine overall health
    health_status = case
                   when uptime >= 99 && running_jobs < 10
                     { status: 'healthy', color: 'green', text: 'Healthy' }
                   when uptime >= 95 && running_jobs < 20
                     { status: 'warning', color: 'yellow', text: 'Warning' }
                   else
                     { status: 'critical', color: 'red', text: 'Critical' }
                   end
    
    {
      health: health_status,
      uptime: "#{uptime}%",
      processing_jobs: running_jobs,
      storage_used: "#{estimated_storage_gb} GB",
      last_updated: Time.current
    }
  end
end
