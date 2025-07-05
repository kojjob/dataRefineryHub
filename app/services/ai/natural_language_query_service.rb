# frozen_string_literal: true

module Ai
  class NaturalLanguageQueryService
    include ActiveModel::Model

    attr_accessor :organization, :user_query, :available_fields, :data_context

    # Supported query types and their patterns
    QUERY_PATTERNS = {
      customer_analysis: {
        keywords: %w[customers users clients buyers],
        patterns: [
          /customers?\s+who\s+(.+)/i,
          /show\s+me\s+customers?\s+(.+)/i,
          /find\s+customers?\s+(.+)/i,
          /which\s+customers?\s+(.+)/i
        ]
      },
      product_analysis: {
        keywords: %w[products items merchandise inventory],
        patterns: [
          /products?\s+that\s+(.+)/i,
          /show\s+me\s+products?\s+(.+)/i,
          /what\s+products?\s+(.+)/i,
          /which\s+products?\s+(.+)/i
        ]
      },
      revenue_analysis: {
        keywords: %w[revenue sales money profit income earnings],
        patterns: [
          /revenue\s+(.+)/i,
          /sales\s+(.+)/i,
          /how\s+much\s+(.+)/i,
          /total\s+(revenue|sales)\s+(.+)/i
        ]
      },
      order_analysis: {
        keywords: %w[orders purchases transactions],
        patterns: [
          /orders?\s+(.+)/i,
          /purchases?\s+(.+)/i,
          /transactions?\s+(.+)/i,
          /show\s+me\s+orders?\s+(.+)/i
        ]
      },
      trend_analysis: {
        keywords: %w[trending growing declining increasing decreasing],
        patterns: [
          /what\'?s\s+trending\s+(.+)/i,
          /trending\s+(.+)/i,
          /growing\s+(.+)/i,
          /increasing\s+(.+)/i,
          /declining\s+(.+)/i
        ]
      },
      comparison_analysis: {
        keywords: %w[compare comparison versus vs against],
        patterns: [
          /compare\s+(.+)\s+(vs|versus|against)\s+(.+)/i,
          /(.+)\s+(vs|versus|against)\s+(.+)/i
        ]
      }
    }.freeze

    TIME_PATTERNS = {
      "today" => { start: "Date.current.beginning_of_day", end: "Date.current.end_of_day" },
      "yesterday" => { start: "1.day.ago.beginning_of_day", end: "1.day.ago.end_of_day" },
      "this week" => { start: "Date.current.beginning_of_week", end: "Date.current.end_of_week" },
      "last week" => { start: "1.week.ago.beginning_of_week", end: "1.week.ago.end_of_week" },
      "this month" => { start: "Date.current.beginning_of_month", end: "Date.current.end_of_month" },
      "last month" => { start: "1.month.ago.beginning_of_month", end: "1.month.ago.end_of_month" },
      "this quarter" => { start: "Date.current.beginning_of_quarter", end: "Date.current.end_of_quarter" },
      "last quarter" => { start: "3.months.ago.beginning_of_quarter", end: "3.months.ago.end_of_quarter" },
      "this year" => { start: "Date.current.beginning_of_year", end: "Date.current.end_of_year" },
      "last year" => { start: "1.year.ago.beginning_of_year", end: "1.year.ago.end_of_year" }
    }.freeze

    def initialize(organization:, user_query:, data_context: nil)
      @organization = organization
      @user_query = user_query.to_s.strip
      @data_context = data_context || build_available_data_context
      @available_fields = extract_available_fields
      @llm_service = Ai::LlmService.new(organization: organization)
    end

    def process_query
      Rails.logger.info "Processing natural language query: #{@user_query}"

      # Step 1: Parse query intent and extract components
      query_analysis = analyze_query_intent

      # Step 2: Generate SQL/data query
      data_query = build_data_query(query_analysis)

      # Step 3: Execute query and get results
      results = execute_query(data_query)

      # Step 4: Generate natural language response
      response = generate_response(query_analysis, results)

      # Step 5: Create visualization suggestions
      visualizations = suggest_visualizations(query_analysis, results)

      {
        original_query: @user_query,
        query_analysis: query_analysis,
        data_query: data_query,
        results: results,
        response: response,
        visualizations: visualizations,
        confidence: calculate_confidence(query_analysis),
        processed_at: Time.current.iso8601
      }
    end

    def get_query_suggestions(partial_query = "")
      # Generate intelligent query suggestions based on available data
      base_suggestions = [
        "Show me customers who haven't ordered in 30 days",
        "What products are trending up this month?",
        "Compare revenue this month vs last month",
        "Which customers spent the most this quarter?",
        "What's my average order value this week?",
        "Show me orders over $500 this month",
        "Which products have the highest profit margins?",
        "How many new customers did we get last week?",
        "What's the customer lifetime value trend?",
        "Show me revenue by product category"
      ]

      if partial_query.present?
        # Filter suggestions based on partial input
        base_suggestions.select { |suggestion|
          suggestion.downcase.include?(partial_query.downcase)
        }.first(5)
      else
        # Return personalized suggestions based on organization's data
        generate_personalized_suggestions
      end
    end

    def validate_query(query)
      # Validate if query can be processed with available data
      analysis = analyze_query_intent(query)

      {
        can_process: analysis[:confidence] > 0.5,
        missing_data: identify_missing_data_requirements(analysis),
        suggestions: suggest_query_improvements(analysis),
        confidence: analysis[:confidence]
      }
    end

    private

    def analyze_query_intent
      # Use AI to analyze query intent
      ai_analysis = @llm_service.generate_natural_language_query(@user_query, @available_fields)

      # Combine AI analysis with pattern matching
      pattern_analysis = analyze_query_patterns
      time_analysis = extract_time_components

      # Merge analyses
      {
        intent: ai_analysis[:intent] || pattern_analysis[:type] || "general_query",
        query_type: pattern_analysis[:type],
        entities: extract_entities,
        time_range: time_analysis,
        filters: ai_analysis[:filters] || extract_filters_from_patterns,
        aggregations: ai_analysis[:aggregations] || determine_aggregations,
        fields_needed: ai_analysis[:fields] || pattern_analysis[:fields],
        confidence: calculate_analysis_confidence(ai_analysis, pattern_analysis)
      }
    end

    def analyze_query_patterns
      query_lower = @user_query.downcase

      QUERY_PATTERNS.each do |type, config|
        # Check if query contains keywords for this type
        if config[:keywords].any? { |keyword| query_lower.include?(keyword) }
          # Try to match specific patterns
          config[:patterns].each do |pattern|
            if match = query_lower.match(pattern)
              return {
                type: type,
                match: match,
                fields: get_fields_for_query_type(type),
                confidence: 0.8
              }
            end
          end

          return {
            type: type,
            match: nil,
            fields: get_fields_for_query_type(type),
            confidence: 0.6
          }
        end
      end

      { type: "general_query", confidence: 0.3 }
    end

    def extract_time_components
      query_lower = @user_query.downcase

      TIME_PATTERNS.each do |phrase, range|
        if query_lower.include?(phrase)
          return {
            phrase: phrase,
            start_date: range[:start],
            end_date: range[:end],
            detected: true
          }
        end
      end

      # Check for specific date patterns
      date_patterns = [
        /(\d{4}-\d{2}-\d{2})/,  # YYYY-MM-DD
        /(\d{1,2}\/\d{1,2}\/\d{4})/,  # MM/DD/YYYY
        /in\s+(\d+)\s+days?/i,
        /last\s+(\d+)\s+days?/i,
        /past\s+(\d+)\s+days?/i
      ]

      date_patterns.each do |pattern|
        if match = query_lower.match(pattern)
          return parse_date_match(match)
        end
      end

      # Default to last 30 days if no time specified
      {
        phrase: "default (last 30 days)",
        start_date: "30.days.ago",
        end_date: "Time.current",
        detected: false
      }
    end

    def extract_entities
      entities = {
        customers: extract_customer_entities,
        products: extract_product_entities,
        amounts: extract_amount_entities,
        categories: extract_category_entities
      }

      entities.compact
    end

    def extract_customer_entities
      # Extract customer-related entities dynamically based on organization data
      segments = get_dynamic_customer_segments
      query_lower = @user_query.downcase

      found_segments = segments.select { |segment| query_lower.include?(segment.downcase) }
      found_segments.any? ? found_segments : nil
    end

    def extract_product_entities
      # Extract product-related entities dynamically
      categories = get_dynamic_product_categories
      query_lower = @user_query.downcase

      found_categories = categories.select { |cat| query_lower.include?(cat.downcase) }
      found_categories.any? ? found_categories : nil
    end

    def extract_amount_entities
      # Extract monetary amounts and quantities
      amounts = []

      # Match currency amounts: $100, $1,000, etc.
      @user_query.scan(/\$[\d,]+(?:\.\d{2})?/) do |amount|
        amounts << { type: "currency", value: amount }
      end

      # Match quantities: 10 items, 50 orders, etc.
      @user_query.scan(/(\d+)\s+(items?|orders?|customers?|products?)/) do |quantity, unit|
        amounts << { type: "quantity", value: quantity.to_i, unit: unit }
      end

      amounts.any? ? amounts : nil
    end

    def extract_category_entities
      # Extract category-related information
      # This would be enhanced with actual product categories from the database
      []
    end

    def build_data_query(analysis)
      case analysis[:query_type]
      when :customer_analysis
        build_customer_query(analysis)
      when :product_analysis
        build_product_query(analysis)
      when :revenue_analysis
        build_revenue_query(analysis)
      when :order_analysis
        build_order_query(analysis)
      when :trend_analysis
        build_trend_query(analysis)
      when :comparison_analysis
        build_comparison_query(analysis)
      else
        build_general_query(analysis)
      end
    end

    def build_customer_query(analysis)
      base_query = @organization.raw_data_records
                               .joins(:data_source)
                               .where("raw_data_records.record_type = ?", "customer")

      # Apply time filters
      if analysis[:time_range][:detected]
        start_date = parse_date_safely(analysis[:time_range][:start_date])
        end_date = parse_date_safely(analysis[:time_range][:end_date])
        base_query = base_query.where("raw_data_records.created_at": start_date..end_date)
      end

      # Apply specific filters based on query
      if @user_query.downcase.include?("haven't ordered")
        # Find customers who haven't placed orders recently
        days = extract_number_from_query || 30
        {
          type: "customer_without_orders",
          query: base_query,
          additional_logic: "customers_without_orders_in_#{days}_days",
          days: days
        }
      elsif @user_query.downcase.include?("spent the most")
        {
          type: "top_spending_customers",
          query: base_query,
          order: "total_spent DESC",
          limit: 10
        }
      else
        {
          type: "general_customer_query",
          query: base_query
        }
      end
    end

    def build_product_query(analysis)
      base_query = @organization.raw_data_records
                               .joins(:data_source)
                               .where("raw_data_records.record_type = ?", "product")

      if @user_query.downcase.include?("trending")
        {
          type: "trending_products",
          query: base_query,
          additional_logic: "calculate_product_trends",
          time_range: analysis[:time_range]
        }
      else
        {
          type: "general_product_query",
          query: base_query
        }
      end
    end

    def build_revenue_query(analysis)
      base_query = @organization.raw_data_records
                               .joins(:data_source)
                               .where("raw_data_records.record_type = ?", "order")

      # Apply time filters
      if analysis[:time_range][:detected]
        start_date = parse_date_safely(analysis[:time_range][:start_date])
        end_date = parse_date_safely(analysis[:time_range][:end_date])
        base_query = base_query.where("raw_data_records.created_at": start_date..end_date)
      end

      {
        type: "revenue_calculation",
        query: base_query,
        aggregation: "sum_total_price",
        time_range: analysis[:time_range]
      }
    end

    def build_order_query(analysis)
      base_query = @organization.raw_data_records
                               .joins(:data_source)
                               .where("raw_data_records.record_type = ?", "order")

      # Apply amount filters if specified
      if amount_entities = analysis[:entities][:amounts]
        amount_entities.each do |amount|
          if amount[:type] == "currency"
            value = amount[:value].gsub(/[$,]/, "").to_f
            if @user_query.downcase.include?("over")
              base_query = base_query.where("(raw_data_records.raw_data->>'total_price')::float > ?", value)
            elsif @user_query.downcase.include?("under")
              base_query = base_query.where("(raw_data_records.raw_data->>'total_price')::float < ?", value)
            end
          end
        end
      end

      # Apply time filters
      if analysis[:time_range][:detected]
        start_date = parse_date_safely(analysis[:time_range][:start_date])
        end_date = parse_date_safely(analysis[:time_range][:end_date])
        base_query = base_query.where("raw_data_records.created_at": start_date..end_date)
      end

      {
        type: "order_analysis",
        query: base_query,
        time_range: analysis[:time_range]
      }
    end

    def build_trend_query(analysis)
      # For trend analysis, we need to compare data over time periods
      {
        type: "trend_analysis",
        base_entity: determine_trend_entity,
        time_periods: generate_time_periods_for_trend,
        comparison_logic: "calculate_period_over_period_change"
      }
    end

    def build_comparison_query(analysis)
      # Extract what's being compared
      comparison_entities = extract_comparison_entities

      {
        type: "comparison_analysis",
        entities: comparison_entities,
        comparison_logic: "side_by_side_comparison"
      }
    end

    def build_general_query(analysis)
      # Fallback for queries that don't match specific patterns
      {
        type: "general_query",
        suggested_refinements: generate_query_refinement_suggestions,
        available_data: @data_context
      }
    end

    def execute_query(data_query)
      case data_query[:type]
      when "customer_without_orders"
        execute_customer_without_orders_query(data_query)
      when "top_spending_customers"
        execute_top_spending_customers_query(data_query)
      when "trending_products"
        execute_trending_products_query(data_query)
      when "revenue_calculation"
        execute_revenue_calculation_query(data_query)
      when "order_analysis"
        execute_order_analysis_query(data_query)
      when "trend_analysis"
        execute_trend_analysis_query(data_query)
      when "comparison_analysis"
        execute_comparison_analysis_query(data_query)
      else
        execute_general_query(data_query)
      end
    rescue => e
      Rails.logger.error "Query execution failed: #{e.message}"
      {
        error: true,
        message: "Unable to execute query: #{e.message}",
        suggestion: "Try rephrasing your question or check if the requested data is available."
      }
    end

    def execute_customer_without_orders_query(data_query)
      days = data_query[:days] || 30
      cutoff_date = days.days.ago

      # Get all customers
      all_customers = data_query[:query].limit(1000)

      # Get customers who have placed orders recently
      recent_order_customers = @organization.raw_data_records
                                           .joins(:data_source)
                                           .where("raw_data_records.record_type = ?", "order")
                                           .where("created_at >= ?", cutoff_date)
                                           .pluck("raw_data_records.raw_data->>'customer_external_id'")
                                           .compact
                                           .uniq

      # Filter customers who haven't ordered
      inactive_customers = all_customers.reject do |customer|
        customer_id = customer.data.dig("normalized_data", "external_id") || customer.data["customer_id"]
        recent_order_customers.include?(customer_id.to_s)
      end

      {
        count: inactive_customers.count,
        customers: inactive_customers.first(20).map { |c| format_customer_result(c) },
        total_customers_checked: all_customers.count,
        period: "#{days} days",
        has_more: inactive_customers.count > 20
      }
    end

    def execute_top_spending_customers_query(data_query)
      # Calculate customer spending from orders
      customer_spending = {}

      orders = @organization.raw_data_records
                           .joins(:data_source)
                           .where("raw_data_records.data @> ?", { record_type: "order" }.to_json)

      orders.each do |order|
        customer_id = order.data.dig("normalized_data", "customer_external_id")
        next unless customer_id

        amount = order.data.dig("normalized_data", "total_price").to_f
        customer_spending[customer_id] ||= 0
        customer_spending[customer_id] += amount
      end

      # Sort by spending and get top customers
      top_spenders = customer_spending.sort_by { |_, amount| -amount }.first(10)

      {
        count: top_spenders.count,
        customers: top_spenders.map do |customer_id, total_spent|
          {
            customer_id: customer_id,
            total_spent: total_spent,
            formatted_amount: "$#{total_spent.round(2)}"
          }
        end,
        total_revenue_from_top_customers: top_spenders.sum { |_, amount| amount }
      }
    end

    def execute_trending_products_query(data_query)
      # Calculate product trends by comparing current vs previous period
      current_period_sales = calculate_product_sales_for_period(30.days.ago, Time.current)
      previous_period_sales = calculate_product_sales_for_period(60.days.ago, 30.days.ago)

      trends = calculate_product_trends(current_period_sales, previous_period_sales)

      {
        trending_up: trends[:up].first(10),
        trending_down: trends[:down].first(10),
        stable: trends[:stable].first(5),
        analysis_period: "Last 30 days vs previous 30 days"
      }
    end

    def execute_revenue_calculation_query(data_query)
      orders = data_query[:query]

      total_revenue = orders.sum do |order|
        order.data.dig("normalized_data", "total_price").to_f
      end

      {
        total_revenue: total_revenue,
        formatted_revenue: "$#{total_revenue.round(2)}",
        order_count: orders.count,
        average_order_value: orders.count > 0 ? total_revenue / orders.count : 0,
        time_period: data_query[:time_range][:phrase]
      }
    end

    def execute_order_analysis_query(data_query)
      orders = data_query[:query].limit(1000)

      {
        total_orders: orders.count,
        orders: orders.first(20).map { |o| format_order_result(o) },
        summary: {
          total_value: orders.sum { |o| o.data.dig("normalized_data", "total_price").to_f },
          average_value: calculate_average_order_value(orders),
          date_range: data_query[:time_range][:phrase]
        },
        has_more: orders.count > 20
      }
    end

    def execute_trend_analysis_query(data_query)
      # Implement trend analysis logic
      { message: "Trend analysis coming soon", type: "trend_analysis" }
    end

    def execute_comparison_analysis_query(data_query)
      # Implement comparison logic
      { message: "Comparison analysis coming soon", type: "comparison_analysis" }
    end

    def execute_general_query(data_query)
      {
        message: "I understand you're looking for business insights, but I need more specific information.",
        suggestions: data_query[:suggested_refinements] || get_query_suggestions,
        available_data_types: %w[customers orders products revenue]
      }
    end

    def generate_response(analysis, results)
      return "I couldn't process your query. Please try rephrasing it." if results[:error]

      case analysis[:query_type]
      when :customer_analysis
        generate_customer_analysis_response(results)
      when :revenue_analysis
        generate_revenue_analysis_response(results)
      when :order_analysis
        generate_order_analysis_response(results)
      else
        generate_general_response(results)
      end
    end

    def generate_customer_analysis_response(results)
      if results[:count]
        "I found #{results[:count]} customers matching your criteria. " \
        "#{results[:has_more] ? 'Showing the first 20 results.' : ''}"
      else
        "Here are the customer insights you requested."
      end
    end

    def generate_revenue_analysis_response(results)
      if results[:total_revenue]
        "Your total revenue for #{results[:time_period]} was #{results[:formatted_revenue]} " \
        "across #{results[:order_count]} orders, with an average order value of $#{results[:average_order_value].round(2)}."
      else
        "Here's your revenue analysis."
      end
    end

    def generate_order_analysis_response(results)
      if results[:total_orders]
        "I found #{results[:total_orders]} orders for the specified period. " \
        "Total value: $#{results[:summary][:total_value].round(2)}, " \
        "Average: $#{results[:summary][:average_value].round(2)}."
      else
        "Here's your order analysis."
      end
    end

    def generate_general_response(results)
      results[:message] || "Here are your results."
    end

    def suggest_visualizations(analysis, results)
      suggestions = []

      case analysis[:query_type]
      when :customer_analysis
        suggestions << { type: "bar_chart", title: "Customer Analysis", description: "Customer segments breakdown" }
      when :revenue_analysis
        suggestions << { type: "line_chart", title: "Revenue Trend", description: "Revenue over time" }
        suggestions << { type: "pie_chart", title: "Revenue Sources", description: "Revenue by source" }
      when :order_analysis
        suggestions << { type: "bar_chart", title: "Order Volume", description: "Orders over time" }
        suggestions << { type: "histogram", title: "Order Values", description: "Distribution of order values" }
      when :trend_analysis
        suggestions << { type: "line_chart", title: "Trend Analysis", description: "Trend over time periods" }
      end

      suggestions
    end

    # Helper methods

    def build_available_data_context
      {
        customers: @organization.raw_data_records.where("data @> ?", { record_type: "customer" }.to_json).count,
        orders: @organization.raw_data_records.where("data @> ?", { record_type: "order" }.to_json).count,
        products: @organization.raw_data_records.where("data @> ?", { record_type: "product" }.to_json).count,
        data_sources: @organization.data_sources.count,
        date_range: {
          earliest: @organization.raw_data_records.minimum(:created_at),
          latest: @organization.raw_data_records.maximum(:created_at)
        }
      }
    end

    def extract_available_fields
      # Extract available fields from the data
      sample_records = @organization.raw_data_records.limit(10)
      fields = Set.new

      sample_records.each do |record|
        extract_fields_from_record(record.data, fields)
      end

      fields.to_a
    end

    def extract_fields_from_record(data, fields, prefix = "")
      return unless data.is_a?(Hash)

      data.each do |key, value|
        field_name = prefix.present? ? "#{prefix}.#{key}" : key
        fields << field_name

        if value.is_a?(Hash)
          extract_fields_from_record(value, fields, field_name)
        end
      end
    end

    def get_fields_for_query_type(type)
      case type
      when :customer_analysis
        %w[customer_id customer_name email total_spent orders_count last_order_date]
      when :product_analysis
        %w[product_id product_name category price inventory_quantity]
      when :revenue_analysis
        %w[total_price order_date customer_id product_revenue]
      when :order_analysis
        %w[order_id order_date total_price customer_id status]
      else
        []
      end
    end

    def extract_number_from_query
      matches = @user_query.scan(/\d+/)
      matches.first&.to_i
    end

    def calculate_confidence(analysis)
      base_confidence = analysis[:confidence] || 0.5

      # Adjust based on available data
      if @data_context[:customers] > 0 && @data_context[:orders] > 0
        base_confidence += 0.2
      end

      # Adjust based on query specificity
      if analysis[:time_range][:detected]
        base_confidence += 0.1
      end

      [ base_confidence, 1.0 ].min
    end

    def calculate_analysis_confidence(ai_analysis, pattern_analysis)
      ai_conf = ai_analysis[:confidence] == "high" ? 0.9 : (ai_analysis[:confidence] == "medium" ? 0.7 : 0.5)
      pattern_conf = pattern_analysis[:confidence] || 0.5

      # Weighted average favoring AI analysis if available
      if ai_analysis[:intent].present?
        (ai_conf * 0.7) + (pattern_conf * 0.3)
      else
        pattern_conf
      end
    end

    def format_customer_result(customer)
      normalized = customer.data["normalized_data"] || customer.data
      {
        id: normalized["external_id"] || normalized["customer_id"],
        name: "#{normalized['first_name']} #{normalized['last_name']}".strip,
        email: normalized["email"],
        last_order: normalized["last_order_at"],
        total_spent: normalized["total_spent"]
      }
    end

    def format_order_result(order)
      normalized = order.data["normalized_data"] || order.data
      {
        id: normalized["external_id"] || normalized["order_id"],
        date: normalized["created_at"],
        total: normalized["total_price"],
        customer_id: normalized["customer_external_id"],
        status: normalized["status"]
      }
    end

    def calculate_average_order_value(orders)
      return 0 if orders.empty?
      total = orders.sum { |o| o.data.dig("normalized_data", "total_price").to_f }
      total / orders.count
    end

    # Placeholder methods for complex calculations

    def generate_personalized_suggestions
      suggestions = []

      if @data_context[:customers] > 0
        suggestions << "Show me my top 10 customers by total spending"
        suggestions << "Which customers haven't ordered in the last 60 days?"
      end

      if @data_context[:orders] > 0
        suggestions << "What's my revenue this month compared to last month?"
        threshold = calculate_dynamic_order_threshold
        suggestions << "Show me orders over $#{threshold} this quarter"
      end

      if @data_context[:products] > 0
        suggestions << "Which products are my best sellers this month?"
        suggestions << "What products are trending up this week?"
      end

      suggestions.any? ? suggestions.first(5) : [ "No specific suggestions available" ]
    end

    def identify_missing_data_requirements(analysis); []; end
    def suggest_query_improvements(analysis); []; end
    def parse_date_match(match); {}; end
    def extract_filters_from_patterns; []; end
    def determine_aggregations; []; end
    def determine_trend_entity; "revenue"; end
    def generate_time_periods_for_trend; []; end
    def extract_comparison_entities; []; end
    def generate_query_refinement_suggestions; []; end
    def calculate_product_sales_for_period(start_date, end_date); {}; end
    def calculate_product_trends(current, previous); { up: [], down: [], stable: [] }; end

    # Dynamic data helper methods
    def get_dynamic_customer_segments
      # Generate customer segments based on organization's actual data patterns
      base_segments = %w[new returning]

      # Add segments based on organization characteristics
      if @organization.data_sources.count > 2
        base_segments += %w[vip premium high_value]
      end

      if @data_context[:customers] > 100
        base_segments += %w[inactive at_risk]
      end

      base_segments
    end

    def get_dynamic_product_categories
      # Generate product categories based on organization's business type
      base_categories = %w[products services]

      # Add categories based on data sources
      shopify_connected = @organization.data_sources.any? { |ds| ds.source_type == "shopify" }
      if shopify_connected
        base_categories += %w[electronics clothing accessories home]
      end

      # Add generic business categories
      base_categories += %w[featured bestsellers new_arrivals]

      base_categories.uniq
    end

    def calculate_dynamic_order_threshold
      # Calculate a realistic order threshold based on organization data
      if @data_context[:orders] > 0
        # Try to estimate from actual order data if available
        sample_orders = @organization.raw_data_records
          .where("data @> ?", { record_type: "order" }.to_json)
          .limit(10)

        if sample_orders.any?
          avg_order = sample_orders.map { |o| o.data.dig("normalized_data", "total_price").to_f }.compact.sum / sample_orders.count
          # Set threshold at roughly 2x average order value
          (avg_order * 2).round(-1) # Round to nearest 10
        else
          # Fallback based on organization characteristics
          calculate_fallback_order_threshold
        end
      else
        calculate_fallback_order_threshold
      end
    end

    def calculate_fallback_order_threshold
      # Calculate threshold based on organization context
      base_threshold = 100

      # Adjust based on data source types
      if @organization.data_sources.any? { |ds| %w[shopify stripe].include?(ds.source_type) }
        # E-commerce businesses might have higher order values
        base_threshold = 250
      end

      # Adjust based on organization age/maturity
      if @organization.created_at < 6.months.ago
        # More mature organizations might have higher thresholds
        base_threshold = (base_threshold * 1.5).round(-1)
      end

      base_threshold
    end

    def parse_date_safely(date_string)
      return nil if date_string.blank?

      # Handle common date expressions safely
      case date_string.downcase
      when /^(\d+)\.days?\.ago$/
        $1.to_i.days.ago
      when /^(\d+)\.weeks?\.ago$/
        $1.to_i.weeks.ago
      when /^(\d+)\.months?\.ago$/
        $1.to_i.months.ago
      when /^(\d+)\.years?\.ago$/
        $1.to_i.years.ago
      when "time.current", "time.now", "date.current", "date.today"
        Time.current
      when "beginning_of_month"
        Time.current.beginning_of_month
      when "end_of_month"
        Time.current.end_of_month
      when "beginning_of_year"
        Time.current.beginning_of_year
      when "end_of_year"
        Time.current.end_of_year
      else
        # Try to parse as a date string
        begin
          Time.zone.parse(date_string)
        rescue ArgumentError
          # Default to current time if parsing fails
          Rails.logger.warn "Failed to parse date: #{date_string}"
          Time.current
        end
      end
    end
  end
end
