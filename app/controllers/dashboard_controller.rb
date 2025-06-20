class DashboardController < ApplicationController
  before_action :ensure_organization_member

  def index
    @organization = current_organization
    @data_sources = policy_scope(DataSource).includes(:extraction_jobs)
    @recent_jobs = policy_scope(ExtractionJob).recent.limit(10)
    @stats = calculate_dashboard_stats
    @ecommerce_stats = calculate_ecommerce_stats
    @charts_data = build_charts_data
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

  def calculate_ecommerce_stats
    ecommerce_sources = @data_sources.where(source_type: %w[shopify woocommerce amazon_seller_central])
    
    return {} if ecommerce_sources.empty?

    # Get recent order data from raw records
    recent_orders = get_recent_ecommerce_records('orders', 30.days.ago)
    recent_customers = get_recent_ecommerce_records('customers', 30.days.ago)
    recent_products = get_recent_ecommerce_records('products', 30.days.ago)
    
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
      .where('raw_data_records.created_at >= ?', since_date)
      .where('raw_data_records.data @> ?', { record_type: record_type }.to_json)
      .limit(1000) # Reasonable limit for dashboard performance
  end

  def calculate_total_revenue(order_records)
    order_records.sum do |record|
      normalized_data = record.data.dig('normalized_data')
      next 0 unless normalized_data
      
      (normalized_data['total_price'] || 0).to_f
    end
  end

  def calculate_average_order_value(order_records)
    return 0 if order_records.empty?
    calculate_total_revenue(order_records) / order_records.count
  end

  def get_top_products(order_records, limit = 5)
    product_sales = Hash.new { |h, k| h[k] = { count: 0, revenue: 0.0 } }
    
    order_records.each do |record|
      normalized_data = record.data.dig('normalized_data')
      next unless normalized_data
      
      line_items = normalized_data['line_items'] || []
      line_items.each do |item|
        product_name = item['product_title'] || item['name'] || 'Unknown Product'
        quantity = (item['quantity'] || 1).to_i
        price = (item['price'] || 0).to_f
        
        product_sales[product_name][:count] += quantity
        product_sales[product_name][:revenue] += price * quantity
      end
    end
    
    product_sales.sort_by { |_, stats| -stats[:revenue] }.first(limit).to_h
  end

  def calculate_revenue_trend(order_records)
    daily_revenue = Hash.new(0)
    
    order_records.each do |record|
      normalized_data = record.data.dig('normalized_data')
      next unless normalized_data
      
      order_date = Date.parse(normalized_data['created_at']) rescue Date.current
      revenue = (normalized_data['total_price'] || 0).to_f
      
      daily_revenue[order_date] += revenue
    end
    
    # Fill in missing dates with 0
    start_date = 30.days.ago.to_date
    end_date = Date.current
    
    (start_date..end_date).map do |date|
      {
        date: date.strftime('%Y-%m-%d'),
        revenue: daily_revenue[date].round(2)
      }
    end
  end

  def calculate_customer_segments(customer_records)
    segments = { new: 0, returning: 0, vip: 0, at_risk: 0 }
    
    customer_records.each do |record|
      normalized_data = record.data.dig('normalized_data')
      next unless normalized_data
      
      orders_count = (normalized_data['orders_count'] || 0).to_i
      total_spent = (normalized_data['total_spent'] || 0).to_f
      last_order_at = normalized_data['last_order_at']
      
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
      record.data.dig('normalized_data', 'customer_external_id')
    end.compact.uniq.count
    
    {
      conversion_rate: total_customers > 0 ? (customers_with_orders.to_f / total_customers * 100).round(2) : 0,
      repeat_purchase_rate: calculate_repeat_purchase_rate(order_records)
    }
  end

  def calculate_repeat_purchase_rate(order_records)
    customer_order_counts = Hash.new(0)
    
    order_records.each do |record|
      customer_id = record.data.dig('normalized_data', 'customer_external_id')
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
    order_records = get_recent_ecommerce_records('orders', 30.days.ago)
    daily_orders = Hash.new(0)
    
    order_records.each do |record|
      normalized_data = record.data.dig('normalized_data')
      next unless normalized_data
      
      order_date = Date.parse(normalized_data['created_at']) rescue Date.current
      daily_orders[order_date] += 1
    end
    
    (30.days.ago.to_date..Date.current).map do |date|
      {
        x: date.strftime('%Y-%m-%d'),
        y: daily_orders[date]
      }
    end
  end

  def build_customer_growth_chart_data
    customer_records = get_recent_ecommerce_records('customers', 30.days.ago)
    daily_customers = Hash.new(0)
    
    customer_records.each do |record|
      normalized_data = record.data.dig('normalized_data')
      next unless normalized_data
      
      created_date = Date.parse(normalized_data['created_at']) rescue Date.current
      daily_customers[created_date] += 1
    end
    
    (30.days.ago.to_date..Date.current).map do |date|
      {
        x: date.strftime('%Y-%m-%d'),
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
end