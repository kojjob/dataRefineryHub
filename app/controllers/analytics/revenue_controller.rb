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

    total_revenue = order_records.sum("CAST(raw_data->>'total_price' AS DECIMAL)")
    total_orders = order_records.count

    # Calculate previous period for comparison
    period_length = @end_date - @start_date
    previous_start = @start_date - period_length
    previous_end = @start_date

    previous_orders = order_records_scope_for_period(previous_start, previous_end)
    previous_revenue = previous_orders.sum("CAST(raw_data->>'total_price' AS DECIMAL)")
    previous_order_count = previous_orders.count

    {
      total_revenue: total_revenue,
      total_orders: total_orders,
      average_order_value: total_orders > 0 ? (total_revenue / total_orders).round(2) : 0,
      revenue_growth: calculate_percentage_change(previous_revenue, total_revenue),
      order_growth: calculate_percentage_change(previous_order_count, total_orders),
      tax_collected: order_records.sum("CAST(raw_data->>'total_tax' AS DECIMAL)"),
      shipping_revenue: order_records.sum("CAST(raw_data->>'total_shipping' AS DECIMAL)"),
      discounts_given: order_records.sum("CAST(raw_data->>'total_discounts' AS DECIMAL)")
    }
  end

  def calculate_revenue_trends
    order_records = order_records_scope

    # Group by day for detailed trends
    daily_revenue = order_records
      .group("DATE(created_at)")
      .sum("CAST(raw_data->>'total_price' AS DECIMAL)")
      .transform_keys { |date| date.strftime("%Y-%m-%d") }

    daily_orders = order_records
      .group("DATE(created_at)")
      .count
      .transform_keys { |date| date.strftime("%Y-%m-%d") }

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

    fulfilled_orders = order_records.where("raw_data->>'fulfillment_status' = ?", "fulfilled")
    pending_orders = order_records.where("raw_data->>'fulfillment_status' IS NULL OR raw_data->>'fulfillment_status' = ?", "pending")
    cancelled_orders = order_records.where("raw_data->>'cancelled_at' IS NOT NULL")

    # Calculate fulfillment times for fulfilled orders
    fulfilled_with_times = fulfilled_orders.where("raw_data->>'fulfilled_at' IS NOT NULL")
    fulfillment_times = fulfilled_with_times.map do |order|
      created = Time.parse(order.raw_data["created_at"])
      fulfilled = Time.parse(order.raw_data["fulfilled_at"])
      (fulfilled - created) / 1.day
    end

    {
      total_orders: order_records.count,
      fulfilled_count: fulfilled_orders.count,
      pending_count: pending_orders.count,
      cancelled_count: cancelled_orders.count,
      fulfillment_rate: order_records.count > 0 ? (fulfilled_orders.count.to_f / order_records.count * 100).round(1) : 0,
      cancellation_rate: order_records.count > 0 ? (cancelled_orders.count.to_f / order_records.count * 100).round(1) : 0,
      avg_fulfillment_time: fulfillment_times.any? ? (fulfillment_times.sum / fulfillment_times.length).round(1) : 0,
      fulfilled_revenue: fulfilled_orders.sum("CAST(raw_data->>'total_price' AS DECIMAL)"),
      pending_revenue: pending_orders.sum("CAST(raw_data->>'total_price' AS DECIMAL)"),
      cancelled_revenue: cancelled_orders.sum("CAST(raw_data->>'total_price' AS DECIMAL)")
    }
  end

  def calculate_revenue_breakdown
    order_records = order_records_scope

    # Revenue by source
    revenue_by_source = order_records
      .joins(:data_source)
      .group("data_sources.source_type")
      .sum("CAST(raw_data->>'total_price' AS DECIMAL)")

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

    order_records.find_each do |order|
      customer_email = order.raw_data["customer"]&.dig("email")
      next unless customer_email

      total_price = order.raw_data["total_price"].to_f

      # Simple segmentation logic - in practice this would be more sophisticated
      customer_orders_count = order_records
        .where("raw_data->'customer'->>'email' = ?", customer_email)
        .count

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
