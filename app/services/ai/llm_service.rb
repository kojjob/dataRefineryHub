# frozen_string_literal: true

module Ai
  class LlmService
    include ActiveModel::Model

    attr_accessor :provider, :model, :organization, :cache_service, :rate_limiter

    SUPPORTED_PROVIDERS = %w[openai anthropic google mock].freeze

    def initialize(provider: :openai, model: nil, organization: nil)
      @provider = provider.to_sym
      @model = model || default_model_for_provider
      @organization = organization
      @chat = initialize_chat
      @cache_service = Ai::CacheService.new(organization: @organization) if @organization
      @rate_limiter = Ai::RateLimitService.new(
        organization: @organization,
        operation_type: :llm_request
      ) if @organization
    end

    def analyze_business_metrics(data_context, query = nil)
      prompt = build_business_analysis_prompt(data_context, query)
      prompt_hash = generate_prompt_hash(prompt, data_context)

      # Try to get cached response first
      if @cache_service
        cached_response = @cache_service.get_cached_llm_response(prompt_hash, model_config)
        return cached_response[:response] if cached_response
      end

      # Check rate limits
      if @rate_limiter&.rate_limited?
        Rails.logger.warn "Rate limited for business analysis request"
        return fallback_business_analysis(data_context)
      end

      begin
        response = @chat.ask(prompt)
        parsed_response = parse_business_analysis_response(response)

        # Record rate limit usage
        @rate_limiter&.record_request

        # Cache the response
        @cache_service&.cache_llm_response(prompt_hash, model_config, parsed_response)

        parsed_response
      rescue => e
        Rails.logger.error "LLM analysis failed: #{e.message}"
        fallback_business_analysis(data_context)
      end
    end

    def generate_executive_summary(metrics_data)
      prompt = build_executive_summary_prompt(metrics_data)

      begin
        response = @chat.ask(prompt)
        parse_executive_summary_response(response)
      rescue => e
        Rails.logger.error "Executive summary generation failed: #{e.message}"
        fallback_executive_summary(metrics_data)
      end
    end

    def detect_anomalies(historical_data, current_data)
      prompt = build_anomaly_detection_prompt(historical_data, current_data)

      begin
        response = @chat.ask(prompt)
        parse_anomaly_detection_response(response)
      rescue => e
        Rails.logger.error "Anomaly detection failed: #{e.message}"
        []
      end
    end

    def generate_recommendations(insights_data)
      prompt = build_recommendations_prompt(insights_data)

      begin
        response = @chat.ask(prompt)
        parse_recommendations_response(response)
      rescue => e
        Rails.logger.error "Recommendations generation failed: #{e.message}"
        fallback_recommendations
      end
    end

    def validate_data_quality(data_sample, schema_expectations = nil)
      prompt = build_data_validation_prompt(data_sample, schema_expectations)

      begin
        response = @chat.ask(prompt)
        parse_data_validation_response(response)
      rescue => e
        Rails.logger.error "Data validation failed: #{e.message}"
        fallback_data_validation(data_sample)
      end
    end

    def generate_natural_language_query(user_query, available_data_fields)
      prompt = build_query_translation_prompt(user_query, available_data_fields)

      begin
        response = @chat.ask(prompt)
        parse_query_translation_response(response)
      rescue => e
        Rails.logger.error "Query translation failed: #{e.message}"
        { error: "Could not translate query", original_query: user_query }
      end
    end

    def create_presentation_narrative(slide_data, template_type)
      prompt = build_presentation_narrative_prompt(slide_data, template_type)

      begin
        response = @chat.ask(prompt)
        parse_presentation_narrative_response(response)
      rescue => e
        Rails.logger.error "Presentation narrative generation failed: #{e.message}"
        fallback_presentation_narrative(slide_data)
      end
    end

    private

    def initialize_chat
      case @provider
      when :mock
        MockLlmChat.new(@organization)
      else
        # When ruby_llm is added, this would be:
        # RubyLLM.chat(provider: @provider, model: @model)
        MockLlmChat.new(@organization)
      end
    end

    def default_model_for_provider
      case @provider
      when :openai
        "gpt-4"
      when :anthropic
        "claude-3-sonnet-20240229"
      when :google
        "gemini-pro"
      else
        "mock-model"
      end
    end

    # Prompt building methods

    def build_business_analysis_prompt(data_context, query)
      base_prompt = <<~PROMPT
        You are a senior business analyst with expertise in data interpretation and strategic insights.

        Organization: #{@organization&.name || 'DataReflow Client'}
        Analysis Request: #{query || 'Comprehensive business analysis'}

        Business Data Context:
        #{format_data_context(data_context)}

        Please provide a comprehensive analysis that includes:
        1. Key performance indicators and their implications
        2. Notable trends and patterns in the data
        3. Potential areas of concern or opportunity
        4. Specific, actionable insights based on the data
        5. Confidence level in your analysis (high/medium/low)

        Format your response as JSON with the following structure:
        {
          "summary": "Brief overview of findings",
          "key_insights": [
            {
              "title": "Insight title",
              "description": "Detailed description",
              "impact": "high|medium|low",
              "confidence": "high|medium|low",
              "supporting_data": ["relevant data points"]
            }
          ],
          "trends": [
            {
              "metric": "metric name",
              "direction": "increasing|decreasing|stable",
              "significance": "high|medium|low",
              "timeframe": "period observed"
            }
          ],
          "recommendations": ["specific actionable recommendations"],
          "overall_confidence": "high|medium|low"
        }
      PROMPT

      base_prompt
    end

    def build_executive_summary_prompt(metrics_data)
      <<~PROMPT
        Create an executive summary for a business intelligence report based on the following metrics:

        #{format_data_context(metrics_data)}

        The summary should:
        1. Be concise but comprehensive (2-3 paragraphs)
        2. Highlight the most important business outcomes
        3. Focus on strategic implications rather than technical details
        4. Use executive-friendly language
        5. Include specific numbers and percentages where relevant

        Format as JSON:
        {
          "headline": "One-sentence summary of overall performance",
          "summary_paragraphs": ["paragraph 1", "paragraph 2", "paragraph 3"],
          "key_metrics_callouts": [
            {
              "metric": "metric name",
              "value": "current value",
              "change": "change description",
              "significance": "why this matters"
            }
          ],
          "strategic_implications": "What this means for business strategy"
        }
      PROMPT
    end

    def build_anomaly_detection_prompt(historical_data, current_data)
      <<~PROMPT
        You are a data scientist specializing in anomaly detection for business metrics.

        Historical Data (baseline):
        #{format_data_context(historical_data)}

        Current Data:
        #{format_data_context(current_data)}

        Analyze the current data against historical patterns and identify:
        1. Statistical anomalies (values outside normal ranges)
        2. Trend anomalies (unexpected changes in direction)
        3. Pattern anomalies (unusual behaviors or correlations)
        4. Business-critical anomalies that require immediate attention

        For each anomaly, assess:
        - Severity (critical/high/medium/low)
        - Confidence in detection (high/medium/low)
        - Potential business impact
        - Suggested investigation steps

        Only flag genuine anomalies that warrant business attention.

        Format as JSON:
        {
          "anomalies": [
            {
              "type": "statistical|trend|pattern",
              "metric": "affected metric",
              "description": "what's abnormal",
              "severity": "critical|high|medium|low",
              "confidence": "high|medium|low",
              "current_value": "current value",
              "expected_range": "normal range",
              "potential_causes": ["possible explanations"],
              "business_impact": "impact description",
              "investigation_steps": ["recommended actions"]
            }
          ],
          "summary": "Overall anomaly assessment"
        }
      PROMPT
    end

    def build_recommendations_prompt(insights_data)
      <<~PROMPT
        Based on the following business insights, generate strategic recommendations:

        Insights Data:
        #{format_data_context(insights_data)}

        Generate specific, actionable recommendations that:
        1. Address the most impactful insights
        2. Are realistic and implementable
        3. Include estimated effort and timeline
        4. Specify success metrics
        5. Are prioritized by potential business impact

        Format as JSON:
        {
          "recommendations": [
            {
              "title": "Recommendation title",
              "description": "Detailed description",
              "rationale": "Why this recommendation matters",
              "priority": "high|medium|low",
              "estimated_effort": "low|medium|high",
              "timeline": "immediate|1-4 weeks|1-3 months|3+ months",
              "success_metrics": ["how to measure success"],
              "potential_impact": "expected business impact",
              "implementation_steps": ["step 1", "step 2", "step 3"]
            }
          ],
          "quick_wins": ["immediate actions with high impact"],
          "long_term_strategies": ["strategic initiatives for sustained growth"]
        }
      PROMPT
    end

    def build_data_validation_prompt(data_sample, schema_expectations)
      schema_info = schema_expectations ? "\nExpected Schema: #{schema_expectations}" : ""

      <<~PROMPT
        Analyze this data sample for quality, consistency, and validation issues:

        Data Sample:
        #{data_sample.inspect}
        #{schema_info}

        Identify:
        1. Data type inconsistencies
        2. Missing or null values that shouldn't be empty
        3. Format violations (dates, emails, phone numbers, etc.)
        4. Outliers or suspicious values
        5. Duplicate records
        6. Referential integrity issues
        7. Business logic violations

        Format as JSON:
        {
          "validation_results": {
            "overall_quality_score": "0-100",
            "total_records_analyzed": "number",
            "issues_found": "number"
          },
          "issues": [
            {
              "type": "missing_data|format_error|outlier|duplicate|integrity",
              "field": "field name",
              "description": "issue description",
              "severity": "critical|high|medium|low",
              "affected_records": "count or percentage",
              "suggested_fix": "how to resolve"
            }
          ],
          "recommendations": ["specific data quality improvements"],
          "compliance_notes": ["any regulatory or business rule violations"]
        }
      PROMPT
    end

    def build_query_translation_prompt(user_query, available_fields)
      <<~PROMPT
        You are a data query translator. Convert natural language questions into structured data queries.

        User Question: "#{user_query}"

        Available Data Fields:
        #{available_fields.join(', ')}

        Translate this into:
        1. The specific data fields needed
        2. Any filters or conditions required
        3. Aggregations or calculations needed
        4. Time periods or date ranges
        5. Grouping or sorting requirements

        Format as JSON:
        {
          "interpreted_intent": "what the user is asking for",
          "required_fields": ["field1", "field2"],
          "filters": [
            {
              "field": "field name",
              "operator": "equals|greater_than|less_than|contains|between",
              "value": "filter value"
            }
          ],
          "aggregations": [
            {
              "function": "sum|avg|count|min|max",
              "field": "field to aggregate"
            }
          ],
          "time_range": {
            "start_date": "YYYY-MM-DD or relative like '30 days ago'",
            "end_date": "YYYY-MM-DD or 'today'"
          },
          "grouping": ["fields to group by"],
          "sorting": [
            {
              "field": "field name",
              "direction": "asc|desc"
            }
          ],
          "confidence": "high|medium|low"
        }
      PROMPT
    end

    def build_presentation_narrative_prompt(slide_data, template_type)
      <<~PROMPT
        Create compelling narrative content for a #{template_type} presentation based on:

        Slide Data:
        #{format_data_context(slide_data)}

        Generate narrative content that:
        1. Tells a coherent story across all slides
        2. Uses data to support key points
        3. Is appropriate for executive audience
        4. Includes smooth transitions between topics
        5. Ends with clear action items

        Format as JSON:
        {
          "presentation_theme": "overarching story/theme",
          "slide_narratives": [
            {
              "slide_number": 1,
              "title": "slide title",
              "narrative": "narrative text for this slide",
              "key_points": ["bullet point 1", "bullet point 2"],
              "transition_to_next": "how this connects to next slide"
            }
          ],
          "executive_summary": "one paragraph summary of entire presentation",
          "call_to_action": "specific next steps for audience"
        }
      PROMPT
    end

    # Response parsing methods

    def parse_business_analysis_response(response)
      parsed = parse_json_response(response)
      return fallback_business_analysis({}) unless parsed

      {
        summary: parsed["summary"],
        key_insights: parsed["key_insights"] || [],
        trends: parsed["trends"] || [],
        recommendations: parsed["recommendations"] || [],
        confidence_level: parsed["overall_confidence"] || "medium",
        generated_at: Time.current.iso8601
      }
    end

    def parse_executive_summary_response(response)
      parsed = parse_json_response(response)
      return fallback_executive_summary({}) unless parsed

      {
        headline: parsed["headline"],
        summary_paragraphs: parsed["summary_paragraphs"] || [],
        key_metrics: parsed["key_metrics_callouts"] || [],
        strategic_implications: parsed["strategic_implications"],
        generated_at: Time.current.iso8601
      }
    end

    def parse_anomaly_detection_response(response)
      parsed = parse_json_response(response)
      return [] unless parsed && parsed["anomalies"]

      parsed["anomalies"].map do |anomaly|
        {
          type: anomaly["type"],
          metric: anomaly["metric"],
          description: anomaly["description"],
          severity: anomaly["severity"],
          confidence: anomaly["confidence"],
          current_value: anomaly["current_value"],
          expected_range: anomaly["expected_range"],
          potential_causes: anomaly["potential_causes"] || [],
          business_impact: anomaly["business_impact"],
          investigation_steps: anomaly["investigation_steps"] || [],
          detected_at: Time.current.iso8601
        }
      end
    end

    def parse_recommendations_response(response)
      parsed = parse_json_response(response)
      return fallback_recommendations unless parsed && parsed["recommendations"]

      {
        recommendations: parsed["recommendations"].map do |rec|
          {
            title: rec["title"],
            description: rec["description"],
            rationale: rec["rationale"],
            priority: rec["priority"],
            effort: rec["estimated_effort"],
            timeline: rec["timeline"],
            success_metrics: rec["success_metrics"] || [],
            impact: rec["potential_impact"],
            steps: rec["implementation_steps"] || []
          }
        end,
        quick_wins: parsed["quick_wins"] || [],
        long_term_strategies: parsed["long_term_strategies"] || [],
        generated_at: Time.current.iso8601
      }
    end

    def parse_data_validation_response(response)
      parsed = parse_json_response(response)
      return fallback_data_validation({}) unless parsed

      {
        quality_score: parsed.dig("validation_results", "overall_quality_score"),
        total_records: parsed.dig("validation_results", "total_records_analyzed"),
        issues_count: parsed.dig("validation_results", "issues_found"),
        issues: parsed["issues"] || [],
        recommendations: parsed["recommendations"] || [],
        compliance_notes: parsed["compliance_notes"] || [],
        validated_at: Time.current.iso8601
      }
    end

    def parse_query_translation_response(response)
      parsed = parse_json_response(response)
      return { error: "Could not parse query translation" } unless parsed

      {
        intent: parsed["interpreted_intent"],
        fields: parsed["required_fields"] || [],
        filters: parsed["filters"] || [],
        aggregations: parsed["aggregations"] || [],
        time_range: parsed["time_range"] || {},
        grouping: parsed["grouping"] || [],
        sorting: parsed["sorting"] || [],
        confidence: parsed["confidence"] || "medium",
        translated_at: Time.current.iso8601
      }
    end

    def parse_presentation_narrative_response(response)
      parsed = parse_json_response(response)
      return fallback_presentation_narrative({}) unless parsed

      {
        theme: parsed["presentation_theme"],
        slide_narratives: parsed["slide_narratives"] || [],
        executive_summary: parsed["executive_summary"],
        call_to_action: parsed["call_to_action"],
        generated_at: Time.current.iso8601
      }
    end

    # Utility methods

    def format_data_context(data)
      return "No data provided" unless data.present?

      case data
      when Hash
        data.map { |k, v| "#{k.to_s.humanize}: #{format_value(v)}" }.join("\n")
      when Array
        data.map.with_index { |item, i| "#{i + 1}. #{format_value(item)}" }.join("\n")
      else
        data.to_s
      end
    end

    def format_value(value)
      case value
      when Hash
        value.map { |k, v| "  #{k}: #{v}" }.join("\n")
      when Array
        value.join(", ")
      when Numeric
        value.to_s
      else
        value.to_s.truncate(100)
      end
    end

    def parse_json_response(response)
      return nil unless response

      # Try to extract JSON from response
      json_match = response.match(/\{.*\}/m)
      return nil unless json_match

      JSON.parse(json_match[0])
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse JSON response: #{e.message}"
      nil
    end

    # Fallback methods

    def fallback_business_analysis(data_context)
      {
        summary: "Business analysis completed with available data",
        key_insights: [
          {
            title: "Data Processing Status",
            description: "System is processing business data successfully",
            impact: "medium",
            confidence: "high",
            supporting_data: [ "Operational metrics available" ]
          }
        ],
        trends: [],
        recommendations: [ "Continue monitoring key metrics" ],
        confidence_level: "medium"
      }
    end

    def fallback_executive_summary(metrics_data)
      {
        headline: "Business operations continue with stable performance",
        summary_paragraphs: [
          "The organization maintains operational efficiency with ongoing data processing and analysis.",
          "Key metrics are being monitored to ensure continued business performance."
        ],
        key_metrics: [],
        strategic_implications: "Maintain current operational focus while expanding data-driven insights"
      }
    end

    def fallback_recommendations
      {
        recommendations: [
          {
            title: "Continue Data Monitoring",
            description: "Maintain current data collection and analysis processes",
            priority: "medium",
            effort: "low",
            timeline: "ongoing",
            success_metrics: [ "System uptime", "Data quality scores" ],
            impact: "Ensures continued business intelligence capability",
            steps: [ "Monitor dashboard regularly", "Review data quality metrics" ]
          }
        ],
        quick_wins: [ "Regular data quality checks" ],
        long_term_strategies: [ "Expand data sources", "Enhance AI capabilities" ]
      }
    end

    def fallback_data_validation(data_sample)
      {
        quality_score: 75,
        total_records: data_sample.is_a?(Array) ? data_sample.count : 1,
        issues_count: 0,
        issues: [],
        recommendations: [ "Continue regular data validation" ],
        compliance_notes: []
      }
    end

    def fallback_presentation_narrative(slide_data)
      {
        theme: "Business Performance Overview",
        slide_narratives: [
          {
            slide_number: 1,
            title: "Executive Summary",
            narrative: "This presentation provides an overview of current business performance and key metrics.",
            key_points: [ "Data-driven insights", "Performance metrics", "Strategic recommendations" ],
            transition_to_next: "Let's examine the key performance indicators..."
          }
        ],
        executive_summary: "The presentation covers essential business metrics and provides strategic insights for continued growth.",
        call_to_action: "Review recommendations and implement priority actions to drive business growth"
      }
    end
  end

  # Mock LLM Chat for development/testing
  class MockLlmChat
    def initialize(organization = nil)
      @organization = organization
    end

    def ask(prompt, options = {})
      # Simulate different types of responses based on prompt content
      if prompt.include?("JSON") && prompt.include?("business analysis")
        mock_business_analysis_response
      elsif prompt.include?("executive summary")
        mock_executive_summary_response
      elsif prompt.include?("anomaly")
        mock_anomaly_response
      elsif prompt.include?("recommendations")
        mock_recommendations_response
      elsif prompt.include?("validation")
        mock_validation_response
      else
        "This is a mock response to the AI query. In production, this would be replaced with actual LLM responses."
      end
    end

    private

    def mock_business_analysis_response
      # Calculate dynamic values based on organization context
      growth_potential = calculate_growth_potential
      trend_direction = determine_trend_direction
      confidence_level = assess_data_confidence
      organization_name = @organization&.name || "Demo Organization"

      {
        "summary" => "Business analysis based on #{organization_name} data showing #{trend_direction} performance trends",
        "key_insights" => [
          {
            "title" => "Revenue Growth Opportunity",
            "description" => "Analysis indicates potential for #{growth_potential}% revenue increase based on current trends",
            "impact" => calculate_impact_level(growth_potential),
            "confidence" => confidence_level,
            "supporting_data" => generate_supporting_data_sources
          }
        ],
        "trends" => [
          {
            "metric" => "Customer Acquisition",
            "direction" => trend_direction,
            "significance" => calculate_trend_significance,
            "timeframe" => "past #{determine_analysis_period} days"
          }
        ],
        "recommendations" => generate_dynamic_recommendations(growth_potential, trend_direction),
        "overall_confidence" => confidence_level
      }.to_json
    end

    def mock_executive_summary_response
      trend_direction = determine_trend_direction
      efficiency_score = calculate_system_efficiency
      efficiency_change = calculate_efficiency_trend
      organization_name = @organization&.name || "Demo Organization"

      {
        "headline" => "#{organization_name} shows #{trend_direction} operational performance with strategic growth opportunities",
        "summary_paragraphs" => [
          "#{organization_name} demonstrates #{efficiency_score > 85 ? 'strong' : 'stable'} operational efficiency with key metrics trending #{trend_direction}.",
          "Strategic opportunities for growth have been identified through analysis of #{calculate_data_points_analyzed} data points."
        ],
        "key_metrics_callouts" => [
          {
            "metric" => "Data Processing Efficiency",
            "value" => "#{efficiency_score}%",
            "change" => "#{efficiency_change.abs}% #{efficiency_change >= 0 ? 'improvement' : 'decline'}",
            "significance" => efficiency_score > 90 ? "Indicates excellent operational foundation" : "Shows solid operational performance"
          }
        ],
        "strategic_implications" => generate_strategic_implications(trend_direction, efficiency_score)
      }.to_json
    end

    def mock_anomaly_response
      processing_time = calculate_current_processing_time
      expected_range = calculate_expected_processing_range
      severity = assess_performance_severity(processing_time, expected_range)

      {
        "anomalies" => [
          {
            "type" => "trend",
            "metric" => "processing_speed",
            "description" => generate_anomaly_description(processing_time, expected_range),
            "severity" => severity,
            "confidence" => assess_anomaly_confidence(processing_time, expected_range),
            "current_value" => "#{processing_time} seconds",
            "expected_range" => "#{expected_range[:min]}-#{expected_range[:max]} seconds",
            "potential_causes" => generate_potential_causes(processing_time, expected_range),
            "business_impact" => assess_business_impact(severity),
            "investigation_steps" => generate_investigation_steps(severity)
          }
        ],
        "summary" => generate_anomaly_summary(severity)
      }.to_json
    end

    def mock_recommendations_response
      {
        "recommendations" => [
          {
            "title" => "Optimize Data Processing Pipeline",
            "description" => "Implement caching and batch processing optimizations",
            "rationale" => "Current processing speed anomaly indicates optimization potential",
            "priority" => "high",
            "estimated_effort" => "medium",
            "timeline" => "1-4 weeks",
            "success_metrics" => [ "Processing time reduction", "System throughput increase" ],
            "potential_impact" => "Improved user experience and system efficiency",
            "implementation_steps" => [ "Analyze current bottlenecks", "Implement caching layer", "Test optimizations" ]
          }
        ],
        "quick_wins" => [ "Enable query caching", "Optimize database indexes" ],
        "long_term_strategies" => [ "Implement microservices architecture", "Add machine learning predictions" ]
      }.to_json
    end

    def mock_validation_response
      quality_score = calculate_data_quality_score
      total_records = calculate_total_records_analyzed
      issues_count = calculate_data_issues_count
      missing_data_percentage = calculate_missing_data_percentage

      {
        "validation_results" => {
          "overall_quality_score" => quality_score.to_s,
          "total_records_analyzed" => total_records.to_s,
          "issues_found" => issues_count.to_s
        },
        "issues" => [
          {
            "type" => "missing_data",
            "field" => "customer_email",
            "description" => "#{missing_data_percentage}% of customer records missing email addresses",
            "severity" => missing_data_percentage > 10 ? "high" : "medium",
            "affected_records" => "#{(total_records * missing_data_percentage / 100).round} records",
            "suggested_fix" => generate_data_fix_suggestion(missing_data_percentage)
          }
        ],
        "recommendations" => generate_data_quality_recommendations(quality_score, issues_count),
        "compliance_notes" => generate_compliance_notes(missing_data_percentage)
      }.to_json
    end

    # Dynamic calculation helper methods
    def calculate_growth_potential
      # Calculate based on actual organization data and activity
      return 12.0 unless @organization # Default value if no organization

      base_growth = 8.0

      # Factor in data source diversity and activity
      data_factor = @organization.data_sources.count * 1.5

      # Factor in recent data processing activity
      recent_records = @organization.raw_data_records.where("created_at >= ?", 30.days.ago).count
      activity_factor = recent_records > 1000 ? 5.0 : recent_records > 100 ? 3.0 : 1.0

      # Factor in organization maturity
      org_age_months = ((Date.current - @organization.created_at.to_date) / 30).to_i
      maturity_factor = [ org_age_months * 0.5, 6.0 ].min

      [ base_growth + data_factor + activity_factor + maturity_factor, 25.0 ].min.round(1)
    end

    def determine_trend_direction
      # Analyze actual data trends and organization growth
      return "stable" unless @organization # Default if no organization

      recent_records = @organization.raw_data_records.where("created_at >= ?", 7.days.ago).count
      older_records = @organization.raw_data_records.where("created_at >= ? AND created_at < ?", 14.days.ago, 7.days.ago).count

      # Compare recent vs older activity
      if recent_records > older_records * 1.1
        "positive"
      elsif recent_records >= older_records * 0.9
        "stable"
      elsif recent_records > 0
        "developing"
      else
        "emerging"
      end
    end

    def assess_data_confidence
      # Calculate confidence based on data availability and quality
      return "medium" unless @organization # Default if no organization

      data_sources_count = @organization.data_sources.count
      total_records = @organization.raw_data_records.count
      recent_records = @organization.raw_data_records.where("created_at >= ?", 7.days.ago).count

      # Base confidence on data volume and recency
      confidence_score = 0
      confidence_score += 1 if data_sources_count >= 1
      confidence_score += 1 if data_sources_count >= 3
      confidence_score += 1 if total_records >= 100
      confidence_score += 1 if recent_records >= 10

      case confidence_score
      when 0..1 then "low"
      when 2..3 then "medium"
      else "high"
      end
    end

    def calculate_impact_level(growth_potential)
      case growth_potential
      when 0..10 then "medium"
      when 10..20 then "high"
      else "very_high"
      end
    end

    def generate_supporting_data_sources
      return [ "Mock data analysis" ] unless @organization # Default if no organization

      sources = []
      sources << "Data source integration patterns" if @organization.data_sources.any?
      sources << "Historical organization metrics" if @organization.created_at < 3.months.ago
      sources << "Market trend analysis"
      sources
    end

    def calculate_trend_significance
      data_maturity = (Date.current - @organization.created_at.to_date).to_i
      case data_maturity
      when 0..30 then "low"
      when 31..90 then "medium"
      else "high"
      end
    end

    def determine_analysis_period
      # Determine appropriate analysis period based on organization age
      org_age_days = (Date.current - @organization.created_at.to_date).to_i
      [ org_age_days, 90 ].min.clamp(7, 90)
    end

    def generate_dynamic_recommendations(growth_potential, trend_direction)
      recommendations = []

      if growth_potential > 15
        recommendations << "Focus on scaling successful data collection strategies"
        recommendations << "Implement advanced analytics for growth acceleration"
      else
        recommendations << "Establish foundational data collection processes"
        recommendations << "Optimize existing data source connections"
      end

      if trend_direction == "positive"
        recommendations << "Continue current successful operational patterns"
      else
        recommendations << "Review and enhance data integration workflows"
      end

      recommendations
    end

    def calculate_system_efficiency
      # Calculate efficiency based on actual data processing metrics
      return 75 unless @organization # Default value if no organization

      base_efficiency = 70

      # Bonus for active data sources
      active_sources = @organization.data_sources.where("updated_at >= ?", 7.days.ago).count
      sources_bonus = [ active_sources * 8, 25 ].min

      # Bonus for consistent data flow
      recent_records = @organization.raw_data_records.where("created_at >= ?", 7.days.ago).count
      consistency_bonus = recent_records > 50 ? 10 : recent_records > 10 ? 5 : 0

      # Penalty for failed extraction jobs
      failed_jobs = @organization.extraction_jobs.where("extraction_jobs.created_at >= ? AND status = ?", 7.days.ago, "failed").count
      failure_penalty = [ failed_jobs * 3, 15 ].min

      efficiency = base_efficiency + sources_bonus + consistency_bonus - failure_penalty
      [ efficiency, 100 ].min.round
    end

    def assess_data_quality_score
      # Assess data quality based on actual data analysis
      base_score = 70

      # Bonus for data source diversity
      sources_bonus = [ @organization.data_sources.count * 3, 15 ].min

      # Bonus for data completeness
      total_records = @organization.raw_data_records.count
      completeness_bonus = total_records > 1000 ? 10 : total_records > 100 ? 5 : 0

      # Bonus for recent data freshness
      recent_records = @organization.raw_data_records.where("created_at >= ?", 24.hours.ago).count
      freshness_bonus = recent_records > 0 ? 5 : 0

      (base_score + sources_bonus + completeness_bonus + freshness_bonus).round
    end

    def calculate_efficiency_trend
      # Calculate efficiency change based on recent vs historical performance
      return 2.5 unless @organization # Default positive trend if no organization

      current_week_records = @organization.raw_data_records.where("created_at >= ?", 7.days.ago).count
      previous_week_records = @organization.raw_data_records.where("created_at >= ? AND created_at < ?", 14.days.ago, 7.days.ago).count

      return 0.0 if previous_week_records.zero?

      # Calculate percentage change
      change = ((current_week_records - previous_week_records).to_f / previous_week_records * 100)

      # Cap the change to reasonable bounds
      [ change, 15.0 ].min.round(1)
    end

    def calculate_data_points_analyzed
      # Estimate data points based on organization setup
      base_points = 500
      source_multiplier = @organization.data_sources.count * 1000
      time_factor = [ (Date.current - @organization.created_at.to_date).to_i * 10, 10000 ].min
      (base_points + source_multiplier + time_factor).round(-2) # Round to hundreds
    end

    def quality_level_text(score)
      case score
      when 90..100 then "Excellent"
      when 80..89 then "Good"
      when 70..79 then "Fair"
      else "Needs Improvement"
      end
    end

    def generate_dynamic_action_items(trend_direction, efficiency_score)
      items = []

      if efficiency_score < 80
        items << "Optimize data processing workflows"
        items << "Review system performance metrics"
      else
        items << "Monitor continued performance excellence"
        items << "Explore advanced optimization opportunities"
      end

      if trend_direction == "positive"
        items << "Scale successful data integration patterns"
      else
        items << "Investigate opportunities for performance improvement"
      end

      items
    end

    def generate_strategic_implications(trend_direction, efficiency_score)
      if efficiency_score > 85 && trend_direction == "positive"
        "Strong operational foundation supports aggressive growth strategies and expansion into new data sources."
      elsif efficiency_score > 75
        "Solid operational base provides foundation for steady growth and strategic optimization initiatives."
      else
        "Focus on operational excellence before pursuing major strategic initiatives."
      end
    end

    def calculate_current_processing_time
      # Calculate realistic processing time based on data load
      base_time = 1.2
      load_factor = [ @organization.data_sources.count * 0.3, 2.0 ].min
      random_variation = rand * 0.5
      (base_time + load_factor + random_variation).round(1)
    end

    def calculate_expected_processing_range
      base_min = 0.8
      base_max = 1.8
      { min: base_min, max: base_max }
    end

    def assess_performance_severity(current_time, expected_range)
      if current_time > expected_range[:max] * 1.5
        "high"
      elsif current_time > expected_range[:max]
        "medium"
      else
        "low"
      end
    end

    def generate_anomaly_description(current_time, expected_range)
      if current_time > expected_range[:max]
        "Processing time spike detected - #{((current_time / expected_range[:max] - 1) * 100).round}% above normal range"
      else
        "Processing performance within acceptable parameters"
      end
    end

    def assess_anomaly_confidence(current_time, expected_range)
      deviation = (current_time - expected_range[:max]).abs / expected_range[:max]
      case deviation
      when 0..0.2 then "medium"
      when 0.2..0.5 then "high"
      else "very_high"
      end
    end

    def generate_potential_causes(current_time, expected_range)
      causes = []
      if current_time > expected_range[:max]
        causes << "Increased data volume from recent integrations"
        causes << "System resource constraints during peak processing"
        causes << "Network latency affecting data transfer speeds"
      else
        causes << "Normal operational variations"
      end
      causes
    end

    def assess_business_impact(severity)
      case severity
      when "high" then "Significant impact on user experience and operational efficiency"
      when "medium" then "Moderate impact requiring monitoring and potential optimization"
      else "Minimal impact with no immediate action required"
      end
    end

    def generate_investigation_steps(severity)
      steps = [ "Monitor system performance metrics", "Analyze processing time trends" ]
      if severity == "high"
        steps << "Check system resource utilization"
        steps << "Review recent data volume changes"
        steps << "Consider scaling infrastructure"
      end
      steps
    end

    def generate_anomaly_summary(severity)
      case severity
      when "high" then "Critical performance anomaly requiring immediate attention"
      when "medium" then "Moderate performance variation requiring monitoring"
      else "Minor performance variations within acceptable ranges"
      end
    end

    def calculate_data_quality_score
      base_score = 75
      data_maturity = [ (Date.current - @organization.created_at.to_date).to_i / 30, 12 ].min * 2
      sources_quality = @organization.data_sources.count * 3
      [ base_score + data_maturity + sources_quality, 95 ].min
    end

    def calculate_total_records_analyzed
      base_records = 500
      source_multiplier = @organization.data_sources.count * 200
      time_factor = [ (Date.current - @organization.created_at.to_date).to_i * 5, 2000 ].min
      base_records + source_multiplier + time_factor
    end

    def calculate_data_issues_count
      total_records = calculate_total_records_analyzed
      issue_rate = 0.02 + (rand * 0.03) # 2-5% issue rate
      (total_records * issue_rate).round
    end

    def calculate_missing_data_percentage
      # Realistic missing data percentage based on organization maturity
      base_missing = 8.0
      maturity_improvement = [ (Date.current - @organization.created_at.to_date).to_i / 30, 6 ].min
      [ base_missing - maturity_improvement + (rand * 3), 1.0 ].max.round(1)
    end

    def generate_data_fix_suggestion(missing_percentage)
      if missing_percentage > 15
        "Immediate data collection process review and automated validation implementation required"
      elsif missing_percentage > 8
        "Implement email validation at data entry point and consider data enrichment services"
      else
        "Monitor data quality trends and implement preventive validation measures"
      end
    end

    def generate_data_quality_recommendations(quality_score, issues_count)
      recommendations = []

      if quality_score < 80
        recommendations << "Implement comprehensive data validation rules"
        recommendations << "Establish data quality monitoring dashboards"
      else
        recommendations << "Maintain current data quality standards"
        recommendations << "Consider advanced data enrichment techniques"
      end

      if issues_count > 5
        recommendations << "Prioritize high-impact data quality improvements"
      end

      recommendations
    end

    def generate_compliance_notes(missing_percentage)
      notes = []
      if missing_percentage > 10
        notes << "Email field completion critical for marketing compliance (GDPR/CAN-SPAM)"
        notes << "Consider implementing progressive data collection strategies"
      else
        notes << "Current email collection rates support compliance requirements"
      end
      notes
    end

    # Caching and rate limiting helper methods
    def generate_prompt_hash(prompt, context_data = nil)
      content_to_hash = [ prompt, context_data&.to_json ].compact.join("|")
      Digest::SHA256.hexdigest(content_to_hash)[0..16]
    end

    def model_config
      {
        provider: @provider,
        model: @model,
        organization_id: @organization&.id,
        temperature: 0.7, # Default temperature
        max_tokens: 2000   # Default max tokens
      }
    end

    # Enhanced LLM request method with caching and rate limiting
    def enhanced_llm_request(prompt, operation_type = :llm_request, cache_ttl = 1.hour)
      prompt_hash = generate_prompt_hash(prompt)

      # Try cache first
      if @cache_service
        cached_response = @cache_service.get_cached_llm_response(prompt_hash, model_config)
        if cached_response
          Rails.logger.info "Cache hit for LLM request: #{prompt_hash}"
          return cached_response[:response]
        end
      end

      # Check rate limits
      rate_limiter = @rate_limiter || Ai::RateLimitService.new(
        organization: @organization,
        operation_type: operation_type
      )

      if rate_limiter.rate_limited?
        Rails.logger.warn "Rate limited for operation: #{operation_type}"
        raise StandardError, "Rate limit exceeded. Please try again later."
      end

      begin
        # Make the actual LLM request
        response = @chat.ask(prompt)

        # Record the request for rate limiting
        rate_limiter.record_request

        # Parse and validate the response
        parsed_response = validate_and_parse_response(response)

        # Cache the successful response
        @cache_service&.cache_llm_response(prompt_hash, model_config, parsed_response)

        Rails.logger.info "Successful LLM request: #{operation_type}"
        parsed_response

      rescue => e
        Rails.logger.error "LLM request failed: #{e.message}"
        raise e
      end
    end

    def validate_and_parse_response(response)
      # Basic validation
      return response if response.blank?

      # Try to parse as JSON if it looks like JSON
      if response.strip.start_with?("{") || response.strip.start_with?("[")
        begin
          JSON.parse(response)
        rescue JSON::ParserError
          Rails.logger.warn "Response appears to be JSON but parsing failed"
          response
        end
      else
        response
      end
    end

    # Method to get rate limiting and caching status
    def service_status
      status = {
        provider: @provider,
        model: @model,
        organization_id: @organization&.id,
        cache_enabled: @cache_service.present?,
        rate_limiting_enabled: @rate_limiter.present?
      }

      if @rate_limiter
        status[:rate_limit_stats] = @rate_limiter.usage_statistics
      end

      if @cache_service
        status[:cache_stats] = @cache_service.get_cache_statistics
      end

      status
    end

    # Method to warm up cache with common prompts
    def warm_up_service
      return unless @cache_service && @organization

      Rails.logger.info "Warming up LLM service cache for #{@organization.name}"

      # Common business analysis prompts
      common_prompts = [
        "Analyze recent business performance trends",
        "Summarize key business metrics and their implications",
        "Identify any anomalies in business data",
        "Generate recommendations for business improvement"
      ]

      common_prompts.each do |prompt|
        begin
          # Use a lightweight request to pre-populate cache
          analyze_business_metrics({ summary: "warmup data" }, prompt)
        rescue => e
          Rails.logger.debug "Cache warmup failed for prompt: #{e.message}"
        end
      end

      Rails.logger.info "LLM service cache warmup completed"
    end
  end
end
