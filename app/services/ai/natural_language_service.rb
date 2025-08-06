# frozen_string_literal: true

module Ai
  class NaturalLanguageService
    include ActionView::Helpers::NumberHelper

    attr_reader :organization, :user

    INTENTS = {
      revenue_analysis: {
        patterns: [
          /revenue|sales|income|earnings/i,
          /how much.*made|earned/i,
          /top.*products?|services?/i
        ],
        handler: :analyze_revenue
      },
      customer_analysis: {
        patterns: [
          /customer|client|user/i,
          /churn|retention|lifetime value|ltv/i,
          /satisfaction|nps|feedback/i
        ],
        handler: :analyze_customers
      },
      performance_analysis: {
        patterns: [
          /performance|kpi|metric/i,
          /compare|versus|vs|comparison/i,
          /trend|growth|decline/i
        ],
        handler: :analyze_performance
      },
      anomaly_detection: {
        patterns: [
          /anomaly|unusual|strange|weird/i,
          /what.*wrong|issue|problem/i,
          /alert|warning|concern/i
        ],
        handler: :detect_anomalies
      },
      forecast: {
        patterns: [
          /forecast|predict|projection/i,
          /will|future|next|upcoming/i,
          /estimate|expect/i
        ],
        handler: :generate_forecast
      },
      action_request: {
        patterns: [
          /create|make|generate|build/i,
          /send|email|notify|alert/i,
          /update|change|modify|adjust/i
        ],
        handler: :suggest_action
      }
    }.freeze

    def initialize(organization:, user:)
      @organization = organization
      @user = user
      @llm_service = Ai::LlmService.new
      @bi_agent = Ai::BusinessIntelligenceAgentService.new(organization)
    end

    def process_query(query, context = {})
      # Store query for analytics
      stored_query = store_query(query, context)

      # Extract intent and entities
      intent = detect_intent(query)
      entities = extract_entities(query)

      # Generate response based on intent
      response = case intent
      when :revenue_analysis
        analyze_revenue(query, entities, context)
      when :customer_analysis
        analyze_customers(query, entities, context)
      when :performance_analysis
        analyze_performance(query, entities, context)
      when :anomaly_detection
        detect_anomalies(query, entities, context)
      when :forecast
        generate_forecast(query, entities, context)
      when :action_request
        suggest_action(query, entities, context)
      else
        handle_general_query(query, context)
      end

      # Update stored query with response
      stored_query.update!(
        response: response[:message],
        intent: intent,
        entities: entities
      )

      response
    end

    def process_voice_command(audio_data)
      # Transcribe audio using Whisper or Web Speech API
      transcript = transcribe_audio(audio_data)

      # Process as regular query
      process_query(transcript)
    end

    def get_suggestions(partial_query)
      # Return autocomplete suggestions based on common queries
      recent_queries = Ai::Query.where(organization: organization)
                                .where("query ILIKE ?", "#{partial_query}%")
                                .distinct
                                .limit(5)
                                .pluck(:query)

      # Add common query templates
      templates = [
        "What's my revenue for",
        "Show me customer churn",
        "Compare this month to",
        "Why did sales drop",
        "Forecast next quarter",
        "Create a report about"
      ].select { |t| t.downcase.include?(partial_query.downcase) }

      (recent_queries + templates).uniq.first(5)
    end

    private

    def detect_intent(query)
      INTENTS.each do |intent, config|
        config[:patterns].each do |pattern|
          return intent if query.match?(pattern)
        end
      end

      :general
    end

    def extract_entities(query)
      entities = {}

      # Extract time periods
      if query.match?(/(?:last|past|previous)\s+(\w+)/i)
        period = $1.downcase
        entities[:time_period] = period
        entities[:time_range] = calculate_time_range(period)
      elsif query.match?(/(?:this|current)\s+(\w+)/i)
        period = $1.downcase
        entities[:time_period] = "current_#{period}"
        entities[:time_range] = calculate_time_range("current_#{period}")
      end

      # Extract comparison periods
      if query.match?(/compare.*?to\s+(\w+\s+\w+)/i)
        entities[:comparison_period] = $1.downcase
      end

      # Extract metrics/KPIs mentioned
      metrics = %w[revenue sales customers churn rate conversion profit margin]
      mentioned_metrics = metrics.select { |m| query.downcase.include?(m) }
      entities[:metrics] = mentioned_metrics if mentioned_metrics.any?

      # Extract product/service names
      if query.match?(/(?:product|service|item)\s+["']?([^"']+)["']?/i)
        entities[:product] = $1.strip
      end

      entities
    end

    def analyze_revenue(query, entities, context)
      time_range = entities[:time_range] || 30.days.ago..Time.current

      # Get revenue data
      revenue_data = organization.raw_data_records
                                 .where(created_at: time_range)
                                 .where(record_type: "order")
                                 .sum("(data->>'total')::decimal")

      # Get top products
      top_products = organization.raw_data_records
                                 .where(created_at: time_range)
                                 .where(record_type: "order")
                                 .group("data->>'product_name'")
                                 .sum("(data->>'total')::decimal")
                                 .sort_by { |_, v| -v }
                                 .first(5)

      # Compare to previous period if requested
      comparison = if entities[:comparison_period]
        previous_range = calculate_time_range(entities[:comparison_period])
        previous_revenue = organization.raw_data_records
                                       .where(created_at: previous_range)
                                       .where(record_type: "order")
                                       .sum("(data->>'total')::decimal")

        change = ((revenue_data - previous_revenue) / previous_revenue * 100).round(1)
        { previous: previous_revenue, change: change }
      end

      # Generate natural language response
      message = build_revenue_response(revenue_data, top_products, comparison, entities)

      {
        message: message,
        data: {
          revenue: revenue_data,
          top_products: top_products,
          comparison: comparison
        },
        visualizations: [
          { type: "metric", title: "Total Revenue", value: revenue_data },
          { type: "bar_chart", title: "Top Products", data: top_products }
        ],
        actions: suggest_revenue_actions(revenue_data, comparison)
      }
    end

    def analyze_customers(query, entities, context)
      # Implementation for customer analysis
      insights = @bi_agent.monitor_customer_lifecycle

      {
        message: "Here's your customer analysis: #{insights[:summary]}",
        data: insights,
        visualizations: [
          { type: "metric", title: "Active Customers", value: insights[:active_customers] },
          { type: "line_chart", title: "Churn Trend", data: insights[:churn_trend] }
        ],
        actions: insights[:recommended_actions]
      }
    end

    def analyze_performance(query, entities, context)
      # Get KPI data
      kpis = @bi_agent.generate_proactive_insights

      {
        message: "Performance analysis shows #{kpis[:summary]}",
        data: kpis,
        visualizations: kpis[:visualizations],
        actions: kpis[:recommendations]
      }
    end

    def detect_anomalies(query, entities, context)
      anomalies = @bi_agent.detect_business_anomalies_and_opportunities

      if anomalies[:anomalies].any?
        {
          message: "I found #{anomalies[:anomalies].count} anomalies that need attention.",
          data: anomalies,
          visualizations: anomalies[:visualizations],
          actions: anomalies[:recommended_actions],
          priority: "high"
        }
      else
        {
          message: "Good news! No significant anomalies detected in your data.",
          data: anomalies,
          visualizations: [],
          actions: []
        }
      end
    end

    def generate_forecast(query, entities, context)
      scenarios = @bi_agent.predict_business_scenarios

      {
        message: "Based on current trends, here's what I'm forecasting:",
        data: scenarios,
        visualizations: [
          {
            type: "line_chart",
            title: "Revenue Forecast",
            data: scenarios[:revenue_projection],
            scenarios: [ "optimistic", "realistic", "pessimistic" ]
          }
        ],
        actions: scenarios[:recommendations]
      }
    end

    def suggest_action(query, entities, context)
      # Parse action intent
      action_type = detect_action_type(query)

      # Create action suggestion
      action = Ai::AutomatedAction.new(
        organization: organization,
        action_type: action_type,
        parameters: entities,
        suggested_by: "natural_language_query"
      )

      {
        message: "I can help you with that. Here's what I suggest:",
        data: { action: action },
        visualizations: [],
        actions: [
          {
            type: action_type,
            description: action.description,
            impact: action.estimated_impact,
            requires_approval: action.requires_approval?,
            confidence: 0.85
          }
        ],
        requires_confirmation: true
      }
    end

    def handle_general_query(query, context)
      # Use LLM for general queries
      llm_response = @llm_service.get_completion(
        prompt: build_general_prompt(query, context),
        max_tokens: 500
      )

      {
        message: llm_response,
        data: {},
        visualizations: [],
        actions: []
      }
    end

    def build_revenue_response(revenue, top_products, comparison, entities)
      period_text = entities[:time_period] || "the selected period"
      revenue_text = number_to_currency(revenue)

      response = "Your revenue for #{period_text} is #{revenue_text}."

      if comparison
        trend = comparison[:change] > 0 ? "up" : "down"
        response += " That's #{trend} #{comparison[:change].abs}% compared to #{entities[:comparison_period]}."
      end

      if top_products.any?
        response += " Your top performing product is #{top_products.first[0]} with #{number_to_currency(top_products.first[1])} in sales."
      end

      response
    end

    def suggest_revenue_actions(revenue, comparison)
      actions = []

      if comparison && comparison[:change] < -10
        actions << {
          type: "alert",
          description: "Revenue declined significantly. Would you like me to analyze why?",
          priority: "high"
        }
      end

      actions << {
        type: "report",
        description: "Generate detailed revenue report",
        priority: "medium"
      }

      actions
    end

    def calculate_time_range(period)
      case period
      when "week", "last_week"
        1.week.ago..Time.current
      when "month", "last_month"
        1.month.ago..Time.current
      when "quarter", "last_quarter"
        3.months.ago..Time.current
      when "year", "last_year"
        1.year.ago..Time.current
      when /current_(\w+)/
        unit = $1
        Time.current.send("beginning_of_#{unit}")..Time.current
      else
        30.days.ago..Time.current
      end
    end

    def store_query(query, context)
      Ai::Query.create!(
        organization: organization,
        user: user,
        query: query,
        context: context
      )
    end

    def transcribe_audio(audio_data)
      # Implementation would use Whisper API or Web Speech API
      # For now, returning placeholder
      "transcribed query from audio"
    end

    def detect_action_type(query)
      case query.downcase
      when /email|send.*report/
        :send_email
      when /create.*campaign/
        :create_campaign
      when /adjust.*price|pricing/
        :adjust_pricing
      when /order.*inventory|reorder/
        :reorder_inventory
      else
        :general_action
      end
    end

    def build_general_prompt(query, context)
      <<~PROMPT
        You are an AI business intelligence assistant for a data analytics platform.
        The user has asked: "#{query}"

        Context: #{context.to_json}

        Provide a helpful, concise response focused on business insights and data analysis.
        If you need specific data to answer the question, explain what data would be helpful.
      PROMPT
    end
  end
end
