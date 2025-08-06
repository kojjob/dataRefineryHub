class Analytics::CustomersController < Analytics::BaseController
  before_action :set_date_range

  def index
    authorize :analytics, :index?

    @customer_metrics = calculate_customer_analytics
    @acquisition_insights = calculate_acquisition_insights
    @customer_segments = calculate_top_segments
    @customer_growth_data = calculate_customer_growth_data
  end

  def acquisition
    authorize :analytics, :index?

    @acquisition_insights = calculate_acquisition_insights
    render json: @acquisition_insights
  end

  def segments
    authorize :analytics, :index?

    @customer_segments = calculate_detailed_segments
    render json: @customer_segments
  end

  def lifetime_value
    authorize :analytics, :index?

    @ltv_analysis = calculate_lifetime_value_analysis
    render json: @ltv_analysis
  end

  private

  def set_date_range
    @date_range = params[:date_range] || "30_days"
    @start_date, @end_date = calculate_date_range(@date_range)
  end

  def calculate_customer_analytics
    customer_records = customer_records_scope
    order_records = order_records_scope

    # Basic customer metrics
    total_customers = customer_records.count

    # Since raw_data is encrypted, we need to process in Ruby
    new_customers = customer_records.select do |record|
      created_at = record.raw_data["created_at"] rescue nil
      created_at && Time.parse(created_at) >= @start_date
    end.count

    # Calculate repeat customers from orders
    customer_emails = {}
    order_records.find_each do |order|
      email = order.raw_data.dig("customer", "email") rescue nil
      next unless email
      customer_emails[email] = (customer_emails[email] || 0) + 1
    end
    repeat_customers = customer_emails.select { |_email, count| count > 1 }.length

    # Customer geography analysis
    geography_data = {}
    customer_records.find_each do |record|
      country = record.raw_data.dig("default_address", "country") rescue nil
      next unless country
      geography_data[country] = (geography_data[country] || 0) + 1
    end

    # Customer acquisition trends
    monthly_acquisitions = {}
    customer_records.find_each do |record|
      created_at = record.raw_data["created_at"] rescue nil
      next unless created_at
      month_key = Time.parse(created_at).strftime("%Y-%m")
      monthly_acquisitions[month_key] = (monthly_acquisitions[month_key] || 0) + 1
    end

    {
      total_customers: total_customers,
      new_customers: new_customers,
      returning_customers: repeat_customers,
      customer_retention_rate: total_customers > 0 ? (repeat_customers.to_f / total_customers * 100).round(1) : 0,
      geography_distribution: geography_data,
      monthly_acquisitions: monthly_acquisitions.transform_keys { |k| k&.strftime("%Y-%m") },
      avg_customer_lifetime_orders: calculate_avg_lifetime_orders(order_records)
    }
  end

  def calculate_acquisition_insights
    customer_records = customer_records_scope
    order_records = order_records_scope

    # Calculate Customer Acquisition Cost (CAC) proxy
    # This would ideally include marketing spend data
    marketing_cost = 0
    RawDataRecord.joins(:data_source)
      .where(data_sources: { organization_id: current_organization.id, source_type: [ "google_ads", "facebook_ads", "mailchimp" ] })
      .where(created_at: @start_date..@end_date)
      .find_each do |record|
        cost = record.raw_data["cost"] rescue nil
        marketing_cost += cost.to_f if cost
      end

    new_customers_count = customer_records.select do |record|
      created_at = record.raw_data["created_at"] rescue nil
      created_at && Time.parse(created_at) >= @start_date
    end.count
    estimated_cac = new_customers_count > 0 ? (marketing_cost / new_customers_count).round(2) : 0

    # Customer sources analysis
    acquisition_sources = {}
    customer_records.find_each do |record|
      utm_source = record.raw_data.dig("marketing", "utm_source") rescue nil
      next unless utm_source
      acquisition_sources[utm_source] = (acquisition_sources[utm_source] || 0) + 1
    end

    # First purchase analysis
    first_purchases = {}
    order_records.order(:created_at).find_each do |order|
      email = order.raw_data.dig("customer", "email") rescue nil
      total_price = order.raw_data["total_price"] rescue nil
      next unless email && total_price
      first_purchases[email] ||= total_price.to_f
    end

    avg_first_purchase = first_purchases.any? ? (first_purchases.values.sum / first_purchases.size) : 0

    {
      new_customers_count: new_customers_count,
      estimated_cac: estimated_cac,
      acquisition_sources: acquisition_sources,
      avg_first_purchase_value: avg_first_purchase.round(2),
      acquisition_conversion_rate: calculate_acquisition_conversion_rate,
      monthly_acquisition_trend: calculate_monthly_acquisition_trend
    }
  end

  def calculate_top_segments
    order_records = order_records_scope

    # Customer value segments
    customer_values = {}
    order_records.find_each do |order|
      email = order.raw_data.dig("customer", "email")
      next unless email

      customer_values[email] = (customer_values[email] || 0) + order.raw_data["total_price"].to_f
    end

    # Segment customers by value
    segments = {
      "High Value (>$1000)" => customer_values.select { |_k, v| v > 1000 }.length,
      "Medium Value ($250-$1000)" => customer_values.select { |_k, v| v >= 250 && v <= 1000 }.length,
      "Low Value (<$250)" => customer_values.select { |_k, v| v < 250 }.length
    }

    # Geographic segments
    customer_records = customer_records_scope
    geographic_segments = {}
    customer_records.find_each do |record|
      country = record.raw_data.dig("default_address", "country") rescue nil
      next unless country
      geographic_segments[country] = (geographic_segments[country] || 0) + 1
    end
    geographic_segments = geographic_segments.sort_by { |_k, v| -v }.first(10).to_h

    # Behavior segments based on order frequency
    order_frequency = {}
    customer_order_counts = {}
    order_records.find_each do |order|
      email = order.raw_data.dig("customer", "email") rescue nil
      next unless email
      customer_order_counts[email] = (customer_order_counts[email] || 0) + 1
    end

    customer_order_counts.each do |email, count|
      case count
      when 1
        order_frequency["One-time Buyers"] = (order_frequency["One-time Buyers"] || 0) + 1
      when 2..5
        order_frequency["Occasional Buyers"] = (order_frequency["Occasional Buyers"] || 0) + 1
      else
        order_frequency["Frequent Buyers"] = (order_frequency["Frequent Buyers"] || 0) + 1
      end
    end

    {
      value_segments: segments,
      geographic_segments: geographic_segments,
      behavior_segments: order_frequency
    }
  end

  def calculate_detailed_segments
    customer_records = customer_records_scope
    order_records = order_records_scope

    segments = []

    # RFM Analysis (Recency, Frequency, Monetary)
    customer_rfm = {}

    order_records.find_each do |order|
      email = order.raw_data.dig("customer", "email")
      next unless email

      created_at = Time.parse(order.raw_data["created_at"])
      total_price = order.raw_data["total_price"].to_f

      if customer_rfm[email]
        customer_rfm[email][:frequency] += 1
        customer_rfm[email][:monetary] += total_price
        customer_rfm[email][:recency] = [ customer_rfm[email][:recency], created_at ].max
      else
        customer_rfm[email] = {
          frequency: 1,
          monetary: total_price,
          recency: created_at
        }
      end
    end

    # Calculate RFM scores
    customer_rfm.each do |email, data|
      recency_days = (Time.current - data[:recency]) / 1.day

      # Score from 1-5 (5 being best)
      recency_score = case recency_days
      when 0..7 then 5
      when 8..30 then 4
      when 31..90 then 3
      when 91..365 then 2
      else 1
      end

      frequency_score = case data[:frequency]
      when 1 then 1
      when 2..3 then 2
      when 4..6 then 3
      when 7..10 then 4
      else 5
      end

      monetary_score = case data[:monetary]
      when 0..50 then 1
      when 51..150 then 2
      when 151..300 then 3
      when 301..500 then 4
      else 5
      end

      # Determine segment based on RFM scores
      segment = determine_customer_segment(recency_score, frequency_score, monetary_score)

      segments << {
        email: email,
        recency_score: recency_score,
        frequency_score: frequency_score,
        monetary_score: monetary_score,
        segment: segment,
        total_spent: data[:monetary],
        order_count: data[:frequency],
        last_order: data[:recency]
      }
    end

    # Group by segment
    segment_summary = segments.group_by { |s| s[:segment] }.transform_values do |customers|
      {
        count: customers.length,
        avg_spent: customers.sum { |c| c[:total_spent] } / customers.length,
        avg_orders: customers.sum { |c| c[:order_count] } / customers.length
      }
    end

    {
      segments: segments,
      segment_summary: segment_summary
    }
  end

  def calculate_lifetime_value_analysis
    order_records = order_records_scope

    customer_data = {}

    order_records.find_each do |order|
      email = order.raw_data.dig("customer", "email")
      next unless email

      created_at = Time.parse(order.raw_data["created_at"])
      total_price = order.raw_data["total_price"].to_f

      if customer_data[email]
        customer_data[email][:orders] << {
          date: created_at,
          value: total_price
        }
      else
        customer_data[email] = {
          orders: [ {
            date: created_at,
            value: total_price
          } ]
        }
      end
    end

    # Calculate CLV metrics
    ltv_metrics = customer_data.map do |email, data|
      orders = data[:orders].sort_by { |o| o[:date] }

      total_value = orders.sum { |o| o[:value] }
      order_count = orders.length
      avg_order_value = total_value / order_count

      # Calculate customer lifespan in days
      lifespan = orders.length > 1 ? (orders.last[:date] - orders.first[:date]) / 1.day : 0

      # Estimate purchase frequency (orders per month)
      purchase_frequency = lifespan > 0 ? (order_count / (lifespan / 30.0)) : order_count

      # Simple CLV calculation: AOV * Purchase Frequency * Estimated Lifespan
      estimated_lifespan_months = [ lifespan / 30.0, 12 ].max # Assume minimum 1 year
      estimated_clv = avg_order_value * purchase_frequency * estimated_lifespan_months

      {
        email: email,
        total_spent: total_value,
        order_count: order_count,
        avg_order_value: avg_order_value,
        lifespan_days: lifespan,
        purchase_frequency: purchase_frequency,
        estimated_clv: estimated_clv
      }
    end

    {
      customer_ltv: ltv_metrics,
      avg_clv: ltv_metrics.sum { |c| c[:estimated_clv] } / ltv_metrics.length,
      high_value_customers: ltv_metrics.select { |c| c[:estimated_clv] > 1000 }.length,
      clv_distribution: calculate_clv_distribution(ltv_metrics)
    }
  end

  def determine_customer_segment(recency, frequency, monetary)
    # Champions: High on all dimensions
    return "Champions" if recency >= 4 && frequency >= 4 && monetary >= 4

    # Loyal Customers: High frequency and monetary, medium recency
    return "Loyal Customers" if frequency >= 3 && monetary >= 3

    # Potential Loyalists: Recent customers with good potential
    return "Potential Loyalists" if recency >= 4 && monetary >= 2

    # New Customers: High recency, low frequency
    return "New Customers" if recency >= 4 && frequency <= 2

    # At Risk: Low recency but high frequency/monetary
    return "At Risk" if recency <= 2 && frequency >= 3

    # Cannot Lose Them: Low recency but very high monetary
    return "Cannot Lose Them" if recency <= 2 && monetary >= 4

    # Hibernating: Low on all dimensions
    return "Hibernating" if recency <= 2 && frequency <= 2 && monetary <= 2

    "Others"
  end

  def calculate_avg_lifetime_orders(order_records)
    customer_orders = {}
    order_records.find_each do |order|
      email = order.raw_data.dig("customer", "email") rescue nil
      next unless email
      customer_orders[email] = (customer_orders[email] || 0) + 1
    end

    return 0 if customer_orders.empty?
    customer_orders.values.sum.to_f / customer_orders.length
  end

  def calculate_acquisition_conversion_rate
    # This would need website visitor data to calculate properly
    # For now, return a placeholder
    0.0
  end

  def calculate_monthly_acquisition_trend
    customer_records = customer_records_scope

    monthly_trend = {}
    customer_records.find_each do |record|
      created_at = record.raw_data["created_at"] rescue nil
      next unless created_at

      month_key = Time.parse(created_at).strftime("%Y-%m")
      monthly_trend[month_key] = (monthly_trend[month_key] || 0) + 1
    end

    monthly_trend
  end

  def calculate_clv_distribution(ltv_metrics)
    clv_values = ltv_metrics.map { |c| c[:estimated_clv] }

    {
      "Under $100" => clv_values.count { |v| v < 100 },
      "$100 - $500" => clv_values.count { |v| v >= 100 && v < 500 },
      "$500 - $1000" => clv_values.count { |v| v >= 500 && v < 1000 },
      "$1000 - $2000" => clv_values.count { |v| v >= 1000 && v < 2000 },
      "Over $2000" => clv_values.count { |v| v >= 2000 }
    }
  end

  def calculate_customer_growth_data
    customer_records = customer_records_scope

    # Initialize daily data
    daily_data = {}
    (@start_date.to_date..@end_date.to_date).each do |date|
      daily_data[date.to_s] = { new_customers: 0, total_customers: 0 }
    end

    # Count new customers per day
    customer_records.find_each do |record|
      created_at = record.raw_data["created_at"] rescue nil
      next unless created_at

      customer_date = Time.parse(created_at).to_date
      date_str = customer_date.to_s

      # Count new customers for dates in range
      if daily_data[date_str]
        daily_data[date_str][:new_customers] += 1
      end
    end

    # Calculate cumulative totals
    running_total = @customer_metrics[:total_customers] - @customer_metrics[:new_customers]
    daily_data.keys.sort.each do |date|
      running_total += daily_data[date][:new_customers]
      daily_data[date][:total_customers] = running_total
    end

    # Convert to arrays for chart
    dates = daily_data.keys.sort
    new_customers = dates.map { |date| daily_data[date][:new_customers] }
    total_customers = dates.map { |date| daily_data[date][:total_customers] }

    {
      labels: dates.map { |d| Date.parse(d).strftime("%b %d") },
      new_customers: new_customers,
      total_customers: total_customers
    }
  end
end
