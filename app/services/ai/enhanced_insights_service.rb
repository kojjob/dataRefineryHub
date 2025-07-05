# frozen_string_literal: true

module Ai
  class EnhancedInsightsService
    include ActiveModel::Model

    attr_accessor :organization, :time_period, :data_context

    def initialize(organization:, time_period: 7.days, data_context: nil)
      @organization = organization
      @time_period = time_period
      @data_context = data_context || build_data_context
      @chat = initialize_llm_chat
    end

    def generate_comprehensive_insights
      {
        executive_summary: generate_ai_executive_summary,
        key_insights: generate_ai_insights,
        anomaly_detection: perform_ai_anomaly_detection,
        predictive_analysis: generate_ai_predictions,
        recommendations: generate_ai_recommendations,
        narrative_report: generate_narrative_report,
        generated_at: Time.current.iso8601,
        ai_confidence_score: calculate_confidence_score
      }
    end

    def analyze_data_with_ai(query, data_subset = nil)
      context_data = data_subset || @data_context

      prompt = build_analysis_prompt(query, context_data)

      begin
        response = @chat.ask(prompt)

        {
          success: true,
          analysis: response,
          query: query,
          data_points_analyzed: context_data.keys.count,
          generated_at: Time.current.iso8601
        }
      rescue => e
        Rails.logger.error "AI analysis failed: #{e.message}"
        {
          success: false,
          error: e.message,
          fallback_analysis: generate_fallback_analysis(query, context_data)
        }
      end
    end

    def generate_presentation_content(template_type, focus_areas = [])
      slides_data = []

      # Title slide with AI-generated summary
      title_response = @chat.ask(build_title_prompt(template_type))
      slides_data << parse_title_slide(title_response)

      # Executive summary with AI insights
      summary_response = @chat.ask(build_summary_prompt)
      slides_data << parse_summary_slide(summary_response)

      # Key insights slides
      insights_response = @chat.ask(build_insights_prompt(focus_areas))
      slides_data.concat(parse_insights_slides(insights_response))

      # Recommendations slide
      recommendations_response = @chat.ask(build_recommendations_prompt)
      slides_data << parse_recommendations_slide(recommendations_response)

      {
        slides: slides_data,
        metadata: {
          template_type: template_type,
          focus_areas: focus_areas,
          ai_generated: true,
          confidence_score: calculate_confidence_score,
          data_period: {
            start: @time_period.ago.strftime("%Y-%m-%d"),
            end: Date.current.strftime("%Y-%m-%d")
          }
        }
      }
    end

    def perform_intelligent_data_validation(data_sample)
      validation_prompt = build_validation_prompt(data_sample)

      response = @chat.ask(validation_prompt)

      parse_validation_response(response)
    end

    def generate_smart_alerts
      alerts_prompt = build_alerts_prompt(@data_context)

      response = @chat.ask(alerts_prompt)

      parse_alerts_response(response)
    end

    private

    def initialize_llm_chat
      # This would integrate with ruby_llm when added to Gemfile
      # For now, we'll create a mock interface that matches ruby_llm patterns
      MockLLMChat.new
    end

    def build_data_context
      {
        revenue_metrics: calculate_revenue_metrics,
        customer_metrics: calculate_customer_metrics,
        product_metrics: calculate_product_metrics,
        operational_metrics: calculate_operational_metrics,
        data_quality_metrics: calculate_data_quality_metrics,
        time_period: {
          start_date: @time_period.ago.strftime("%Y-%m-%d"),
          end_date: Date.current.strftime("%Y-%m-%d"),
          days: @time_period.to_i / 1.day.to_i
        }
      }
    end

    def generate_ai_executive_summary
      prompt = <<~PROMPT
        You are a business intelligence expert analyzing data for #{@organization.name}.

        Based on the following business metrics from the past #{@time_period.inspect}:
        #{format_context_for_ai(@data_context)}

        Generate a comprehensive executive summary that includes:
        1. Overall business performance assessment
        2. Key achievements and wins
        3. Areas of concern or opportunity
        4. Strategic implications

        Focus on actionable insights and avoid generic statements.
        Format as JSON with the following structure:
        {
          "performance_assessment": "...",
          "key_achievements": [...],
          "areas_of_concern": [...],
          "strategic_implications": "...",
          "confidence_level": "high|medium|low"
        }
      PROMPT

      response = @chat.ask(prompt)
      parse_json_response(response, fallback_executive_summary)
    end

    def generate_ai_insights
      prompt = <<~PROMPT
        Analyze the following business data for #{@organization.name} and identify the top 5 most significant insights:

        #{format_context_for_ai(@data_context)}

        For each insight, provide:
        1. A clear, specific title
        2. Detailed description with supporting data
        3. Impact score (1-10)
        4. Recommended action
        5. Priority level (high/medium/low)

        Focus on insights that are:
        - Actionable and specific
        - Backed by actual data trends
        - Relevant to business growth
        - Not obvious or generic

        Format as JSON array.
      PROMPT

      response = @chat.ask(prompt)
      parse_json_response(response, fallback_insights)
    end

    def perform_ai_anomaly_detection
      prompt = <<~PROMPT
        You are a data scientist specializing in anomaly detection. Analyze this business data for #{@organization.name}:

        #{format_context_for_ai(@data_context)}

        Identify any anomalies, outliers, or unusual patterns that require attention. For each anomaly:
        1. Describe what's abnormal
        2. Potential causes
        3. Business impact
        4. Urgency level
        5. Recommended investigation steps

        Only flag genuine anomalies that warrant business attention.
        Format as JSON array.
      PROMPT

      response = @chat.ask(prompt)
      parse_json_response(response, [])
    end

    def generate_ai_predictions
      prompt = <<~PROMPT
        Based on the historical data trends for #{@organization.name}:

        #{format_context_for_ai(@data_context)}

        Generate predictions for the next 30 days including:
        1. Revenue forecast with confidence interval
        2. Customer growth projections
        3. Potential risks and opportunities
        4. Key metrics to monitor

        Base predictions on observable trends and patterns in the data.
        Format as JSON with clear prediction values and confidence levels.
      PROMPT

      response = @chat.ask(prompt)
      parse_json_response(response, fallback_predictions)
    end

    def generate_ai_recommendations
      prompt = <<~PROMPT
        As a business strategy consultant, provide specific, actionable recommendations for #{@organization.name} based on:

        #{format_context_for_ai(@data_context)}

        Generate 5-7 recommendations that are:
        1. Specific and actionable
        2. Based on the actual data patterns
        3. Prioritized by potential impact
        4. Include estimated timeline and resources needed
        5. Measurable outcomes defined

        Format as JSON array with detailed implementation guidance.
      PROMPT

      response = @chat.ask(prompt)
      parse_json_response(response, fallback_recommendations)
    end

    def generate_narrative_report
      prompt = <<~PROMPT
        Write a comprehensive business intelligence narrative report for #{@organization.name} based on the data analysis.

        Data Context:
        #{format_context_for_ai(@data_context)}

        The report should be professional, data-driven, and tell a compelling story about the business performance.
        Include sections for:
        1. Executive Summary (2-3 paragraphs)
        2. Key Performance Highlights
        3. Areas for Improvement
        4. Strategic Recommendations
        5. Next Steps

        Write in a clear, executive-friendly tone. Use specific numbers and percentages where available.
        Format as markdown for easy rendering.
      PROMPT

      response = @chat.ask(prompt)
      response || generate_fallback_narrative
    end

    # Helper methods for prompt building

    def build_analysis_prompt(query, data)
      <<~PROMPT
        You are analyzing business data for #{@organization.name}.

        User Query: #{query}

        Available Data:
        #{format_context_for_ai(data)}

        Provide a comprehensive analysis that directly answers the user's question.
        Include specific data points, trends, and actionable insights.
        If the data is insufficient to answer fully, explain what's available and what additional data might be needed.
      PROMPT
    end

    def build_title_prompt(template_type)
      <<~PROMPT
        Generate an appropriate title and subtitle for a #{template_type.humanize} presentation for #{@organization.name}.

        Business Context:
        #{format_context_for_ai(@data_context)}

        The title should be:
        1. Professional and engaging
        2. Specific to the current time period
        3. Reflective of the key business themes

        Format as JSON: {"title": "...", "subtitle": "...", "date_range": "..."}
      PROMPT
    end

    def build_summary_prompt
      <<~PROMPT
        Create an executive summary slide content for #{@organization.name} based on:

        #{format_context_for_ai(@data_context)}

        Include:
        1. 3-4 key performance highlights
        2. Main business theme/story
        3. Critical metrics worth highlighting

        Format as JSON with structured content for presentation slides.
      PROMPT
    end

    def build_insights_prompt(focus_areas)
      focus_text = focus_areas.any? ? "Focus particularly on: #{focus_areas.join(', ')}" : ""

      <<~PROMPT
        Generate key business insights for presentation slides based on:

        #{format_context_for_ai(@data_context)}

        #{focus_text}

        Create 3-5 insight slides, each with:
        1. Compelling headline
        2. Supporting data/evidence
        3. Visual suggestion (chart type)
        4. Key takeaway

        Format as JSON array of slide objects.
      PROMPT
    end

    def build_recommendations_prompt
      <<~PROMPT
        Based on the business analysis for #{@organization.name}:

        #{format_context_for_ai(@data_context)}

        Generate strategic recommendations for a presentation slide including:
        1. Top 3-5 priority actions
        2. Expected impact for each
        3. Implementation timeline
        4. Success metrics

        Format as JSON with structured recommendation data.
      PROMPT
    end

    def build_validation_prompt(data_sample)
      <<~PROMPT
        Analyze this data sample for quality issues, anomalies, and validation concerns:

        #{data_sample.inspect}

        Identify:
        1. Data quality issues
        2. Missing or inconsistent values
        3. Format problems
        4. Logical inconsistencies
        5. Suggested corrections

        Format as JSON with specific validation results.
      PROMPT
    end

    def build_alerts_prompt(context)
      <<~PROMPT
        Based on the current business metrics for #{@organization.name}:

        #{format_context_for_ai(context)}

        Generate smart alerts for metrics that require immediate attention.
        Only create alerts for genuinely concerning trends or values.

        For each alert include:
        1. Alert type and severity
        2. Specific metric and current value
        3. Why it's concerning
        4. Recommended action

        Format as JSON array of alert objects.
      PROMPT
    end

    # Utility methods

    def format_context_for_ai(context)
      # Format the data context in a way that's easy for AI to understand
      formatted = []

      context.each do |category, data|
        formatted << "#{category.to_s.humanize}:"

        case data
        when Hash
          data.each { |key, value| formatted << "  #{key.to_s.humanize}: #{value}" }
        when Array
          data.each_with_index { |item, index| formatted << "  #{index + 1}. #{item}" }
        else
          formatted << "  #{data}"
        end

        formatted << ""
      end

      formatted.join("\n")
    end

    def parse_json_response(response, fallback = {})
      return fallback unless response

      # Try to extract JSON from the response
      json_match = response.match(/\{.*\}/m) || response.match(/\[.*\]/m)
      return fallback unless json_match

      JSON.parse(json_match[0])
    rescue JSON::ParserError
      fallback
    end

    def calculate_confidence_score
      # Calculate confidence based on data availability and quality
      data_points = @data_context.values.flatten.compact.count

      case data_points
      when 0..10 then 0.3
      when 11..50 then 0.6
      when 51..100 then 0.8
      else 0.9
      end
    end

    # Data calculation methods (simplified implementations)

    def calculate_revenue_metrics
      orders = @organization.raw_data_records
                           .joins(:data_source)
                           .where("raw_data_records.created_at >= ?", @time_period.ago)
                           .where("raw_data_records.record_type = ?", "order")

      {
        total_revenue: calculate_total_revenue_from_orders(orders),
        order_count: orders.count,
        average_order_value: calculate_average_order_value_from_orders(orders)
      }
    end

    def calculate_customer_metrics
      customers = @organization.raw_data_records
                              .joins(:data_source)
                              .where("raw_data_records.created_at >= ?", @time_period.ago)
                              .where("raw_data_records.record_type = ?", "customer")

      {
        total_customers: customers.count,
        new_customers: customers.where("raw_data_records.created_at >= ?", @time_period.ago).count,
        customer_growth_rate: calculate_customer_growth_rate(customers)
      }
    end

    def calculate_product_metrics
      products = @organization.raw_data_records
                             .joins(:data_source)
                             .where("raw_data_records.created_at >= ?", @time_period.ago)
                             .where("raw_data_records.record_type = ?", "product")

      {
        total_products: products.count,
        top_selling_products: calculate_top_products(products)
      }
    end

    def calculate_operational_metrics
      jobs = @organization.extraction_jobs.where("extraction_jobs.created_at >= ?", @time_period.ago)

      {
        total_jobs: jobs.count,
        successful_jobs: jobs.completed.count,
        failed_jobs: jobs.failed.count,
        success_rate: jobs.count > 0 ? (jobs.completed.count.to_f / jobs.count * 100).round(1) : 0
      }
    end

    def calculate_data_quality_metrics
      records = @organization.raw_data_records.where("created_at >= ?", @time_period.ago)

      {
        total_records: records.count,
        data_sources_active: @organization.data_sources.connected.count,
        avg_processing_time: calculate_average_processing_time
      }
    end

    # Fallback methods for when AI is unavailable

    def fallback_executive_summary
      {
        "performance_assessment" => "Business metrics are being analyzed",
        "key_achievements" => [ "Data processing maintained", "System stability preserved" ],
        "areas_of_concern" => [ "Requires detailed analysis" ],
        "strategic_implications" => "Continue monitoring key performance indicators",
        "confidence_level" => "medium"
      }
    end

    def fallback_insights
      [
        {
          "title" => "Data Processing Performance",
          "description" => "System processed #{@data_context[:operational_metrics][:total_records]} records",
          "impact_score" => 6,
          "recommended_action" => "Continue monitoring",
          "priority" => "medium"
        }
      ]
    end

    def fallback_predictions
      {
        "revenue_forecast" => { "value" => "Stable", "confidence" => "medium" },
        "customer_growth" => { "trend" => "Steady", "confidence" => "medium" },
        "key_risks" => [ "Market volatility" ],
        "opportunities" => [ "Data optimization" ]
      }
    end

    def fallback_recommendations
      [
        {
          "title" => "Continue Data Monitoring",
          "description" => "Maintain current data collection and processing",
          "priority" => "medium",
          "timeline" => "Ongoing",
          "resources" => "Current team"
        }
      ]
    end

    def generate_fallback_narrative
      <<~MARKDOWN
        # Business Intelligence Report

        ## Executive Summary

        This report provides an overview of business performance for #{@organization.name} over the past #{@time_period.inspect}.

        ## Key Metrics

        - Total records processed: #{@data_context[:operational_metrics][:total_records]}
        - Data sources active: #{@data_context[:data_quality_metrics][:data_sources_active]}
        - System success rate: #{@data_context[:operational_metrics][:success_rate]}%

        ## Next Steps

        Continue monitoring key performance indicators and data quality metrics.
      MARKDOWN
    end

    # Business calculation implementations
    def calculate_total_revenue_from_orders(orders)
      return 0 if orders.blank?

      orders.sum do |order|
        # Try common field names for order total
        order["total"] || order["amount"] || order["total_price"] || order["revenue"] || 0
      end.to_f
    end

    def calculate_average_order_value_from_orders(orders)
      return 0 if orders.blank?

      total_revenue = calculate_total_revenue_from_orders(orders)
      total_revenue / orders.count.to_f
    end

    def calculate_customer_growth_rate(customers)
      return 0 if customers.blank?

      # Group customers by month
      monthly_customers = customers.group_by do |customer|
        created_at = customer["created_at"] || customer["date_joined"] || customer["signup_date"]
        next nil unless created_at

        Date.parse(created_at.to_s).beginning_of_month rescue nil
      end.compact

      return 0 if monthly_customers.size < 2

      # Calculate growth rate between last two months
      sorted_months = monthly_customers.keys.sort
      current_month = monthly_customers[sorted_months.last]&.count || 0
      previous_month = monthly_customers[sorted_months[-2]]&.count || 1

      ((current_month - previous_month).to_f / previous_month * 100).round(2)
    end

    def calculate_top_products(products)
      return [] if products.blank?

      # Group by product name/id and sum quantities or revenue
      product_stats = products.group_by do |product|
        product["name"] || product["product_name"] || product["title"] || product["id"]
      end

      top_products = product_stats.map do |name, items|
        total_quantity = items.sum { |item| (item["quantity"] || 1).to_i }
        total_revenue = items.sum { |item| (item["price"] || item["total"] || 0).to_f }

        {
          name: name,
          quantity_sold: total_quantity,
          revenue: total_revenue,
          orders: items.count
        }
      end

      # Sort by revenue and return top 5
      top_products.sort_by { |p| -p[:revenue] }.first(5)
    end

    def calculate_average_processing_time
      # Calculate average processing time for extraction jobs
      recent_jobs = @organization.extraction_jobs
                                .where("created_at >= ?", 30.days.ago)
                                .where.not(completed_at: nil)

      return 0 if recent_jobs.empty?

      total_time = recent_jobs.sum do |job|
        (job.completed_at - job.created_at).to_f
      end

      (total_time / recent_jobs.count / 60).round(2) # Return in minutes
    end
    def parse_title_slide(response); {}; end
    def parse_summary_slide(response); {}; end
    def parse_insights_slides(response); []; end
    def parse_recommendations_slide(response); {}; end
    def parse_validation_response(response); {}; end
    def parse_alerts_response(response); []; end
    def generate_fallback_analysis(query, data); "Analysis unavailable"; end
  end

  # Mock LLM Chat class to simulate ruby_llm interface
  class MockLLMChat
    def ask(prompt)
      # This would be replaced with actual ruby_llm implementation
      Rails.logger.info "AI Prompt: #{prompt.truncate(100)}"

      # Return a mock response for now
      if prompt.include?("JSON")
        '{"analysis": "Mock AI response", "confidence": "medium"}'
      else
        "This is a mock AI response to: #{prompt.split('.').first}..."
      end
    end
  end
end
