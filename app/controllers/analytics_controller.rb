class AnalyticsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_organization_member

  def index
    authorize :analytics, :index?
    
    @date_range = params[:date_range] || '30_days'
    @start_date, @end_date = calculate_date_range(@date_range)
    
    # Calculate comprehensive e-commerce metrics
    @ecommerce_insights = calculate_ecommerce_insights
    
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
    order_records = ecommerce_records.where("data @> ?", { record_type: 'orders' }.to_json)
    customer_records = ecommerce_records.where("data @> ?", { record_type: 'customers' }.to_json)
    product_records = ecommerce_records.where("data @> ?", { record_type: 'products' }.to_json)
    inventory_records = ecommerce_records.where("data @> ?", { record_type: 'inventory' }.to_json)

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
      normalized_data = record.data.dig('normalized_data')
      next 0 unless normalized_data
      (normalized_data['total_price'] || 0).to_f
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
      normalized_data = record.data.dig('normalized_data')
      next unless normalized_data

      # Order status analysis
      status = normalized_data['financial_status'] || 'unknown'
      status_counts[status] += 1

      # Payment method analysis  
      payment_method = normalized_data.dig('payment_details', 'gateway') || 'unknown'
      payment_methods[payment_method] += 1

      # Shipping analysis
      shipping_method = normalized_data.dig('shipping_address', 'shipping_method') || 'standard'
      shipping_methods[shipping_method] += 1

      # Time-based analysis
      created_at = normalized_data['created_at']
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
      normalized_data = record.data.dig('normalized_data')
      next unless normalized_data

      # Customer segmentation
      orders_count = (normalized_data['orders_count'] || 0).to_i
      total_spent = (normalized_data['total_spent'] || 0).to_f
      last_order_at = normalized_data['last_order_at']

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
      country = normalized_data.dig('default_address', 'country') || 'Unknown'
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
      normalized_data = record.data.dig('normalized_data')
      next unless normalized_data

      # Category analysis
      product_type = normalized_data['product_type'] || 'Uncategorized'
      categories[product_type] += 1

      # Price range analysis
      price = (normalized_data['price'] || 0).to_f
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
      variants = normalized_data['variants'] || []
      if variants.is_a?(Array) && variants.length > 1
        variants_analysis[:multiple_variants] += 1
      else
        variants_analysis[:single_variant] += 1
      end

      # Inventory status (if available)
      inventory_quantity = (normalized_data['inventory_quantity'] || 0).to_i
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
      normalized_data = record.data.dig('normalized_data')
      next unless normalized_data

      quantity = (normalized_data['available_quantity'] || 0).to_i
      cost = (normalized_data['cost_per_item'] || 0).to_f
      total_value += quantity * cost

      # Stock level analysis
      reorder_point = (normalized_data['reorder_point'] || 5).to_i
      if quantity == 0
        out_of_stock_items += 1
      elsif quantity <= reorder_point
        low_stock_items += 1
      end

      # Location analysis
      location = normalized_data['location_name'] || 'Unknown'
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
    score -= 20 if source.status == 'error'
    score -= 10 if source.last_sync_at && source.last_sync_at < 1.day.ago
    score -= 30 if source.last_sync_at.nil?
    
    # Consider recent job success rate
    recent_jobs = source.extraction_jobs.where('created_at >= ?', 7.days.ago)
    if recent_jobs.any?
      success_rate = recent_jobs.completed.count.to_f / recent_jobs.count * 100
      score = (score * (success_rate / 100.0)).round
    end
    
    [score, 0].max
  end

  def calculate_data_freshness(source)
    return 0 unless source.last_sync_at
    
    hours_since_sync = (Time.current - source.last_sync_at) / 1.hour
    case hours_since_sync
    when 0..1
      'excellent'
    when 1..6  
      'good'
    when 6..24
      'fair'
    else
      'stale'
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
      normalized_data = record.data.dig('normalized_data')
      next unless normalized_data

      fulfillment_status = normalized_data['fulfillment_status'] || 'pending'
      case fulfillment_status
      when 'fulfilled', 'delivered'
        fulfilled_count += 1
      when 'cancelled'
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
      normalized_data = record.data.dig('normalized_data')
      next unless normalized_data

      # Try to infer acquisition channel from available data
      referring_site = normalized_data['referring_site']
      if referring_site
        if referring_site.include?('google')
          channels['google'] += 1
        elsif referring_site.include?('facebook')
          channels['facebook'] += 1
        elsif referring_site.include?('instagram')
          channels['instagram'] += 1
        else
          channels['referral'] += 1
        end
      else
        channels['direct'] += 1
      end
    end

    {
      acquisition_channels: channels,
      top_referral_source: channels.max_by { |_, count| count }&.first || 'direct'
    }
  end

  def calculate_revenue_trends(order_records)
    # Implementation for revenue trend analysis
    daily_revenue = Hash.new(0)
    
    order_records.each do |record|
      normalized_data = record.data.dig('normalized_data')
      next unless normalized_data
      
      order_date = Date.parse(normalized_data['created_at']) rescue Date.current
      revenue = (normalized_data['total_price'] || 0).to_f
      daily_revenue[order_date] += revenue
    end

    # Calculate week-over-week growth
    current_week = daily_revenue.keys.select { |date| date >= 1.week.ago }.sum { |date| daily_revenue[date] }
    previous_week = daily_revenue.keys.select { |date| date >= 2.weeks.ago && date < 1.week.ago }.sum { |date| daily_revenue[date] }
    
    growth_rate = previous_week > 0 ? ((current_week - previous_week) / previous_week * 100).round(2) : 0

    {
      daily_revenue: daily_revenue,
      week_over_week_growth: growth_rate,
      trend_direction: growth_rate > 0 ? 'up' : 'down'
    }
  end

  def calculate_growth_metrics(order_records, customer_records)
    # Placeholder for growth metrics calculation
    {
      customer_growth_rate: 0,
      revenue_growth_rate: 0,
      order_frequency_trend: 'stable'
    }
  end

  def calculate_top_segments(order_records)
    # Placeholder for top performing segments
    {}
  end

  def calculate_conversion_funnels(order_records, customer_records)
    # Placeholder for conversion funnel analysis
    {}
  end

  def calculate_risk_indicators(order_records, customer_records)
    # Placeholder for risk analysis
    {}
  end

  def identify_growth_opportunities(order_records, product_records)
    # Placeholder for growth opportunity identification
    {}
  end

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