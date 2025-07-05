# frozen_string_literal: true

module Ai
  class InsightsEngineService
    include ActiveModel::Model

    attr_accessor :organization, :time_period, :data_sources

    def initialize(organization:, time_period: 7.days, data_sources: nil)
      @organization = organization
      @time_period = time_period
      @data_sources = data_sources || organization.data_sources
      @start_date = time_period.ago
      @end_date = Time.current
    end

    def generate_insights
      # Initialize AI-powered analysis
      llm_service = Ai::LlmService.new(organization: @organization)
      data_context = build_comprehensive_data_context

      # Get AI-enhanced insights
      ai_analysis = llm_service.analyze_business_metrics(data_context, "Generate comprehensive business insights")
      ai_summary = llm_service.generate_executive_summary(data_context)
      ai_anomalies = llm_service.detect_anomalies(build_historical_context, data_context)
      ai_recommendations = llm_service.generate_recommendations(ai_analysis)

      {
        executive_summary: ai_summary.present? ? ai_summary : generate_executive_summary,
        key_insights: ai_analysis[:key_insights] || generate_key_insights,
        anomalies: ai_anomalies.any? ? ai_anomalies : detect_anomalies,
        recommendations: ai_recommendations[:recommendations] || generate_recommendations,
        trends: analyze_trends,
        performance_alerts: generate_performance_alerts,
        ai_enhanced: true,
        confidence_score: ai_analysis[:confidence_level] || "medium",
        generated_at: Time.current.iso8601
      }
    end

    def generate_narrative_summary
      insights = generate_insights
      build_narrative(insights)
    end

    private

    def generate_executive_summary
      metrics = calculate_key_metrics

      {
        revenue_trend: analyze_revenue_trend(metrics),
        customer_growth: analyze_customer_growth(metrics),
        operational_health: analyze_operational_health(metrics),
        key_highlights: extract_key_highlights(metrics),
        priority_actions: identify_priority_actions(metrics)
      }
    end

    def generate_key_insights
      insights = []

      # Revenue insights
      revenue_data = get_revenue_data
      if revenue_data.any?
        insights.concat(analyze_revenue_insights(revenue_data))
      end

      # Customer insights
      customer_data = get_customer_data
      if customer_data.any?
        insights.concat(analyze_customer_insights(customer_data))
      end

      # Product insights
      product_data = get_product_data
      if product_data.any?
        insights.concat(analyze_product_insights(product_data))
      end

      # Operational insights
      operational_data = get_operational_data
      if operational_data.any?
        insights.concat(analyze_operational_insights(operational_data))
      end

      insights.sort_by { |insight| -insight[:impact_score] }.first(10)
    end

    def detect_anomalies
      anomalies = []

      # Revenue anomalies
      anomalies.concat(detect_revenue_anomalies)

      # Traffic anomalies
      anomalies.concat(detect_traffic_anomalies)

      # Conversion anomalies
      anomalies.concat(detect_conversion_anomalies)

      # Data quality anomalies
      anomalies.concat(detect_data_quality_anomalies)

      anomalies.sort_by { |anomaly| -anomaly[:severity_score] }
    end

    def generate_recommendations
      recommendations = []
      insights = generate_key_insights
      anomalies = detect_anomalies

      # Generate recommendations based on insights
      insights.each do |insight|
        recs = generate_insight_recommendations(insight)
        recommendations.concat(recs) if recs.any?
      end

      # Generate recommendations based on anomalies
      anomalies.each do |anomaly|
        recs = generate_anomaly_recommendations(anomaly)
        recommendations.concat(recs) if recs.any?
      end

      # Prioritize recommendations
      recommendations.sort_by { |rec| -rec[:priority_score] }.first(8)
    end

    def analyze_trends
      {
        revenue_trends: analyze_revenue_trends,
        customer_trends: analyze_customer_trends,
        product_trends: analyze_product_trends,
        seasonal_patterns: analyze_seasonal_patterns,
        growth_trajectory: analyze_growth_trajectory
      }
    end

    def generate_performance_alerts
      alerts = []

      # Critical performance thresholds
      current_metrics = calculate_current_metrics
      previous_metrics = calculate_previous_metrics

      # Revenue alerts
      if current_metrics[:revenue_change] < -10
        alerts << create_alert("revenue_decline", "Revenue declined by #{current_metrics[:revenue_change].abs}%", "critical")
      end

      # Customer alerts
      if current_metrics[:customer_churn_rate] > 0.05
        alerts << create_alert("high_churn", "Customer churn rate at #{(current_metrics[:customer_churn_rate] * 100).round(1)}%", "warning")
      end

      # Data quality alerts
      if current_metrics[:data_quality_score] < 0.8
        alerts << create_alert("data_quality", "Data quality score below threshold: #{(current_metrics[:data_quality_score] * 100).round(1)}%", "warning")
      end

      alerts
    end

    # Helper methods for data analysis

    def calculate_key_metrics
      {
        total_revenue: calculate_total_revenue,
        customer_count: calculate_customer_count,
        average_order_value: calculate_average_order_value,
        conversion_rate: calculate_conversion_rate,
        customer_acquisition_cost: calculate_customer_acquisition_cost,
        lifetime_value: calculate_lifetime_value,
        data_processing_volume: calculate_data_processing_volume,
        system_uptime: calculate_system_uptime
      }
    end

    def get_revenue_data
      @organization.raw_data_records
                  .joins(:data_source)
                  .where("raw_data_records.created_at >= ?", @start_date)
                  .where("raw_data_records.record_type = ?", "order")
                  .includes(:data_source)
    end

    def get_customer_data
      @organization.raw_data_records
                  .joins(:data_source)
                  .where("raw_data_records.created_at >= ?", @start_date)
                  .where("raw_data_records.record_type = ?", "customer")
                  .includes(:data_source)
    end

    def get_product_data
      @organization.raw_data_records
                  .joins(:data_source)
                  .where("raw_data_records.created_at >= ?", @start_date)
                  .where("raw_data_records.record_type = ?", "product")
                  .includes(:data_source)
    end

    def get_operational_data
      @organization.extraction_jobs
                  .where("created_at >= ?", @start_date)
                  .includes(:data_source)
    end

    def analyze_revenue_insights(revenue_data)
      insights = []

      # Revenue growth analysis
      current_revenue = calculate_period_revenue(revenue_data, @start_date, @end_date)
      previous_revenue = calculate_period_revenue(revenue_data, @start_date - @time_period, @start_date)

      if previous_revenue > 0
        growth_rate = ((current_revenue - previous_revenue) / previous_revenue * 100).round(1)

        if growth_rate.abs > 5
          insights << {
            type: "revenue_change",
            title: "Revenue #{growth_rate > 0 ? 'Growth' : 'Decline'} Detected",
            description: "Revenue #{growth_rate > 0 ? 'increased' : 'decreased'} by #{growth_rate.abs}% compared to previous period",
            value: growth_rate,
            impact_score: growth_rate.abs,
            category: "financial",
            trend: growth_rate > 0 ? "positive" : "negative"
          }
        end
      end

      insights
    end

    def analyze_customer_insights(customer_data)
      insights = []

      # Customer acquisition analysis
      new_customers = customer_data.where("raw_data_records.created_at >= ?", @start_date).count
      total_customers = customer_data.count

      if total_customers > 0
        acquisition_rate = (new_customers.to_f / total_customers * 100).round(1)

        insights << {
          type: "customer_acquisition",
          title: "Customer Acquisition Analysis",
          description: "Acquired #{new_customers} new customers (#{acquisition_rate}% of total base)",
          value: acquisition_rate,
          impact_score: acquisition_rate,
          category: "customer",
          trend: acquisition_rate > 10 ? "positive" : "neutral"
        }
      end

      insights
    end

    def analyze_product_insights(product_data)
      insights = []

      # Product performance analysis
      product_sales = analyze_product_performance(product_data)

      if product_sales.any?
        top_product = product_sales.first
        insights << {
          type: "top_product",
          title: "Top Performing Product",
          description: "#{top_product[:name]} generated #{top_product[:revenue_percentage]}% of total revenue",
          value: top_product[:revenue_percentage],
          impact_score: top_product[:revenue_percentage],
          category: "product",
          trend: "positive"
        }
      end

      insights
    end

    def analyze_operational_insights(operational_data)
      insights = []

      # Data processing insights
      total_jobs = operational_data.count
      successful_jobs = operational_data.completed.count

      if total_jobs > 0
        success_rate = (successful_jobs.to_f / total_jobs * 100).round(1)

        insights << {
          type: "processing_efficiency",
          title: "Data Processing Performance",
          description: "#{success_rate}% success rate across #{total_jobs} processing jobs",
          value: success_rate,
          impact_score: success_rate > 95 ? 8 : (success_rate > 90 ? 5 : 2),
          category: "operational",
          trend: success_rate > 95 ? "positive" : "neutral"
        }
      end

      insights
    end

    def build_narrative(insights)
      summary = insights[:executive_summary]
      key_insights = insights[:key_insights]
      anomalies = insights[:anomalies]
      recommendations = insights[:recommendations]

      narrative = []

      # Opening summary
      narrative << "## Executive Summary"
      narrative << ""
      narrative << generate_opening_narrative(summary)
      narrative << ""

      # Key insights section
      if key_insights.any?
        narrative << "## Key Insights"
        narrative << ""
        key_insights.first(5).each do |insight|
          narrative << "- **#{insight[:title]}**: #{insight[:description]}"
        end
        narrative << ""
      end

      # Anomalies section
      if anomalies.any?
        narrative << "## Areas Requiring Attention"
        narrative << ""
        anomalies.first(3).each do |anomaly|
          narrative << "- **#{anomaly[:title]}**: #{anomaly[:description]}"
        end
        narrative << ""
      end

      # Recommendations section
      if recommendations.any?
        narrative << "## Recommended Actions"
        narrative << ""
        recommendations.first(5).each_with_index do |rec, index|
          narrative << "#{index + 1}. **#{rec[:title]}**: #{rec[:description]}"
        end
        narrative << ""
      end

      narrative << "---"
      narrative << "*Report generated automatically by DataReflow AI on #{Time.current.strftime('%B %d, %Y at %I:%M %p')}*"

      narrative.join("\n")
    end

    def generate_opening_narrative(summary)
      "Based on analysis of your data over the past #{@time_period.inspect}, " \
      "the following trends and opportunities have been identified. " \
      "This report provides actionable insights to drive business growth and operational efficiency."
    end

    # Business metrics calculations based on actual data

    def calculate_total_revenue
      # Calculate revenue from order data in raw_data_records
      order_records = @organization.raw_data_records
                                   .where("data_type = ? OR source_table ILIKE ?", "order", "%order%")
                                   .where("created_at >= ?", 30.days.ago)

      total = 0
      order_records.find_each do |record|
        data = record.data.is_a?(String) ? JSON.parse(record.data) : record.data
        # Look for common revenue fields
        revenue_fields = %w[total_price total amount revenue value price]
        revenue_value = revenue_fields.find { |field| data[field] }
        total += data[revenue_value].to_f if revenue_value
      rescue JSON::ParserError
        next
      end

      total
    end

    def calculate_customer_count
      # Count unique customers from customer/order data
      customer_records = @organization.raw_data_records
                                      .where("data_type IN (?) OR source_table ILIKE ANY(array[?])",
                                             [ "customer", "order" ], [ "%customer%", "%order%" ])
                                      .where("created_at >= ?", 30.days.ago)

      unique_customers = Set.new
      customer_records.find_each do |record|
        data = record.data.is_a?(String) ? JSON.parse(record.data) : record.data
        # Look for customer identifier fields
        customer_fields = %w[customer_id user_id email customer_email]
        customer_id = customer_fields.find { |field| data[field] }
        unique_customers.add(data[customer_id]) if customer_id && data[customer_id]
      rescue JSON::ParserError
        next
      end

      unique_customers.size
    end

    def calculate_average_order_value
      # Calculate AOV from order data
      total_revenue = calculate_total_revenue
      order_count = @organization.raw_data_records
                                 .where("data_type = ? OR source_table ILIKE ?", "order", "%order%")
                                 .where("created_at >= ?", 30.days.ago)
                                 .count

      return 0 if order_count.zero?
      (total_revenue / order_count).round(2)
    end

    def calculate_conversion_rate
      # Calculate conversion from session/visitor data vs orders
      visitor_records = @organization.raw_data_records
                                     .where("data_type IN (?) OR source_table ILIKE ANY(array[?])",
                                            [ "session", "visitor", "pageview" ], [ "%session%", "%visitor%", "%pageview%" ])
                                     .where("created_at >= ?", 30.days.ago)
                                     .count

      order_count = @organization.raw_data_records
                                 .where("data_type = ? OR source_table ILIKE ?", "order", "%order%")
                                 .where("created_at >= ?", 30.days.ago)
                                 .count

      return 0 if visitor_records.zero?
       ((order_count.to_f / visitor_records) * 100).round(2)
    end

    def calculate_customer_acquisition_cost
      # Implementation would calculate CAC from marketing/customer data
      0
    end

    def calculate_lifetime_value
      # Implementation would calculate CLV from customer data
      0
    end

    def calculate_data_processing_volume
      @organization.raw_data_records.where("created_at >= ?", @start_date).count
    end

    def calculate_system_uptime
      total_jobs = @organization.extraction_jobs.where("extraction_jobs.created_at >= ?", @start_date)
      return 100 if total_jobs.empty?

      successful_jobs = total_jobs.completed.count
      (successful_jobs.to_f / total_jobs.count * 100).round(1)
    end

    def create_alert(type, message, severity)
      {
        type: type,
        message: message,
        severity: severity,
        timestamp: Time.current.iso8601,
        severity_score: severity == "critical" ? 10 : (severity == "warning" ? 5 : 1)
      }
    end

    # AI-enhanced helper methods

    def build_comprehensive_data_context
      {
        revenue_metrics: get_revenue_metrics,
        customer_metrics: get_customer_metrics,
        product_metrics: get_product_metrics,
        operational_metrics: get_operational_metrics,
        data_quality_metrics: get_data_quality_metrics,
        time_period: {
          start_date: @start_date.strftime("%Y-%m-%d"),
          end_date: @end_date.strftime("%Y-%m-%d"),
          duration_days: (@end_date - @start_date).to_i
        }
      }
    end

    def build_historical_context
      # Get historical data for comparison
      historical_start = @start_date - @time_period
      historical_end = @start_date

      {
        revenue_metrics: get_revenue_metrics_for_period(historical_start, historical_end),
        customer_metrics: get_customer_metrics_for_period(historical_start, historical_end),
        operational_metrics: get_operational_metrics_for_period(historical_start, historical_end),
        time_period: {
          start_date: historical_start.strftime("%Y-%m-%d"),
          end_date: historical_end.strftime("%Y-%m-%d"),
          duration_days: (historical_end - historical_start).to_i
        }
      }
    end

    def get_revenue_metrics
      revenue_data = get_revenue_data
      {
        total_revenue: calculate_total_revenue_from_data(revenue_data),
        order_count: revenue_data.count,
        average_order_value: calculate_average_order_value_from_data(revenue_data),
        revenue_growth: calculate_revenue_growth_rate(revenue_data)
      }
    end

    def get_customer_metrics
      customer_data = get_customer_data
      {
        total_customers: customer_data.count,
        new_customers: customer_data.where("created_at >= ?", @start_date).count,
        customer_retention_rate: calculate_customer_retention_rate(customer_data),
        customer_lifetime_value: calculate_customer_lifetime_value(customer_data)
      }
    end

    def get_product_metrics
      product_data = get_product_data
      {
        total_products: product_data.count,
        top_performing_products: get_top_performing_products(product_data),
        product_performance_trends: analyze_product_performance_trends(product_data)
      }
    end

    def get_operational_metrics
      operational_data = get_operational_data
      {
        total_jobs: operational_data.count,
        successful_jobs: operational_data.completed.count,
        failed_jobs: operational_data.failed.count,
        success_rate: calculate_job_success_rate(operational_data),
        average_processing_time: calculate_average_processing_time(operational_data)
      }
    end

    def get_data_quality_metrics
      {
        data_completeness: calculate_data_completeness,
        data_accuracy: calculate_data_accuracy,
        data_freshness: calculate_data_freshness,
        data_consistency: calculate_data_consistency
      }
    end

    # Period-specific metric methods for historical comparison

    def get_revenue_metrics_for_period(start_date, end_date)
      revenue_data = @organization.raw_data_records
                                  .joins(:data_source)
                                  .where("raw_data_records.created_at >= ? AND raw_data_records.created_at <= ?", start_date, end_date)
                                  .where("raw_data_records.record_type = ?", "order")

      {
        total_revenue: calculate_total_revenue_from_data(revenue_data),
        order_count: revenue_data.count,
        average_order_value: calculate_average_order_value_from_data(revenue_data)
      }
    end

    def get_customer_metrics_for_period(start_date, end_date)
      customer_data = @organization.raw_data_records
                                   .joins(:data_source)
                                   .where("raw_data_records.created_at >= ? AND raw_data_records.created_at <= ?", start_date, end_date)
                                   .where("raw_data_records.record_type = ?", "customer")

      {
        total_customers: customer_data.count,
        new_customers: customer_data.count # All are "new" in their period
      }
    end

    def get_operational_metrics_for_period(start_date, end_date)
      jobs_data = @organization.extraction_jobs
                               .where("created_at >= ? AND created_at <= ?", start_date, end_date)

      {
        total_jobs: jobs_data.count,
        successful_jobs: jobs_data.completed.count,
        failed_jobs: jobs_data.failed.count,
        success_rate: calculate_job_success_rate(jobs_data)
      }
    end

    # Calculation helper methods

    def calculate_total_revenue_from_data(revenue_data)
      revenue_data.sum do |record|
        normalized_data = record.data.dig("normalized_data")
        next 0 unless normalized_data
        (normalized_data["total_price"] || 0).to_f
      end
    end

    def calculate_average_order_value_from_data(revenue_data)
      return 0 if revenue_data.empty?
      total_revenue = calculate_total_revenue_from_data(revenue_data)
      total_revenue / revenue_data.count
    end

    def calculate_revenue_growth_rate(current_data)
      # Calculate growth compared to previous period
      previous_period_data = get_revenue_metrics_for_period(@start_date - @time_period, @start_date)
      current_revenue = calculate_total_revenue_from_data(current_data)
      previous_revenue = previous_period_data[:total_revenue]

      return 0 if previous_revenue.zero?
      ((current_revenue - previous_revenue) / previous_revenue * 100).round(2)
    end

    def calculate_customer_retention_rate(customer_data)
      # Calculate retention by comparing customers across periods
      current_period_customers = Set.new
      previous_period_customers = Set.new

      # Get customers from current period (last 30 days)
      current_records = @organization.raw_data_records
                                     .where("data_type IN (?) OR source_table ILIKE ANY(array[?])",
                                            [ "customer", "order" ], [ "%customer%", "%order%" ])
                                     .where("created_at >= ?", 30.days.ago)

      # Get customers from previous period (30-60 days ago)
      previous_records = @organization.raw_data_records
                                      .where("data_type IN (?) OR source_table ILIKE ANY(array[?])",
                                             [ "customer", "order" ], [ "%customer%", "%order%" ])
                                      .where("created_at >= ? AND created_at < ?", 60.days.ago, 30.days.ago)

      # Extract customer IDs from both periods
      [ current_records, previous_records ].each_with_index do |records, index|
        customer_set = index == 0 ? current_period_customers : previous_period_customers

        records.find_each do |record|
          data = record.data.is_a?(String) ? JSON.parse(record.data) : record.data
          customer_fields = %w[customer_id user_id email customer_email]
          customer_id = customer_fields.find { |field| data[field] }
          customer_set.add(data[customer_id]) if customer_id && data[customer_id]
        rescue JSON::ParserError
          next
        end
      end

      return 0 if previous_period_customers.empty?

      # Calculate retention rate
      retained_customers = current_period_customers & previous_period_customers
      ((retained_customers.size.to_f / previous_period_customers.size) * 100).round(2)
    end

    def calculate_customer_lifetime_value(customer_data)
      # Calculate CLV based on average order value and purchase frequency
      avg_order_value = calculate_average_order_value
      return 0 if avg_order_value.zero?

      # Calculate average purchase frequency (orders per customer per month)
      total_customers = calculate_customer_count
      return 0 if total_customers.zero?

      total_orders = @organization.raw_data_records
                                  .where("data_type = ? OR source_table ILIKE ?", "order", "%order%")
                                  .where("created_at >= ?", 30.days.ago)
                                  .count

      monthly_frequency = total_orders.to_f / total_customers

      # Estimate CLV (simplified: AOV * frequency * estimated lifetime in months)
      estimated_lifetime_months = 12 # Conservative estimate
      (avg_order_value * monthly_frequency * estimated_lifetime_months).round(2)
    end

    def get_top_performing_products(product_data)
      # Analyze product performance from order data
      product_sales = {}

      get_revenue_data.each do |order|
        normalized_data = order.data.dig("normalized_data")
        next unless normalized_data

        line_items = normalized_data["line_items"] || []
        line_items.each do |item|
          product_name = item["product_title"] || "Unknown Product"
          quantity = (item["quantity"] || 1).to_i
          price = (item["price"] || 0).to_f

          product_sales[product_name] ||= { quantity: 0, revenue: 0.0 }
          product_sales[product_name][:quantity] += quantity
          product_sales[product_name][:revenue] += (price * quantity)
        end
      end

      product_sales.sort_by { |_, data| -data[:revenue] }.first(5).to_h
    end

    def analyze_product_performance_trends(product_data)
      # Analyze trends in product performance
      # This would compare current vs previous period performance
      { trending_up: [], trending_down: [], stable: [] }
    end

    def calculate_job_success_rate(jobs_data)
      return 0 if jobs_data.empty?
      (jobs_data.completed.count.to_f / jobs_data.count * 100).round(2)
    end

    def calculate_average_processing_time(jobs_data)
      completed_jobs = jobs_data.completed.where.not(completed_at: nil)
      return 0 if completed_jobs.empty?

      total_time = completed_jobs.sum do |job|
        (job.completed_at - job.created_at).to_i
      end

      (total_time.to_f / completed_jobs.count / 60).round(2) # in minutes
    end

    def calculate_data_completeness
      # Calculate what percentage of expected data fields are populated
      sample_records = @organization.raw_data_records.limit(100)
      return 0 if sample_records.empty?

      total_fields = 0
      populated_fields = 0

      sample_records.each do |record|
        data = record.data || {}
        data.each do |key, value|
          total_fields += 1
          populated_fields += 1 if value.present?
        end
      end

      return 0 if total_fields.zero?
      (populated_fields.to_f / total_fields * 100).round(2)
    end

    def calculate_data_accuracy
      # Calculate data accuracy based on validation rules
      total_records = @organization.raw_data_records.count
      return 100 if total_records.zero?

      invalid_records = 0

      @organization.raw_data_records.find_each do |record|
        begin
          data = record.data.is_a?(String) ? JSON.parse(record.data) : record.data

          # Check for common data quality issues
          invalid_records += 1 if data_has_quality_issues?(data)
        rescue JSON::ParserError
          invalid_records += 1
        end
      end

      accuracy = ((total_records - invalid_records).to_f / total_records * 100).round(2)
      [ accuracy, 0 ].max # Ensure non-negative
    end

    def calculate_data_freshness
      # Calculate how recent the data is
      recent_records = @organization.raw_data_records
                                   .where("created_at >= ?", 24.hours.ago)
                                   .count
      total_records = @organization.raw_data_records.count

      return 0 if total_records.zero?
      (recent_records.to_f / total_records * 100).round(2)
    end

    def calculate_data_consistency
      # Calculate consistency across data sources
      data_sources = @organization.data_sources.active
      return 100 if data_sources.count <= 1

      consistency_scores = []

      # Compare schema consistency across similar data types
      data_types = @organization.raw_data_records.distinct.pluck(:data_type).compact

      data_types.each do |data_type|
        records_by_source = @organization.raw_data_records
                                         .where(data_type: data_type)
                                         .joins(:data_source)
                                         .group("data_sources.id")
                                         .limit(10)

        schemas = []
        records_by_source.each do |source_id, records|
          sample_record = records.first
          next unless sample_record

          begin
            data = sample_record.data.is_a?(String) ? JSON.parse(sample_record.data) : sample_record.data
            schemas << data.keys.sort
          rescue JSON::ParserError
            next
          end
        end

        # Calculate schema consistency for this data type
        if schemas.size > 1
          base_schema = schemas.first
          matching_schemas = schemas.count { |schema| schema == base_schema }
          consistency_scores << (matching_schemas.to_f / schemas.size * 100)
        end
      end

      return 100 if consistency_scores.empty?
      (consistency_scores.sum / consistency_scores.size).round(2)
    end

    # Helper method for data quality validation
    def data_has_quality_issues?(data)
      return true if data.nil? || data.empty?

      # Check for common data quality issues
      issues = [
        # Missing required fields for common data types
        data.is_a?(Hash) && data.values.any? { |v| v.nil? || (v.is_a?(String) && v.strip.empty?) },

        # Invalid email formats
        data.values.any? { |v| v.is_a?(String) && v.include?("@") && !v.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i) },

        # Invalid numeric values
        data.values.any? { |v| v.is_a?(String) && v.match?(/^\d+$/) && v.to_i < 0 && %w[price amount total revenue].any? { |field| data.keys.map(&:to_s).include?(field) } },

        # Duplicate or inconsistent data patterns
        data.is_a?(Hash) && data.keys.size != data.keys.uniq.size
      ]

      issues.any?
    end

    # Fallback methods for original functionality
    def detect_revenue_anomalies; []; end
    def detect_traffic_anomalies; []; end
    def detect_conversion_anomalies; []; end
    def detect_data_quality_anomalies; []; end
    def generate_insight_recommendations(insight); []; end
    def generate_anomaly_recommendations(anomaly); []; end
    def analyze_revenue_trends; {}; end
    def analyze_customer_trends; {}; end
    def analyze_product_trends; {}; end
    def analyze_seasonal_patterns; {}; end
    def analyze_growth_trajectory; {}; end
    def calculate_current_metrics; {}; end
    def calculate_previous_metrics; {}; end
    def calculate_period_revenue(data, start_date, end_date); 0; end
    def extract_key_highlights(metrics); []; end
    def identify_priority_actions(metrics); []; end
    def analyze_revenue_trend(metrics); {}; end
    def analyze_customer_growth(metrics); {}; end
    def analyze_operational_health(metrics); {}; end
    def analyze_product_performance(data); []; end
  end
end
