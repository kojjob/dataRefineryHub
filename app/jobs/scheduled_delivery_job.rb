# frozen_string_literal: true

class ScheduledDeliveryJob < ApplicationJob
  queue_as :deliveries

  def perform(delivery_preference)
    return unless delivery_preference.active?

    # Get report data based on preference type
    report_data = generate_report_data(delivery_preference)

    # Deliver using orchestrator
    orchestrator = DeliveryOrchestratorService.new(
      organization: delivery_preference.organization,
      report_type: delivery_preference.report_type,
      report_data: report_data
    )

    # Deliver via the specific channel/format
    result = orchestrator.deliver_via_channel(
      user: delivery_preference.user,
      channel: delivery_preference.channel,
      format: delivery_preference.format
    )

    # Schedule next delivery if recurring
    if delivery_preference.schedule.present?
      DeliverySchedulerJob.schedule_preference(delivery_preference)
    end

    result
  rescue => e
    Rails.logger.error "Scheduled delivery failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    # Log failure
    DeliveryLog.create!(
      user: delivery_preference.user,
      organization: delivery_preference.organization,
      channel: delivery_preference.channel,
      status: "failed",
      report_type: delivery_preference.report_type,
      error_message: e.message,
      metadata: {
        preference_id: delivery_preference.id,
        error_class: e.class.name
      }
    )
  end

  private

  def generate_report_data(preference)
    case preference.report_type
    when "daily_summary"
      generate_daily_summary_data(preference.organization)
    when "weekly_report"
      generate_weekly_report_data(preference.organization)
    when "monthly_analysis"
      generate_monthly_analysis_data(preference.organization)
    when "real_time_alert"
      generate_alert_data(preference.organization)
    when "sales_report"
      generate_sales_report_data(preference.organization)
    when "inventory_report"
      generate_inventory_report_data(preference.organization)
    when "financial_report"
      generate_financial_report_data(preference.organization)
    else
      generate_custom_report_data(preference)
    end
  end

  def generate_daily_summary_data(organization)
    # Calculate daily metrics
    today = Date.current
    yesterday = today - 1.day

    today_revenue = calculate_revenue(organization, today)
    yesterday_revenue = calculate_revenue(organization, yesterday)
    revenue_change = calculate_percentage_change(yesterday_revenue, today_revenue)

    today_orders = count_orders(organization, today)
    yesterday_orders = count_orders(organization, yesterday)
    orders_change = calculate_percentage_change(yesterday_orders, today_orders)

    {
      revenue: {
        total: today_revenue,
        change: revenue_change,
        currency: organization.currency || "USD"
      },
      orders: {
        count: today_orders,
        change: orders_change,
        average: today_orders > 0 ? (today_revenue / today_orders) : 0,
        aov_change: calculate_aov_change(organization, today, yesterday)
      },
      customers: {
        new: count_new_customers(organization, today),
        returning: count_returning_customers(organization, today),
        total_active: count_active_customers(organization, today)
      },
      top_products: get_top_products(organization, today, limit: 5),
      insights: generate_daily_insights(organization, today),
      alerts: get_active_alerts(organization)
    }
  end

  def generate_weekly_report_data(organization)
    week_start = Date.current.beginning_of_week
    week_end = Date.current.end_of_week
    last_week_start = week_start - 1.week

    {
      week_start: week_start,
      week_end: week_end,
      summary: {
        revenue: calculate_revenue(organization, week_start..week_end),
        orders: count_orders(organization, week_start..week_end),
        aov: calculate_average_order_value(organization, week_start..week_end),
        growth: calculate_week_over_week_growth(organization, week_start),
        retention: calculate_customer_retention(organization, week_start..week_end)
      },
      daily_breakdown: generate_daily_breakdown(organization, week_start, week_end),
      insights: generate_weekly_insights(organization, week_start, week_end),
      top_performers: {
        products: get_top_products(organization, week_start..week_end, limit: 10),
        customers: get_top_customers(organization, week_start..week_end, limit: 10),
        categories: get_top_categories(organization, week_start..week_end)
      }
    }
  end

  def generate_monthly_analysis_data(organization)
    current_month = Date.current.beginning_of_month
    last_month = current_month - 1.month

    {
      month: current_month.strftime("%B %Y"),
      executive_summary: generate_executive_summary(organization, current_month),
      performance: {
        revenue: calculate_revenue(organization, current_month..Date.current),
        growth: calculate_month_over_month_growth(organization, current_month),
        margin: calculate_profit_margin(organization, current_month..Date.current),
        customer_acquisition_cost: calculate_cac(organization, current_month),
        lifetime_value: calculate_ltv(organization)
      },
      insights: generate_monthly_insights(organization, current_month),
      recommendations: generate_recommendations(organization, current_month),
      trend_data: generate_trend_data(organization, 6.months.ago..Date.current)
    }
  end

  def generate_sales_report_data(organization)
    period = determine_report_period(organization)

    {
      period: format_period(period),
      total_sales: calculate_revenue(organization, period),
      transaction_count: count_orders(organization, period),
      average_sale: calculate_average_order_value(organization, period),
      growth: calculate_period_growth(organization, period),
      top_channel: get_top_sales_channel(organization, period),
      sales_by_category: get_sales_by_category(organization, period),
      top_customers: get_top_customers(organization, period, limit: 20),
      hourly_distribution: get_hourly_sales_distribution(organization, period)
    }
  end

  def generate_inventory_report_data(organization)
    {
      total_skus: count_total_skus(organization),
      total_value: calculate_inventory_value(organization),
      low_stock_count: count_low_stock_items(organization),
      out_of_stock_count: count_out_of_stock_items(organization),
      low_stock_items: get_low_stock_items(organization, limit: 20),
      overstock_items: get_overstock_items(organization, limit: 10),
      turnover_rate: calculate_inventory_turnover(organization),
      recommendations: generate_inventory_recommendations(organization)
    }
  end

  def generate_financial_report_data(organization)
    period = Date.current.beginning_of_month..Date.current

    revenue = calculate_revenue(organization, period)
    cogs = calculate_cogs(organization, period)
    gross_profit = revenue - cogs
    operating_expenses = calculate_operating_expenses(organization, period)
    net_income = gross_profit - operating_expenses

    {
      period: format_period(period),
      revenue: revenue,
      cogs: cogs,
      cogs_percentage: (cogs / revenue * 100).round(2),
      gross_profit: gross_profit,
      gross_margin: (gross_profit / revenue * 100).round(2),
      operating_expenses: operating_expenses,
      opex_percentage: (operating_expenses / revenue * 100).round(2),
      net_income: net_income,
      net_margin: (net_income / revenue * 100).round(2),
      financial_ratios: calculate_financial_ratios(organization, period),
      cash_flow_data: generate_cash_flow_data(organization, period)
    }
  end

  def generate_custom_report_data(preference)
    # This would be customizable based on user preferences
    {
      title: preference.report_type.humanize,
      generated_at: Time.current,
      data: {}
    }
  end

  # Helper methods for data calculation

  def calculate_revenue(organization, date_or_range)
    organization.raw_data_records
                .where(record_type: "order")
                .where(created_at: date_or_range)
                .sum("COALESCE((data->>'total')::decimal, 0)")
  end

  def count_orders(organization, date_or_range)
    organization.raw_data_records
                .where(record_type: "order")
                .where(created_at: date_or_range)
                .count
  end

  def calculate_percentage_change(old_value, new_value)
    return 0 if old_value.zero?
    ((new_value - old_value) / old_value * 100).round(2)
  end

  def calculate_average_order_value(organization, date_or_range)
    revenue = calculate_revenue(organization, date_or_range)
    orders = count_orders(organization, date_or_range)

    return 0 if orders.zero?
    (revenue / orders).round(2)
  end

  def count_new_customers(organization, date)
    organization.raw_data_records
                .where(record_type: "customer")
                .where(created_at: date.all_day)
                .count
  end

  def count_returning_customers(organization, date)
    # This would check for customers who made repeat purchases
    organization.raw_data_records
                .where(record_type: "order")
                .where(created_at: date.all_day)
                .where("data->>'customer_type' = 'returning'")
                .distinct
                .count("data->>'customer_id'")
  end

  def count_active_customers(organization, date)
    organization.raw_data_records
                .where(record_type: "order")
                .where(created_at: date.all_day)
                .distinct
                .count("data->>'customer_id'")
  end

  def get_top_products(organization, date_or_range, limit: 5)
    organization.raw_data_records
                .where(record_type: "order_item")
                .where(created_at: date_or_range)
                .group("data->>'product_name'")
                .order("sum_revenue DESC")
                .limit(limit)
                .pluck(
                  "data->>'product_name'",
                  Arel.sql("SUM((data->>'quantity')::int) as units"),
                  Arel.sql("SUM((data->>'total')::decimal) as sum_revenue")
                )
                .map do |name, units, revenue|
                  {
                    name: name,
                    units: units,
                    revenue: revenue
                  }
                end
  end

  def generate_daily_insights(organization, date)
    insights = []

    # Revenue insight
    revenue_change = calculate_percentage_change(
      calculate_revenue(organization, date - 1.day),
      calculate_revenue(organization, date)
    )

    if revenue_change.abs > 20
      insights << if revenue_change > 0
        "Revenue increased by #{revenue_change}% compared to yesterday"
      else
        "Revenue decreased by #{revenue_change.abs}% compared to yesterday"
      end
    end

    # Add more insights based on data patterns
    insights
  end

  def get_active_alerts(organization)
    # This would fetch active alerts from monitoring system
    []
  end

  def format_period(period)
    if period.is_a?(Range)
      "#{period.first.strftime('%B %d')} - #{period.last.strftime('%B %d, %Y')}"
    else
      period.strftime("%B %d, %Y")
    end
  end

  def determine_report_period(organization)
    # Default to last 30 days, but could be customizable
    30.days.ago.to_date..Date.current
  end
end
