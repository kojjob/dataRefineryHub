class Analytics::RevenueController < Analytics::BaseController
  before_action :set_date_range

  def index
    authorize :analytics, :index?

    @revenue_metrics = calculate_revenue_metrics
    @revenue_trends = calculate_revenue_trends
    @fulfillment_metrics = calculate_fulfillment_metrics
  end

  def trends
    authorize :analytics, :index?

    @revenue_trends = calculate_revenue_trends
    render json: @revenue_trends
  end

  def breakdown
    authorize :analytics, :index?

    @revenue_breakdown = calculate_revenue_breakdown
    render json: @revenue_breakdown
  end

  private

  def set_date_range
    @date_range = params[:date_range] || "30_days"
    @start_date, @end_date = calculate_date_range(@date_range)
  end

  def calculate_revenue_metrics
    order_records = order_records_scope

    # Calculate totals by processing in Ruby
    total_revenue = 0
    tax_collected = 0
    shipping_revenue = 0
    discounts_given = 0

    order_records.find_each do |order|
      total_revenue += order.raw_data["total_price"].to_f rescue 0
      tax_collected += order.raw_data["total_tax"].to_f rescue 0
      shipping_revenue += order.raw_data["total_shipping"].to_f rescue 0
      discounts_given += order.raw_data["total_discounts"].to_f rescue 0
    end

    total_orders = order_records.count

    # Calculate previous period for comparison
    period_length = @end_date - @start_date
    previous_start = @start_date - period_length
    previous_end = @start_date

    previous_orders = order_records_scope_for_period(previous_start, previous_end)
    previous_revenue = 0
    previous_orders.find_each do |order|
      previous_revenue += order.raw_data["total_price"].to_f rescue 0
    end
    previous_order_count = previous_orders.count

    {
      total_revenue: total_revenue,
      total_orders: total_orders,
      average_order_value: total_orders > 0 ? (total_revenue / total_orders).round(2) : 0,
      revenue_growth: calculate_percentage_change(previous_revenue, total_revenue),
      order_growth: calculate_percentage_change(previous_order_count, total_orders),
      tax_collected: tax_collected,
      shipping_revenue: shipping_revenue,
      discounts_given: discounts_given
    }
  end

  def calculate_revenue_trends
    order_records = order_records_scope

    # Group by day for detailed trends
    daily_revenue = {}
    daily_orders = {}

    order_records.find_each do |order|
      date_key = order.created_at.to_date.strftime("%Y-%m-%d")
      revenue = order.raw_data["total_price"].to_f rescue 0

      daily_revenue[date_key] = (daily_revenue[date_key] || 0) + revenue
      daily_orders[date_key] = (daily_orders[date_key] || 0) + 1
    end

    # Calculate moving averages
    revenue_values = daily_revenue.values
    moving_avg_7 = calculate_moving_average(revenue_values, 7)
    moving_avg_30 = calculate_moving_average(revenue_values, 30)

    {
      daily_revenue: daily_revenue,
      daily_orders: daily_orders,
      moving_average_7_days: moving_avg_7,
      moving_average_30_days: moving_avg_30,
      peak_revenue_day: daily_revenue.max_by { |_k, v| v },
      peak_orders_day: daily_orders.max_by { |_k, v| v }
    }
  end

  def calculate_fulfillment_metrics
    order_records = order_records_scope

    # Process orders in Ruby
    fulfilled_orders = []
    pending_orders = []
    cancelled_orders = []
    fulfillment_times = []
    fulfilled_revenue = 0
    pending_revenue = 0
    cancelled_revenue = 0

    order_records.find_each do |order|
      fulfillment_status = order.raw_data["fulfillment_status"] rescue nil
      cancelled_at = order.raw_data["cancelled_at"] rescue nil
      total_price = order.raw_data["total_price"].to_f rescue 0

      if cancelled_at
        cancelled_orders << order
        cancelled_revenue += total_price
      elsif fulfillment_status == "fulfilled"
        fulfilled_orders << order
        fulfilled_revenue += total_price

        # Calculate fulfillment time if data available
        fulfilled_at = order.raw_data["fulfilled_at"] rescue nil
        created_at = order.raw_data["created_at"] rescue nil

        if fulfilled_at && created_at
          created = Time.parse(created_at)
          fulfilled = Time.parse(fulfilled_at)
          fulfillment_times << (fulfilled - created) / 1.day
        end
      elsif fulfillment_status.nil? || fulfillment_status == "pending"
        pending_orders << order
        pending_revenue += total_price
      end
    end

    total_orders = order_records.count

    {
      total_orders: total_orders,
      fulfilled_count: fulfilled_orders.count,
      pending_count: pending_orders.count,
      cancelled_count: cancelled_orders.count,
      fulfillment_rate: total_orders > 0 ? (fulfilled_orders.count.to_f / total_orders * 100).round(1) : 0,
      cancellation_rate: total_orders > 0 ? (cancelled_orders.count.to_f / total_orders * 100).round(1) : 0,
      avg_fulfillment_time: fulfillment_times.any? ? (fulfillment_times.sum / fulfillment_times.length).round(1) : 0,
      fulfilled_revenue: fulfilled_revenue,
      pending_revenue: pending_revenue,
      cancelled_revenue: cancelled_revenue
    }
  end

  def calculate_revenue_breakdown
    order_records = order_records_scope

    # Revenue by source
    revenue_by_source = {}
    order_records.includes(:data_source).find_each do |order|
      source_type = order.data_source.source_type
      total_price = order.raw_data["total_price"].to_f rescue 0
      revenue_by_source[source_type] = (revenue_by_source[source_type] || 0) + total_price
    end

    # Revenue by product category (if available)
    revenue_by_category = {}
    order_records.find_each do |order|
      if order.raw_data["line_items"]
        order.raw_data["line_items"].each do |item|
          category = item.dig("product", "product_type") || "Uncategorized"
          price = item["price"].to_f * item["quantity"].to_i
          revenue_by_category[category] = (revenue_by_category[category] || 0) + price
        end
      end
    end

    # Revenue by customer segment
    revenue_by_segment = calculate_customer_segment_revenue(order_records)

    {
      by_source: revenue_by_source,
      by_category: revenue_by_category,
      by_customer_segment: revenue_by_segment
    }
  end

  def calculate_customer_segment_revenue(order_records)
    segments = {
      "New Customers" => 0,
      "Returning Customers" => 0,
      "VIP Customers" => 0
    }

    # First, get customer order counts
    customer_order_counts = {}
    order_records.find_each do |order|
      customer_email = order.raw_data.dig("customer", "email") rescue nil
      next unless customer_email
      customer_order_counts[customer_email] = (customer_order_counts[customer_email] || 0) + 1
    end

    # Then segment revenue
    order_records.find_each do |order|
      customer_email = order.raw_data.dig("customer", "email") rescue nil
      next unless customer_email

      total_price = order.raw_data["total_price"].to_f rescue 0
      customer_orders_count = customer_order_counts[customer_email] || 0

      if customer_orders_count == 1
        segments["New Customers"] += total_price
      elsif total_price > 500 # VIP threshold
        segments["VIP Customers"] += total_price
      else
        segments["Returning Customers"] += total_price
      end
    end

    segments
  end

  def calculate_moving_average(values, window)
    return [] if values.length < window

    (window - 1).upto(values.length - 1).map do |i|
      values[(i - window + 1)..i].sum / window.to_f
    end
  end

  def order_records_scope_for_period(start_date, end_date)
    RawDataRecord.joins(:data_source)
      .where(data_sources: { organization_id: current_organization.id, source_type: [ "shopify", "woocommerce", "stripe" ] })
      .where(record_type: "order")
      .where(created_at: start_date..end_date)
  end
end
