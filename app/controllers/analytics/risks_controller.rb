class Analytics::RisksController < Analytics::BaseController
  before_action :set_date_range

  def index
    authorize :analytics, :index?

    @risk_indicators = calculate_risk_indicators
    @growth_opportunities = calculate_growth_opportunities
  end

  def indicators
    authorize :analytics, :index?

    @risk_analysis = calculate_comprehensive_risk_analysis
    render json: @risk_analysis
  end

  def opportunities
    authorize :analytics, :index?

    @opportunities = calculate_detailed_opportunities
    render json: @opportunities
  end

  private

  def set_date_range
    @date_range = params[:date_range] || "30_days"
    @start_date, @end_date = calculate_date_range(@date_range)
  end

  def calculate_risk_indicators
    order_records = order_records_scope
    customer_records = customer_records_scope

    # Revenue concentration risk
    customer_revenue = {}
    order_records.find_each do |order|
      email = order.raw_data.dig("customer", "email")
      next unless email
      customer_revenue[email] = (customer_revenue[email] || 0) + order.raw_data["total_price"].to_f
    end

    total_revenue = customer_revenue.values.sum
    top_customer_revenue = customer_revenue.values.max || 0
    revenue_concentration = total_revenue > 0 ? (top_customer_revenue / total_revenue * 100).round(1) : 0

    # Order failure analysis
    failed_orders_count = 0
    order_records.find_each do |order|
      financial_status = order.raw_data["financial_status"] rescue nil
      failed_orders_count += 1 if financial_status == "cancelled"
    end
    total_orders_count = order_records.count
    failure_rate = total_orders_count > 0 ? (failed_orders_count.to_f / total_orders_count * 100).round(1) : 0

    # Customer churn indicators
    recent_orders = order_records.where("raw_data_records.created_at >= ?", 2.weeks.ago)
    recent_customers = []
    recent_orders.find_each do |order|
      email = order.raw_data.dig("customer", "email") rescue nil
      recent_customers << email if email
    end
    recent_customers.uniq!

    older_orders = order_records.where("raw_data_records.created_at < ?", 2.weeks.ago).where("raw_data_records.created_at >= ?", 6.weeks.ago)
    older_customers = []
    older_orders.find_each do |order|
      email = order.raw_data.dig("customer", "email") rescue nil
      older_customers << email if email
    end
    older_customers.uniq!

    returning_customers = (recent_customers & older_customers).length
    churn_risk = older_customers.any? ? ((older_customers.length - returning_customers).to_f / older_customers.length * 100).round(1) : 0

    # Geographic concentration
    geographic_revenue = {}
    order_records.find_each do |order|
      country = order.raw_data.dig("shipping_address", "country") || order.raw_data.dig("customer", "default_address", "country")
      next unless country
      geographic_revenue[country] = (geographic_revenue[country] || 0) + order.raw_data["total_price"].to_f
    end

    top_country_revenue = geographic_revenue.values.max || 0
    geographic_concentration = total_revenue > 0 ? (top_country_revenue / total_revenue * 100).round(1) : 0

    # Payment method risks
    payment_methods = {}
    order_records.find_each do |order|
      method = order.raw_data.dig("payment_details", "method") rescue nil
      if method
        payment_methods[method] = (payment_methods[method] || 0) + 1
      end
    end

    # Overall risk score calculation
    overall_risk_score = calculate_overall_risk_score(
      revenue_concentration,
      failure_rate,
      churn_risk,
      geographic_concentration
    )

    {
      revenue_concentration: revenue_concentration,
      top_customer_dependency: revenue_concentration > 30,
      order_failure_rate: failure_rate,
      high_failure_rate: failure_rate > 10,
      customer_churn_risk: churn_risk,
      high_churn_risk: churn_risk > 20,
      geographic_concentration: geographic_concentration,
      geographic_dependency: geographic_concentration > 50,
      payment_method_distribution: payment_methods,
      overall_risk_score: overall_risk_score,
      risk_level: determine_risk_level(overall_risk_score),
      recommendations: generate_risk_recommendations(revenue_concentration, failure_rate, churn_risk, geographic_concentration)
    }
  end

  def calculate_growth_opportunities
    order_records = order_records_scope
    product_records = product_records_scope

    opportunities = []

    # Market expansion opportunities
    geographic_analysis = analyze_geographic_opportunities(order_records)
    if geographic_analysis[:untapped_markets].any?
      opportunities << {
        type: "geographic_expansion",
        priority: "high",
        title: "Expand to New Markets",
        description: "Untapped geographic markets with growth potential",
        markets: geographic_analysis[:untapped_markets].first(3),
        estimated_impact: geographic_analysis[:expansion_potential]
      }
    end

    # Seasonal opportunities
    seasonal_patterns = analyze_seasonal_patterns(order_records)
    if seasonal_patterns[:upcoming_peak]
      opportunities << {
        type: "seasonal_preparation",
        priority: "medium",
        title: "Prepare for Seasonal Peak",
        description: "Upcoming seasonal opportunity based on historical patterns",
        season: seasonal_patterns[:peak_season],
        preparation_time: seasonal_patterns[:days_until_peak],
        estimated_uplift: seasonal_patterns[:peak_multiplier]
      }
    end

    # Cross-sell opportunities
    cross_sell = identify_cross_sell_opportunities(order_records)
    if cross_sell[:opportunities].any?
      opportunities << {
        type: "cross_selling",
        priority: "medium",
        title: "Product Cross-Selling",
        description: "Products frequently bought together",
        product_pairs: cross_sell[:opportunities].first(5),
        potential_revenue: cross_sell[:revenue_potential]
      }
    end

    # Customer segment opportunities
    customer_segments = analyze_customer_opportunities
    opportunities.concat(customer_segments)

    # Price optimization opportunities
    price_opportunities = identify_price_optimization_opportunities(order_records)
    opportunities.concat(price_opportunities)

    {
      opportunities: opportunities.sort_by { |o| [ "high", "medium", "low" ].index(o[:priority]) },
      total_opportunities: opportunities.length,
      high_impact_count: opportunities.count { |o| o[:priority] == "high" },
      estimated_total_impact: opportunities.sum { |o| o[:estimated_impact] || 0 }
    }
  end

  def calculate_comprehensive_risk_analysis
    basic_risks = calculate_risk_indicators

    # Additional risk factors
    operational_risks = analyze_operational_risks
    financial_risks = analyze_financial_risks
    market_risks = analyze_market_risks

    {
      basic_indicators: basic_risks,
      operational_risks: operational_risks,
      financial_risks: financial_risks,
      market_risks: market_risks,
      risk_mitigation_plan: generate_risk_mitigation_plan(basic_risks, operational_risks, financial_risks)
    }
  end

  def calculate_detailed_opportunities
    basic_opportunities = calculate_growth_opportunities

    # Additional opportunity analysis
    digital_opportunities = analyze_digital_opportunities
    product_opportunities = analyze_product_opportunities
    partnership_opportunities = analyze_partnership_opportunities

    {
      growth_opportunities: basic_opportunities,
      digital_opportunities: digital_opportunities,
      product_opportunities: product_opportunities,
      partnership_opportunities: partnership_opportunities,
      prioritized_roadmap: create_opportunity_roadmap(basic_opportunities[:opportunities])
    }
  end

  private

  def analyze_geographic_opportunities(order_records)
    # Analyze current geographic distribution
    country_revenue = {}
    order_records.find_each do |order|
      country = order.raw_data.dig("shipping_address", "country") || order.raw_data.dig("customer", "default_address", "country")
      next unless country
      country_revenue[country] = (country_revenue[country] || 0) + order.raw_data["total_price"].to_f
    end

    current_markets = country_revenue.keys

    # Identify potential markets (this would be enhanced with market research data)
    potential_markets = [ "Canada", "United Kingdom", "Australia", "Germany", "France" ] - current_markets

    avg_country_revenue = country_revenue.values.any? ? country_revenue.values.sum.to_f / country_revenue.values.length : 0
    expansion_potential = potential_markets.length * avg_country_revenue * 0.1 # Conservative estimate

    {
      current_markets: country_revenue,
      untapped_markets: potential_markets,
      expansion_potential: expansion_potential.round(2),
      market_diversity_score: calculate_market_diversity_score(country_revenue)
    }
  end

  def analyze_seasonal_patterns(order_records)
    # Analyze monthly order patterns
    monthly_orders = {}
    order_records.find_each do |order|
      month = order.created_at.month
      monthly_orders[month] = (monthly_orders[month] || 0) + 1
    end

    current_month = Time.current.month

    # Simple seasonal analysis (would be enhanced with historical data)
    peak_months = monthly_orders.sort_by { |_k, v| -v }.first(3).map { |k, _v| k }

    if peak_months.empty?
      # No data available, return default values
      return {
        monthly_patterns: monthly_orders,
        peak_season: "No data",
        days_until_peak: 0,
        peak_multiplier: 1.0,
        upcoming_peak: false
      }
    end

    next_peak = peak_months.find { |month| month > current_month } || peak_months.first
    days_until_peak = (Date.new(Time.current.year, next_peak, 1) - Date.current).to_i
    days_until_peak += 365 if days_until_peak < 0

    avg_orders = monthly_orders.values.any? ? monthly_orders.values.sum.to_f / monthly_orders.length : 1
    peak_orders = monthly_orders[next_peak] || avg_orders
    peak_multiplier = avg_orders > 0 ? peak_orders / avg_orders : 1.0

    {
      monthly_patterns: monthly_orders,
      peak_season: Date::MONTHNAMES[next_peak],
      days_until_peak: days_until_peak,
      peak_multiplier: peak_multiplier.round(2),
      upcoming_peak: days_until_peak < 90 && peak_multiplier > 1.2
    }
  end

  def identify_cross_sell_opportunities(order_records)
    # Analyze products bought together
    product_combinations = {}

    order_records.find_each do |order|
      next unless order.raw_data["line_items"]&.length > 1

      products = order.raw_data["line_items"].map { |item| item["product_id"] }.compact

      products.combination(2).each do |product_a, product_b|
        key = [ product_a, product_b ].sort.join("-")
        if product_combinations[key]
          product_combinations[key][:frequency] += 1
        else
          # Get product titles
          item_a = order.raw_data["line_items"].find { |item| item["product_id"] == product_a }
          item_b = order.raw_data["line_items"].find { |item| item["product_id"] == product_b }

          product_combinations[key] = {
            product_a_title: item_a&.dig("title") || "Unknown",
            product_b_title: item_b&.dig("title") || "Unknown",
            frequency: 1,
            avg_revenue: (item_a&.dig("price").to_f + item_b&.dig("price").to_f)
          }
        end
      end
    end

    # Find frequent combinations
    frequent_combinations = product_combinations.select { |_k, v| v[:frequency] >= 3 }
                                                .sort_by { |_k, v| -v[:frequency] }
                                                .first(10)

    revenue_potential = frequent_combinations.sum { |_k, v| v[:frequency] * v[:avg_revenue] * 0.1 } # Conservative estimate

    {
      opportunities: frequent_combinations.map { |k, v| v.merge(combination_id: k) },
      revenue_potential: revenue_potential.round(2)
    }
  end

  def analyze_customer_opportunities
    opportunities = []

    # Win-back campaigns for churned customers
    opportunities << {
      type: "customer_winback",
      priority: "medium",
      title: "Win-Back Churned Customers",
      description: "Re-engage customers who haven't ordered recently",
      estimated_impact: 1000, # Would calculate based on historical data
      timeline: "30 days"
    }

    # VIP customer program
    opportunities << {
      type: "vip_program",
      priority: "high",
      title: "VIP Customer Program",
      description: "Create loyalty program for high-value customers",
      estimated_impact: 2500,
      timeline: "60 days"
    }

    opportunities
  end

  def identify_price_optimization_opportunities(order_records)
    opportunities = []

    # Analyze price elasticity indicators
    order_records.find_each do |order|
      next unless order.raw_data["line_items"]

      order.raw_data["line_items"].each do |item|
        # Simple heuristic: if quantity > 2, price might be optimizable
        if item["quantity"].to_i > 2
          opportunities << {
            type: "price_optimization",
            priority: "low",
            title: "Price Optimization for #{item['title']}",
            description: "High quantity suggests price elasticity",
            estimated_impact: item["price"].to_f * 0.1,
            product: item["title"]
          }
        end
      end
    end

    # Deduplicate by product
    opportunities.uniq { |o| o[:product] }.first(5)
  end

  def analyze_operational_risks
    extraction_jobs = extraction_jobs_scope

    {
      data_pipeline_reliability: calculate_pipeline_reliability(extraction_jobs),
      integration_health: analyze_integration_health,
      processing_capacity: analyze_processing_capacity
    }
  end

  def analyze_financial_risks
    order_records = order_records_scope

    # Payment failure analysis
    payment_failures = []
    order_records.find_each do |order|
      financial_status = order.raw_data["financial_status"] rescue nil
      payment_failures << order if [ "cancelled", "failed", "declined" ].include?(financial_status)
    end

    {
      payment_failure_rate: calculate_payment_failure_rate(payment_failures, order_records),
      revenue_volatility: calculate_revenue_volatility(order_records),
      cash_flow_risk: analyze_cash_flow_patterns(order_records)
    }
  end

  def analyze_market_risks
    {
      competitive_pressure: "Medium", # Would need external data
      market_saturation: "Low",
      regulatory_risk: "Low",
      technology_disruption: "Medium"
    }
  end

  def calculate_overall_risk_score(revenue_concentration, failure_rate, churn_risk, geographic_concentration)
    # Weight different risk factors
    weighted_score = (
      revenue_concentration * 0.3 +
      failure_rate * 0.2 +
      churn_risk * 0.3 +
      geographic_concentration * 0.2
    )

    # Normalize to 0-100 scale
    [ 0, [ 100, weighted_score ].min ].max.round(1)
  end

  def determine_risk_level(score)
    case score
    when 0..30 then "Low"
    when 31..60 then "Medium"
    when 61..80 then "High"
    else "Critical"
    end
  end

  def generate_risk_recommendations(revenue_concentration, failure_rate, churn_risk, geographic_concentration)
    recommendations = []

    recommendations << "Diversify customer base" if revenue_concentration > 30
    recommendations << "Improve order processing" if failure_rate > 10
    recommendations << "Implement retention strategies" if churn_risk > 20
    recommendations << "Expand to new markets" if geographic_concentration > 50

    recommendations
  end

  def calculate_market_diversity_score(country_revenue)
    return 0 if country_revenue.empty?

    total_revenue = country_revenue.values.sum
    concentration = country_revenue.values.map { |revenue| (revenue / total_revenue) ** 2 }.sum

    # Higher score means more diversity (inverse of concentration)
    ((1 - concentration) * 100).round(1)
  end

  def calculate_pipeline_reliability(extraction_jobs)
    return 100 if extraction_jobs.empty?

    success_rate = (extraction_jobs.completed.count.to_f / extraction_jobs.count * 100).round(1)
    success_rate
  end

  def analyze_integration_health
    # Analyze data source health
    data_sources = current_organization.data_sources
    healthy_sources = data_sources.connected.count
    total_sources = data_sources.count

    health_percentage = total_sources > 0 ? (healthy_sources.to_f / total_sources * 100).round(1) : 100

    {
      health_percentage: health_percentage,
      total_integrations: total_sources,
      healthy_integrations: healthy_sources,
      failing_integrations: total_sources - healthy_sources
    }
  end

  def analyze_processing_capacity
    # Simple capacity analysis based on recent job performance
    recent_jobs = extraction_jobs_scope.where("extraction_jobs.created_at >= ?", 7.days.ago)
    avg_duration = recent_jobs.completed.average("EXTRACT(EPOCH FROM (completed_at - started_at))") || 0

    {
      avg_processing_time: (avg_duration / 60).round(1), # in minutes
      capacity_utilization: "Normal", # Would need more sophisticated analysis
      bottlenecks: []
    }
  end

  def calculate_payment_failure_rate(failed_payments, total_orders)
    return 0 if total_orders.empty?
    (failed_payments.count.to_f / total_orders.count * 100).round(2)
  end

  def calculate_revenue_volatility(order_records)
    daily_revenue = {}
    order_records.find_each do |order|
      date_key = order.created_at.to_date
      total_price = order.raw_data["total_price"].to_f rescue 0
      daily_revenue[date_key] = (daily_revenue[date_key] || 0) + total_price
    end
    daily_revenue = daily_revenue.values

    return 0 if daily_revenue.length < 2

    mean_revenue = daily_revenue.sum / daily_revenue.length
    variance = daily_revenue.sum { |revenue| (revenue - mean_revenue) ** 2 } / daily_revenue.length
    coefficient_of_variation = mean_revenue > 0 ? (Math.sqrt(variance) / mean_revenue * 100).round(1) : 0

    coefficient_of_variation
  end

  def analyze_cash_flow_patterns(order_records)
    # Simple cash flow risk analysis
    weekly_revenue = {}
    order_records.find_each do |order|
      week_key = order.created_at.beginning_of_week
      total_price = order.raw_data["total_price"].to_f rescue 0
      weekly_revenue[week_key] = (weekly_revenue[week_key] || 0) + total_price
    end
    weekly_revenue = weekly_revenue.values

    return "Low" if weekly_revenue.length < 4

    recent_trend = weekly_revenue.last(4)
    declining_weeks = recent_trend.each_cons(2).count { |a, b| b < a }

    case declining_weeks
    when 0..1 then "Low"
    when 2 then "Medium"
    else "High"
    end
  end

  def analyze_digital_opportunities
    [
      {
        type: "seo_optimization",
        title: "SEO Optimization",
        description: "Improve search engine visibility",
        estimated_impact: 1500,
        difficulty: "Medium"
      },
      {
        type: "social_commerce",
        title: "Social Commerce Integration",
        description: "Sell directly through social platforms",
        estimated_impact: 2000,
        difficulty: "High"
      }
    ]
  end

  def analyze_product_opportunities
    [
      {
        type: "product_bundling",
        title: "Product Bundling",
        description: "Create attractive product bundles",
        estimated_impact: 800,
        implementation_time: "2 weeks"
      },
      {
        type: "subscription_model",
        title: "Subscription Products",
        description: "Introduce recurring revenue products",
        estimated_impact: 3000,
        implementation_time: "8 weeks"
      }
    ]
  end

  def analyze_partnership_opportunities
    [
      {
        type: "affiliate_program",
        title: "Affiliate Marketing Program",
        description: "Partner with influencers and affiliates",
        estimated_impact: 2500,
        setup_cost: 500
      },
      {
        type: "wholesale_channel",
        title: "B2B Wholesale Channel",
        description: "Sell to other businesses",
        estimated_impact: 5000,
        setup_cost: 1000
      }
    ]
  end

  def generate_risk_mitigation_plan(basic_risks, operational_risks, financial_risks)
    plan = []

    # Address high-priority risks first
    if basic_risks[:overall_risk_score] > 60
      plan << {
        priority: "immediate",
        action: "Conduct comprehensive risk assessment",
        timeline: "1 week",
        responsible: "Management team"
      }
    end

    if operational_risks[:data_pipeline_reliability] < 90
      plan << {
        priority: "high",
        action: "Improve data pipeline monitoring and alerting",
        timeline: "2 weeks",
        responsible: "Technical team"
      }
    end

    if financial_risks[:payment_failure_rate] > 5
      plan << {
        priority: "high",
        action: "Review payment processing and fraud detection",
        timeline: "1 week",
        responsible: "Finance team"
      }
    end

    plan
  end

  def create_opportunity_roadmap(opportunities)
    # Prioritize opportunities by impact and feasibility
    high_impact = opportunities.select { |o| (o[:estimated_impact] || 0) > 1000 }
    quick_wins = opportunities.select { |o| o[:timeline] && o[:timeline].include?("week") }

    {
      immediate_actions: quick_wins.first(3),
      high_impact_initiatives: high_impact.first(5),
      long_term_goals: opportunities.select { |o| o[:priority] == "high" }.first(3)
    }
  end
end
