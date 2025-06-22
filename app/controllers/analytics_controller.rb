class AnalyticsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_organization_member

  def index
    authorize :analytics, :index?

    @date_range = params[:date_range] || "30_days"
    @start_date, @end_date = calculate_date_range(@date_range)

    # Calculate comprehensive e-commerce metrics
    @ecommerce_insights = calculate_ecommerce_insights

    # Data source metrics
    @total_data_sources = current_organization.data_sources.count
    @active_data_sources = current_organization.data_sources.connected.count
    @syncing_data_sources = current_organization.data_sources.where(status: "syncing").count
    @error_data_sources = current_organization.data_sources.where(status: "error").count
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
    @queued_jobs = extraction_jobs.where(status: "queued").count
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
        completed = day_data["completed"] || 0
        total > 0 ? (completed.to_f / total * 100).round(1) : 0
      end

    # Top performing data sources (by record volume and success rate)
    @top_data_sources = current_organization.data_sources
      .joins(:extraction_jobs, :raw_data_records)
      .where(extraction_jobs: { created_at: @start_date..@end_date })
      .group("data_sources.id", "data_sources.name")
      .select("data_sources.name, COUNT(DISTINCT extraction_jobs.id) as job_count, COUNT(raw_data_records.id) as record_count")
      .order("record_count DESC")
      .limit(5)
      .map { |ds| [ ds.name, ds.record_count ] }

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
    @jobs_with_retries = extraction_jobs.where("retry_count > 0").count
    @avg_retry_count = extraction_jobs.where("retry_count > 0").average(:retry_count)&.round(1) || 0

    # System load indicators
    current_extraction_jobs = ExtractionJob.joins(:data_source)
      .where(data_sources: { organization_id: current_organization.id })
    @current_running_jobs = current_extraction_jobs.running.count
    @current_queued_jobs = current_extraction_jobs.where(status: "queued").count
    @sources_needing_sync = current_organization.data_sources.needs_sync.count
  end

  private

  def calculate_ecommerce_insights
    ecommerce_sources = current_organization.data_sources
      .where(source_type: %w[shopify woocommerce amazon_seller_central])

    return {} if ecommerce_sources.empty?

    # Get e-commerce data records
    ecommerce_records = RawDataRecord.joins(:data_source)
      .where(data_sources: { organization_id: current_organization.id })
      .where(data_sources: { source_type: %w[shopify woocommerce amazon_seller_central] })
      .where(created_at: @start_date..@end_date)

    # Separate by record type
    order_records = ecommerce_records.where("data @> ?", { record_type: "orders" }.to_json)
    customer_records = ecommerce_records.where("data @> ?", { record_type: "customers" }.to_json)
    product_records = ecommerce_records.where("data @> ?", { record_type: "products" }.to_json)
    inventory_records = ecommerce_records.where("data @> ?", { record_type: "inventory" }.to_json)

    {
      # Core metrics
      total_revenue: calculate_revenue_metrics(order_records),
      order_analytics: calculate_order_analytics(order_records),
      customer_analytics: calculate_customer_analytics(customer_records),
      product_analytics: calculate_product_analytics(product_records),
      inventory_analytics: calculate_inventory_analytics(inventory_records),

      # Platform breakdown
      platform_performance: calculate_platform_performance(ecommerce_sources, ecommerce_records),

      # Trends and forecasting
      revenue_trends: calculate_revenue_trends(order_records),
      growth_metrics: calculate_growth_metrics(order_records, customer_records),

      # Business intelligence
      top_performing_segments: calculate_top_segments(order_records),
      conversion_funnels: calculate_conversion_funnels(order_records, customer_records),

      # Risk and opportunities
      risk_indicators: calculate_risk_indicators(order_records, customer_records),
      growth_opportunities: identify_growth_opportunities(order_records, product_records)
    }
  end

  def calculate_revenue_metrics(order_records)
    return {} if order_records.empty?

    revenues = order_records.map do |record|
      normalized_data = record.data.dig("normalized_data")
      next 0 unless normalized_data
      (normalized_data["total_price"] || 0).to_f
    end.compact

    {
      total_revenue: revenues.sum.round(2),
      average_order_value: revenues.empty? ? 0 : (revenues.sum / revenues.count).round(2),
      median_order_value: revenues.empty? ? 0 : revenues.sort[revenues.length / 2].round(2),
      highest_order: revenues.max || 0,
      revenue_variance: revenues.empty? ? 0 : calculate_variance(revenues).round(2)
    }
  end

  def calculate_order_analytics(order_records)
    return {} if order_records.empty?

    status_counts = Hash.new(0)
    payment_methods = Hash.new(0)
    shipping_methods = Hash.new(0)
    hourly_distribution = Hash.new(0)

    order_records.each do |record|
      normalized_data = record.data.dig("normalized_data")
      next unless normalized_data

      # Order status analysis
      status = normalized_data["financial_status"] || "unknown"
      status_counts[status] += 1

      # Payment method analysis
      payment_method = normalized_data.dig("payment_details", "gateway") || "unknown"
      payment_methods[payment_method] += 1

      # Shipping analysis
      shipping_method = normalized_data.dig("shipping_address", "shipping_method") || "standard"
      shipping_methods[shipping_method] += 1

      # Time-based analysis
      created_at = normalized_data["created_at"]
      if created_at
        hour = Time.parse(created_at).hour rescue 12
        hourly_distribution[hour] += 1
      end
    end

    {
      total_orders: order_records.count,
      order_status_breakdown: status_counts,
      payment_method_distribution: payment_methods,
      shipping_method_distribution: shipping_methods,
      peak_ordering_hours: hourly_distribution.sort_by { |_, count| -count }.first(3).to_h,
      fulfillment_metrics: calculate_fulfillment_metrics(order_records)
    }
  end

  def calculate_customer_analytics(customer_records)
    return {} if customer_records.empty?

    segments = { new: 0, returning: 0, vip: 0, at_risk: 0, high_value: 0 }
    acquisition_channels = Hash.new(0)
    geographic_distribution = Hash.new(0)
    lifetime_values = []

    customer_records.each do |record|
      normalized_data = record.data.dig("normalized_data")
      next unless normalized_data

      # Customer segmentation
      orders_count = (normalized_data["orders_count"] || 0).to_i
      total_spent = (normalized_data["total_spent"] || 0).to_f
      last_order_at = normalized_data["last_order_at"]

      case
      when total_spent > 2000
        segments[:vip] += 1
      when total_spent > 500
        segments[:high_value] += 1
      when orders_count == 0
        segments[:new] += 1
      when last_order_at && Date.parse(last_order_at) < 90.days.ago
        segments[:at_risk] += 1
      else
        segments[:returning] += 1
      end

      # Geographic analysis
      country = normalized_data.dig("default_address", "country") || "Unknown"
      geographic_distribution[country] += 1

      # Lifetime value tracking
      lifetime_values << total_spent if total_spent > 0
    end

    {
      total_customers: customer_records.count,
      customer_segments: segments,
      geographic_distribution: geographic_distribution.sort_by { |_, count| -count }.first(10).to_h,
      average_lifetime_value: lifetime_values.empty? ? 0 : (lifetime_values.sum / lifetime_values.count).round(2),
      customer_acquisition_insights: calculate_acquisition_insights(customer_records)
    }
  end

  def calculate_product_analytics(product_records)
    return {} if product_records.empty?

    categories = Hash.new(0)
    price_ranges = { under_25: 0, '25_100': 0, '100_500': 0, over_500: 0 }
    variants_analysis = { single_variant: 0, multiple_variants: 0 }
    inventory_status = { in_stock: 0, low_stock: 0, out_of_stock: 0 }

    product_records.each do |record|
      normalized_data = record.data.dig("normalized_data")
      next unless normalized_data

      # Category analysis
      product_type = normalized_data["product_type"] || "Uncategorized"
      categories[product_type] += 1

      # Price range analysis
      price = (normalized_data["price"] || 0).to_f
      case price
      when 0...25
        price_ranges[:under_25] += 1
      when 25...100
        price_ranges[:'25_100'] += 1
      when 100...500
        price_ranges[:'100_500'] += 1
      else
        price_ranges[:over_500] += 1
      end

      # Variants analysis
      variants = normalized_data["variants"] || []
      if variants.is_a?(Array) && variants.length > 1
        variants_analysis[:multiple_variants] += 1
      else
        variants_analysis[:single_variant] += 1
      end

      # Inventory status (if available)
      inventory_quantity = (normalized_data["inventory_quantity"] || 0).to_i
      case inventory_quantity
      when 0
        inventory_status[:out_of_stock] += 1
      when 1..10
        inventory_status[:low_stock] += 1
      else
        inventory_status[:in_stock] += 1
      end
    end

    {
      total_products: product_records.count,
      category_distribution: categories.sort_by { |_, count| -count }.first(10).to_h,
      price_range_distribution: price_ranges,
      variants_distribution: variants_analysis,
      inventory_health: inventory_status
    }
  end

  def calculate_inventory_analytics(inventory_records)
    return {} if inventory_records.empty?

    total_value = 0
    low_stock_items = 0
    out_of_stock_items = 0
    locations = Hash.new(0)

    inventory_records.each do |record|
      normalized_data = record.data.dig("normalized_data")
      next unless normalized_data

      quantity = (normalized_data["available_quantity"] || 0).to_i
      cost = (normalized_data["cost_per_item"] || 0).to_f
      total_value += quantity * cost

      # Stock level analysis
      reorder_point = (normalized_data["reorder_point"] || 5).to_i
      if quantity == 0
        out_of_stock_items += 1
      elsif quantity <= reorder_point
        low_stock_items += 1
      end

      # Location analysis
      location = normalized_data["location_name"] || "Unknown"
      locations[location] += 1
    end

    {
      total_inventory_value: total_value.round(2),
      total_items: inventory_records.count,
      low_stock_alerts: low_stock_items,
      out_of_stock_alerts: out_of_stock_items,
      location_distribution: locations,
      reorder_recommendations: low_stock_items + out_of_stock_items
    }
  end

  def calculate_platform_performance(sources, records)
    platform_metrics = {}

    sources.each do |source|
      platform_records = records.where(data_source: source)

      platform_metrics[source.source_type] = {
        total_records: platform_records.count,
        last_sync: source.last_sync_at,
        sync_frequency: source.sync_frequency,
        health_score: calculate_platform_health_score(source),
        data_freshness: calculate_data_freshness(source)
      }
    end

    platform_metrics
  end

  def calculate_platform_health_score(source)
    score = 100

    # Deduct points for sync issues
    score -= 20 if source.status == "error"
    score -= 10 if source.last_sync_at && source.last_sync_at < 1.day.ago
    score -= 30 if source.last_sync_at.nil?

    # Consider recent job success rate
    recent_jobs = source.extraction_jobs.where("created_at >= ?", 7.days.ago)
    if recent_jobs.any?
      success_rate = recent_jobs.completed.count.to_f / recent_jobs.count * 100
      score = (score * (success_rate / 100.0)).round
    end

    [ score, 0 ].max
  end

  def calculate_data_freshness(source)
    return 0 unless source.last_sync_at

    hours_since_sync = (Time.current - source.last_sync_at) / 1.hour
    case hours_since_sync
    when 0..1
      "excellent"
    when 1..6
      "good"
    when 6..24
      "fair"
    else
      "stale"
    end
  end

  def calculate_variance(values)
    return 0 if values.empty?

    mean = values.sum.to_f / values.length
    variance = values.sum { |v| (v - mean) ** 2 } / values.length
    Math.sqrt(variance)
  end

  def calculate_fulfillment_metrics(order_records)
    fulfilled_count = 0
    pending_count = 0
    cancelled_count = 0

    order_records.each do |record|
      normalized_data = record.data.dig("normalized_data")
      next unless normalized_data

      fulfillment_status = normalized_data["fulfillment_status"] || "pending"
      case fulfillment_status
      when "fulfilled", "delivered"
        fulfilled_count += 1
      when "cancelled"
        cancelled_count += 1
      else
        pending_count += 1
      end
    end

    {
      fulfillment_rate: order_records.count > 0 ? (fulfilled_count.to_f / order_records.count * 100).round(2) : 0,
      pending_orders: pending_count,
      cancelled_orders: cancelled_count
    }
  end

  def calculate_acquisition_insights(customer_records)
    channels = Hash.new(0)

    customer_records.each do |record|
      normalized_data = record.data.dig("normalized_data")
      next unless normalized_data

      # Try to infer acquisition channel from available data
      referring_site = normalized_data["referring_site"]
      if referring_site
        if referring_site.include?("google")
          channels["google"] += 1
        elsif referring_site.include?("facebook")
          channels["facebook"] += 1
        elsif referring_site.include?("instagram")
          channels["instagram"] += 1
        else
          channels["referral"] += 1
        end
      else
        channels["direct"] += 1
      end
    end

    {
      acquisition_channels: channels,
      top_referral_source: channels.max_by { |_, count| count }&.first || "direct"
    }
  end

  def calculate_revenue_trends(order_records)
    # Implementation for revenue trend analysis
    daily_revenue = Hash.new(0)

    order_records.each do |record|
      normalized_data = record.data.dig("normalized_data")
      next unless normalized_data

      order_date = Date.parse(normalized_data["created_at"]) rescue Date.current
      revenue = (normalized_data["total_price"] || 0).to_f
      daily_revenue[order_date] += revenue
    end

    # Calculate week-over-week growth
    current_week = daily_revenue.keys.select { |date| date >= 1.week.ago }.sum { |date| daily_revenue[date] }
    previous_week = daily_revenue.keys.select { |date| date >= 2.weeks.ago && date < 1.week.ago }.sum { |date| daily_revenue[date] }

    growth_rate = previous_week > 0 ? ((current_week - previous_week) / previous_week * 100).round(2) : 0

    {
      daily_revenue: daily_revenue,
      week_over_week_growth: growth_rate,
      trend_direction: growth_rate > 0 ? "up" : "down"
    }
  end

  def calculate_growth_metrics(order_records, customer_records)
    current_period_orders = order_records.where(created_at: @start_date..@end_date)
    previous_period_start = @start_date - (@end_date - @start_date)
    previous_period_orders = order_records.where(created_at: previous_period_start..@start_date)

    current_period_customers = customer_records.where(created_at: @start_date..@end_date)
    previous_period_customers = customer_records.where(created_at: previous_period_start..@start_date)

    current_revenue = current_period_orders.sum { |order| 
      (order.data.dig("normalized_data", "total_price") || 0).to_f 
    }
    previous_revenue = previous_period_orders.sum { |order| 
      (order.data.dig("normalized_data", "total_price") || 0).to_f 
    }

    customer_growth = calculate_percentage_change(previous_period_customers.count, current_period_customers.count)
    revenue_growth = calculate_percentage_change(previous_revenue, current_revenue)
    order_growth = calculate_percentage_change(previous_period_orders.count, current_period_orders.count)

    {
      customer_growth_rate: customer_growth,
      revenue_growth_rate: revenue_growth,
      order_growth_rate: order_growth,
      order_frequency_trend: order_growth > 10 ? "increasing" : order_growth < -10 ? "decreasing" : "stable",
      growth_insights: generate_growth_insights(customer_growth, revenue_growth, order_growth)
    }
  end

  def calculate_top_segments(order_records)
    segment_performance = Hash.new { |h, k| h[k] = { orders: 0, revenue: 0, customers: Set.new } }

    order_records.each do |record|
      normalized_data = record.data.dig("normalized_data")
      next unless normalized_data

      # Segment by order value
      order_value = (normalized_data["total_price"] || 0).to_f
      customer_id = normalized_data["customer_id"]
      
      segment = case order_value
                when 0...50 then "Small Orders"
                when 50...200 then "Medium Orders" 
                when 200...500 then "Large Orders"
                else "Enterprise Orders"
                end

      segment_performance[segment][:orders] += 1
      segment_performance[segment][:revenue] += order_value
      segment_performance[segment][:customers].add(customer_id) if customer_id
    end

    # Convert to hash and calculate metrics
    segments = segment_performance.transform_values do |data|
      {
        order_count: data[:orders],
        total_revenue: data[:revenue].round(2),
        unique_customers: data[:customers].size,
        average_order_value: data[:orders] > 0 ? (data[:revenue] / data[:orders]).round(2) : 0
      }
    end

    segments.sort_by { |_, data| -data[:total_revenue] }.to_h
  end

  def calculate_conversion_funnels(order_records, customer_records)
    total_customers = customer_records.count
    customers_with_orders = order_records.map { |order| 
      order.data.dig("normalized_data", "customer_id") 
    }.compact.uniq.count

    repeat_customers = order_records
      .group_by { |order| order.data.dig("normalized_data", "customer_id") }
      .select { |_, orders| orders.count > 1 }
      .count

    high_value_customers = order_records
      .group_by { |order| order.data.dig("normalized_data", "customer_id") }
      .select { |_, orders| 
        total_spent = orders.sum { |order| (order.data.dig("normalized_data", "total_price") || 0).to_f }
        total_spent > 500
      }
      .count

    {
      total_customers: total_customers,
      purchasing_customers: customers_with_orders,
      repeat_customers: repeat_customers,
      high_value_customers: high_value_customers,
      conversion_rates: {
        visitor_to_customer: total_customers > 0 ? ((customers_with_orders.to_f / total_customers) * 100).round(2) : 0,
        customer_to_repeat: customers_with_orders > 0 ? ((repeat_customers.to_f / customers_with_orders) * 100).round(2) : 0,
        customer_to_high_value: customers_with_orders > 0 ? ((high_value_customers.to_f / customers_with_orders) * 100).round(2) : 0
      }
    }
  end

  def calculate_risk_indicators(order_records, customer_records)
    # Analyze declining trends and potential risks
    recent_orders = order_records.where("created_at >= ?", 30.days.ago)
    very_recent_orders = order_records.where("created_at >= ?", 7.days.ago)

    # Revenue decline risk
    recent_revenue = recent_orders.sum { |order| (order.data.dig("normalized_data", "total_price") || 0).to_f }
    very_recent_revenue = very_recent_orders.sum { |order| (order.data.dig("normalized_data", "total_price") || 0).to_f }
    weekly_revenue_trend = very_recent_revenue * 4 # Extrapolate to monthly

    # Customer churn risk
    active_customers = recent_orders.map { |order| order.data.dig("normalized_data", "customer_id") }.compact.uniq
    customers_last_week = very_recent_orders.map { |order| order.data.dig("normalized_data", "customer_id") }.compact.uniq
    
    churn_risk = active_customers.count > 0 ? 
      ((active_customers.count - customers_last_week.count).to_f / active_customers.count * 100).round(2) : 0

    # Failed order analysis
    failed_orders = order_records.select do |order|
      status = order.data.dig("normalized_data", "financial_status")
      status == "failed" || status == "cancelled"
    end

    {
      revenue_decline_risk: recent_revenue > weekly_revenue_trend ? "high" : "low",
      customer_churn_risk: churn_risk > 20 ? "high" : churn_risk > 10 ? "medium" : "low",
      failed_order_rate: order_records.count > 0 ? ((failed_orders.count.to_f / order_records.count) * 100).round(2) : 0,
      risk_score: calculate_overall_risk_score(recent_revenue, weekly_revenue_trend, churn_risk, failed_orders.count),
      recommendations: generate_risk_recommendations(recent_revenue, weekly_revenue_trend, churn_risk, failed_orders.count)
    }
  end

  def identify_growth_opportunities(order_records, product_records)
    # Product performance analysis
    product_performance = Hash.new { |h, k| h[k] = { orders: 0, revenue: 0 } }
    
    order_records.each do |order|
      line_items = order.data.dig("normalized_data", "line_items") || []
      line_items.each do |item|
        product_id = item["product_id"]
        quantity = (item["quantity"] || 0).to_i
        price = (item["price"] || 0).to_f
        
        product_performance[product_id][:orders] += quantity
        product_performance[product_id][:revenue] += (quantity * price)
      end
    end

    # Identify top and underperforming products
    top_products = product_performance.sort_by { |_, data| -data[:revenue] }.first(5)
    underperforming_products = product_performance.select { |_, data| data[:orders] < 3 && data[:revenue] < 100 }

    # Market expansion opportunities
    geographic_analysis = analyze_geographic_opportunities(order_records)
    seasonal_patterns = analyze_seasonal_patterns(order_records)

    {
      top_performing_products: top_products.to_h,
      underperforming_products: underperforming_products.keys.count,
      geographic_opportunities: geographic_analysis,
      seasonal_insights: seasonal_patterns,
      cross_sell_opportunities: identify_cross_sell_opportunities(order_records),
      market_expansion_score: calculate_market_expansion_score(geographic_analysis, product_performance)
    }
  end

  def calculate_percentage_change(old_value, new_value)
    return 0 if old_value == 0
    ((new_value - old_value).to_f / old_value * 100).round(2)
  end

  def generate_growth_insights(customer_growth, revenue_growth, order_growth)
    insights = []
    
    if revenue_growth > 20
      insights << "Strong revenue growth indicates successful market expansion"
    elsif revenue_growth < -10
      insights << "Revenue decline requires immediate attention"
    end

    if customer_growth > 15
      insights << "Excellent customer acquisition rate"
    elsif customer_growth < 0
      insights << "Customer acquisition challenges detected"
    end

    if order_growth > revenue_growth + 10
      insights << "Order volume growth outpacing revenue suggests lower AOV"
    end

    insights.empty? ? ["Performance metrics within normal ranges"] : insights
  end

  def calculate_overall_risk_score(recent_revenue, weekly_revenue_trend, churn_risk, failed_orders)
    score = 0
    score += 30 if recent_revenue > weekly_revenue_trend
    score += (churn_risk * 2).to_i
    score += (failed_orders * 5)
    
    case score
    when 0..20 then "low"
    when 21..50 then "medium"
    else "high"
    end
  end

  def generate_risk_recommendations(recent_revenue, weekly_revenue_trend, churn_risk, failed_orders)
    recommendations = []
    
    if recent_revenue > weekly_revenue_trend
      recommendations << "Implement customer retention campaigns"
    end
    
    if churn_risk > 15
      recommendations << "Review customer satisfaction and support processes"
    end
    
    if failed_orders > 5
      recommendations << "Investigate payment processing and checkout flow"
    end

    recommendations.empty? ? ["Continue monitoring key metrics"] : recommendations
  end

  def analyze_geographic_opportunities(order_records)
    countries = Hash.new(0)
    
    order_records.each do |order|
      country = order.data.dig("normalized_data", "shipping_address", "country") || "Unknown"
      countries[country] += 1
    end

    total_orders = countries.values.sum
    
    {
      top_markets: countries.sort_by { |_, count| -count }.first(5).to_h,
      market_concentration: countries.values.max.to_f / total_orders * 100,
      untapped_markets: identify_untapped_markets(countries)
    }
  end

  def analyze_seasonal_patterns(order_records)
    monthly_orders = Hash.new(0)
    
    order_records.each do |order|
      created_at = order.data.dig("normalized_data", "created_at")
      next unless created_at
      
      month = Date.parse(created_at).month rescue nil
      monthly_orders[month] += 1 if month
    end

    peak_months = monthly_orders.sort_by { |_, count| -count }.first(3).map(&:first)
    
    {
      monthly_distribution: monthly_orders,
      peak_months: peak_months,
      seasonality_score: calculate_seasonality_score(monthly_orders)
    }
  end

  def identify_cross_sell_opportunities(order_records)
    product_combinations = Hash.new(0)
    
    order_records.each do |order|
      line_items = order.data.dig("normalized_data", "line_items") || []
      products = line_items.map { |item| item["product_id"] }.compact
      
      if products.length > 1
        products.combination(2).each do |combo|
          key = combo.sort.join("-")
          product_combinations[key] += 1
        end
      end
    end

    product_combinations.sort_by { |_, count| -count }.first(5).to_h
  end

  def calculate_market_expansion_score(geographic_analysis, product_performance)
    market_diversity = geographic_analysis[:top_markets].count
    product_variety = product_performance.count
    
    base_score = (market_diversity * 10) + (product_variety * 2)
    concentration_penalty = geographic_analysis[:market_concentration] > 70 ? 20 : 0
    
    [[base_score - concentration_penalty, 0].max, 100].min
  end

  def identify_untapped_markets(current_markets)
    major_markets = ["United States", "Canada", "United Kingdom", "Germany", "France", "Australia", "Japan"]
    major_markets - current_markets.keys
  end

  def calculate_seasonality_score(monthly_orders)
    return 0 if monthly_orders.empty?
    
    values = monthly_orders.values
    avg = values.sum.to_f / values.length
    variance = values.sum { |v| (v - avg) ** 2 } / values.length
    
    (Math.sqrt(variance) / avg * 100).round(2)
  end

  def calculate_date_range(range)
    case range
    when "7_days"
      [ 7.days.ago.beginning_of_day, Time.current.end_of_day ]
    when "30_days"
      [ 30.days.ago.beginning_of_day, Time.current.end_of_day ]
    when "90_days"
      [ 90.days.ago.beginning_of_day, Time.current.end_of_day ]
    when "1_year"
      [ 1.year.ago.beginning_of_day, Time.current.end_of_day ]
    else
      [ 30.days.ago.beginning_of_day, Time.current.end_of_day ]
    end
  end
end
