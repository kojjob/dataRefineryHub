# frozen_string_literal: true

module Ai
  class DataIntegrationService
    include ActiveModel::Model

    attr_accessor :organization, :data_source, :sample_data, :integration_config

    SUPPORTED_SOURCE_TYPES = %w[
      api database file csv json xml
      shopify stripe quickbooks google_analytics
      mailchimp zendesk hubspot salesforce
    ].freeze

    COMMON_FIELD_PATTERNS = {
      customer: %w[
        customer_id user_id client_id account_id external_id id
        email email_address contact_email user_email
        first_name firstname fname given_name
        last_name lastname lname surname family_name
        full_name display_name name customer_name
        phone phone_number mobile telephone contact_number
        created_at signup_date registration_date join_date
        updated_at modified_date last_seen last_activity
      ],
      order: %w[
        order_id transaction_id purchase_id sale_id external_id id
        customer_id user_id buyer_id account_id
        total_price total_amount amount value price cost
        tax_amount tax_total taxes tax_rate
        shipping_cost shipping_amount delivery_fee shipping_price
        discount_amount discount_total coupon_amount savings
        created_at order_date purchase_date transaction_date
        status order_status state payment_status fulfillment_status
      ],
      product: %w[
        product_id item_id sku external_id id
        title name product_name display_name item_name
        description product_description item_description details
        price unit_price cost amount value
        category product_category item_category type product_type
        inventory_quantity stock_level quantity_available stock_count
        vendor supplier manufacturer brand
        created_at added_date product_created updated_at modified_date
      ]
    }.freeze

    def initialize(organization:, data_source: nil, sample_data: nil, integration_config: nil)
      @organization = organization
      @data_source = data_source
      @sample_data = sample_data
      @integration_config = integration_config || {}
      @llm_service = Ai::LlmService.new(organization: organization)
    end

    def analyze_data_source(source_type:, connection_params: {}, sample_data: nil)
      # Comprehensive analysis of a potential data source
      Rails.logger.info "Analyzing data source: #{source_type} for #{@organization.name}"

      analysis_result = {
        source_type: source_type,
        connection_validation: validate_connection(source_type, connection_params),
        schema_analysis: analyze_schema(sample_data || fetch_sample_data(source_type, connection_params)),
        field_mapping: generate_intelligent_field_mapping(sample_data),
        data_quality: assess_data_quality(sample_data),
        integration_recommendations: generate_integration_recommendations(source_type, sample_data),
        estimated_complexity: calculate_integration_complexity(source_type, sample_data),
        potential_conflicts: detect_potential_conflicts(sample_data),
        transformation_suggestions: suggest_data_transformations(sample_data),
        sync_strategy: recommend_sync_strategy(source_type, sample_data),
        generated_at: Time.current.iso8601
      }

      # Store analysis for future reference
      store_integration_analysis(analysis_result)

      analysis_result
    end

    def generate_intelligent_field_mapping(sample_data)
      # AI-powered field mapping with confidence scoring
      return {} unless sample_data&.any?

      Rails.logger.info "Generating intelligent field mapping for #{@organization.name}"

      # Extract fields from sample data
      detected_fields = extract_fields_from_sample(sample_data)

      # Generate AI-powered mapping suggestions
      ai_mapping = generate_ai_field_mapping(detected_fields, sample_data)

      # Combine with pattern-based mapping
      pattern_mapping = generate_pattern_based_mapping(detected_fields)

      # Create comprehensive mapping with confidence scores
      field_mapping = {}

      detected_fields.each do |field_name|
        field_mapping[field_name] = {
          original_name: field_name,
          suggested_mappings: combine_mapping_suggestions(field_name, ai_mapping, pattern_mapping),
          confidence_score: calculate_field_confidence(field_name, ai_mapping, pattern_mapping),
          data_type: detect_field_data_type(field_name, sample_data),
          sample_values: extract_sample_values(field_name, sample_data),
          validation_rules: suggest_validation_rules(field_name, sample_data),
          transformation_needed: assess_transformation_needs(field_name, sample_data)
        }
      end

      field_mapping
    end

    def optimize_data_source_configuration(data_source)
      # AI-powered optimization recommendations for existing data sources
      Rails.logger.info "Optimizing data source configuration: #{data_source.name}"

      current_config = analyze_current_configuration(data_source)
      performance_metrics = gather_performance_metrics(data_source)
      data_patterns = analyze_data_patterns(data_source)

      optimization_suggestions = {
        sync_frequency: optimize_sync_frequency(performance_metrics, data_patterns),
        field_mappings: optimize_field_mappings(data_source),
        data_validation: enhance_data_validation(data_source, data_patterns),
        transformation_pipeline: optimize_transformations(data_source, data_patterns),
        conflict_resolution: improve_conflict_resolution(data_source),
        performance_tuning: suggest_performance_improvements(performance_metrics),
        data_quality_improvements: recommend_quality_enhancements(data_source),
        cost_optimization: analyze_cost_efficiency(data_source, performance_metrics)
      }

      # Generate AI insights on optimization impact
      ai_optimization_analysis = @llm_service.analyze_business_metrics(
        optimization_suggestions.merge(current_config),
        "Analyze data source optimization recommendations and estimate impact on data quality, performance, and business value."
      )

      {
        current_performance: current_config,
        optimization_suggestions: optimization_suggestions,
        ai_insights: JSON.parse(ai_optimization_analysis),
        estimated_impact: calculate_optimization_impact(optimization_suggestions),
        implementation_plan: create_optimization_plan(optimization_suggestions),
        generated_at: Time.current.iso8601
      }
    end

    def suggest_new_data_sources
      # AI-powered suggestions for additional data sources based on business context
      Rails.logger.info "Suggesting new data sources for #{@organization.name}"

      current_sources = analyze_current_data_ecosystem
      business_context = build_business_context
      industry_patterns = identify_industry_patterns

      # Generate AI-powered data source recommendations
      recommendation_prompt = build_data_source_recommendation_prompt(current_sources, business_context)
      ai_recommendations = @llm_service.analyze_business_metrics(business_context, recommendation_prompt)

      suggested_sources = {
        high_priority: identify_high_priority_sources(current_sources, business_context),
        complementary: find_complementary_sources(current_sources),
        industry_standard: recommend_industry_standard_sources(industry_patterns),
        advanced_analytics: suggest_advanced_analytics_sources(business_context),
        cost_effective: identify_cost_effective_sources(business_context),
        ai_recommendations: JSON.parse(ai_recommendations)
      }

      # Prioritize and score recommendations
      prioritized_suggestions = prioritize_data_source_suggestions(suggested_sources)

      {
        current_ecosystem: current_sources,
        suggested_sources: prioritized_suggestions,
        integration_roadmap: create_integration_roadmap(prioritized_suggestions),
        business_impact: assess_suggested_sources_impact(prioritized_suggestions),
        implementation_guidance: provide_implementation_guidance(prioritized_suggestions),
        generated_at: Time.current.iso8601
      }
    end

    def validate_data_integration_quality(data_source)
      # Comprehensive quality assessment of integrated data
      Rails.logger.info "Validating data integration quality for #{data_source.name}"

      quality_metrics = {
        completeness: assess_data_completeness(data_source),
        accuracy: evaluate_data_accuracy(data_source),
        consistency: check_data_consistency(data_source),
        timeliness: assess_data_timeliness(data_source),
        validity: validate_data_formats(data_source),
        uniqueness: detect_duplicate_records(data_source),
        integrity: check_referential_integrity(data_source)
      }

      # AI-powered quality insights
      quality_analysis_prompt = build_quality_analysis_prompt(quality_metrics, data_source)
      ai_quality_insights = @llm_service.validate_data_quality(quality_metrics, quality_analysis_prompt)

      overall_score = calculate_overall_quality_score(quality_metrics)

      {
        quality_metrics: quality_metrics,
        overall_score: overall_score,
        quality_grade: determine_quality_grade(overall_score),
        ai_insights: JSON.parse(ai_quality_insights),
        improvement_recommendations: generate_quality_improvements(quality_metrics),
        monitoring_suggestions: suggest_quality_monitoring(data_source),
        automated_fixes: identify_automated_fixes(quality_metrics),
        generated_at: Time.current.iso8601
      }
    end

    private

    def validate_connection(source_type, connection_params)
      # Validate connection to data source
      case source_type
      when "api"
        validate_api_connection(connection_params)
      when "database"
        validate_database_connection(connection_params)
      when "file"
        validate_file_access(connection_params)
      when *%w[shopify stripe quickbooks]
        validate_oauth_connection(source_type, connection_params)
      else
        { status: "unknown", message: "Connection validation not implemented for this source type" }
      end
    end

    def fetch_sample_data(source_type, connection_params)
      # Fetch sample data for analysis
      case source_type
      when "api"
        fetch_api_sample(connection_params)
      when "database"
        fetch_database_sample(connection_params)
      when "file"
        fetch_file_sample(connection_params)
      else
        []
      end
    rescue => e
      Rails.logger.warn "Failed to fetch sample data: #{e.message}"
      []
    end

    def analyze_schema(sample_data)
      return {} unless sample_data&.any?

      # Analyze data structure and schema
      schema_analysis = {
        record_count: sample_data.length,
        fields: extract_field_analysis(sample_data),
        data_types: analyze_data_types(sample_data),
        nested_structures: detect_nested_structures(sample_data),
        array_fields: identify_array_fields(sample_data),
        null_patterns: analyze_null_patterns(sample_data),
        unique_constraints: detect_unique_fields(sample_data),
        relationships: infer_relationships(sample_data)
      }

      schema_analysis
    end

    def assess_data_quality(sample_data)
      return { score: 0, issues: [] } unless sample_data&.any?

      quality_issues = []
      quality_score = 100.0

      # Check for common quality issues
      missing_data_pct = calculate_missing_data_percentage(sample_data)
      if missing_data_pct > 10
        quality_issues << "High missing data rate: #{missing_data_pct.round(1)}%"
        quality_score -= (missing_data_pct * 0.5)
      end

      # Check for duplicate records
      duplicate_pct = calculate_duplicate_percentage(sample_data)
      if duplicate_pct > 5
        quality_issues << "Duplicate records detected: #{duplicate_pct.round(1)}%"
        quality_score -= (duplicate_pct * 0.8)
      end

      # Check data consistency
      consistency_issues = detect_consistency_issues(sample_data)
      if consistency_issues.any?
        quality_issues.concat(consistency_issues)
        quality_score -= (consistency_issues.length * 5)
      end

      {
        score: [ quality_score, 0 ].max.round(1),
        grade: quality_grade(quality_score),
        issues: quality_issues,
        recommendations: generate_quality_recommendations(quality_issues)
      }
    end

    def generate_integration_recommendations(source_type, sample_data)
      recommendations = []

      # Source-specific recommendations
      case source_type
      when "api"
        recommendations << "Implement rate limiting and retry logic for API calls"
        recommendations << "Set up webhook endpoints for real-time updates if available"
      when "database"
        recommendations << "Use incremental sync based on timestamp fields"
        recommendations << "Consider read replicas to minimize impact on source system"
      when "file"
        recommendations << "Implement file validation and backup procedures"
        recommendations << "Set up automated file processing and archival"
      end

      # Data-specific recommendations
      if sample_data&.any?
        field_count = extract_fields_from_sample(sample_data).length
        if field_count > 50
          recommendations << "Consider selective field sync to improve performance"
        end

        if detect_nested_structures(sample_data).any?
          recommendations << "Plan for complex data transformation and flattening"
        end
      end

      recommendations
    end

    def calculate_integration_complexity(source_type, sample_data)
      base_complexity = case source_type
      when "file", "csv" then 1
      when "api", "json" then 2
      when "database" then 3
      when *%w[shopify stripe quickbooks] then 4
      else 3
      end

      if sample_data&.any?
        field_count = extract_fields_from_sample(sample_data).length
        complexity_multiplier = case field_count
        when 0..10 then 1.0
        when 11..25 then 1.2
        when 26..50 then 1.5
        else 2.0
        end

        nested_complexity = detect_nested_structures(sample_data).any? ? 1.3 : 1.0

        base_complexity * complexity_multiplier * nested_complexity
      else
        base_complexity
      end
    end

    def detect_potential_conflicts(sample_data)
      conflicts = []

      return conflicts unless sample_data&.any?

      # Check for ID field conflicts
      existing_id_fields = @organization.data_sources.joins(:raw_data_records)
        .pluck("DISTINCT jsonb_object_keys(data)")
        .select { |key| key.include?("id") }

      new_id_fields = extract_fields_from_sample(sample_data)
        .select { |field| field.include?("id") }

      conflicting_ids = existing_id_fields & new_id_fields
      if conflicting_ids.any?
        conflicts << {
          type: "id_field_conflict",
          fields: conflicting_ids,
          description: "ID fields may conflict with existing data"
        }
      end

      conflicts
    end

    def suggest_data_transformations(sample_data)
      transformations = []

      return transformations unless sample_data&.any?

      fields = extract_fields_from_sample(sample_data)

      fields.each do |field_name|
        sample_values = extract_sample_values(field_name, sample_data)

        # Suggest transformations based on field patterns
        if field_name.match?(/date|time|created|updated/i)
          transformations << {
            field: field_name,
            type: "date_normalization",
            description: "Normalize date format to ISO 8601"
          }
        end

        if field_name.match?(/email/i) && sample_values.any? { |v| v&.include?(" ") }
          transformations << {
            field: field_name,
            type: "email_cleaning",
            description: "Clean and validate email addresses"
          }
        end

        if field_name.match?(/price|amount|cost|total/i)
          transformations << {
            field: field_name,
            type: "currency_normalization",
            description: "Normalize currency values to consistent format"
          }
        end
      end

      transformations
    end

    def recommend_sync_strategy(source_type, sample_data)
      strategy = {
        type: "full_sync",
        frequency: "daily",
        incremental_field: nil,
        batch_size: 1000,
        priority: "medium"
      }

      # Adjust based on source type
      case source_type
      when "api"
        strategy[:type] = "incremental"
        strategy[:frequency] = "hourly"
        strategy[:batch_size] = 500
      when "database"
        strategy[:type] = "incremental"
        strategy[:frequency] = "6_hourly"
        strategy[:batch_size] = 2000
      when "file"
        strategy[:type] = "full_sync"
        strategy[:frequency] = "daily"
      end

      # Detect incremental sync fields
      if sample_data&.any?
        timestamp_fields = extract_fields_from_sample(sample_data)
          .select { |f| f.match?(/updated|modified|changed|timestamp/i) }

        if timestamp_fields.any?
          strategy[:type] = "incremental"
          strategy[:incremental_field] = timestamp_fields.first
          strategy[:frequency] = "hourly"
        end
      end

      strategy
    end

    # Helper methods for field mapping and analysis

    def extract_fields_from_sample(sample_data)
      fields = Set.new
      sample_data.first(5).each do |record|
        extract_fields_recursively(record, fields)
      end
      fields.to_a
    end

    def extract_fields_recursively(data, fields, prefix = "")
      return unless data.is_a?(Hash)

      data.each do |key, value|
        field_name = prefix.present? ? "#{prefix}.#{key}" : key
        fields << field_name

        if value.is_a?(Hash)
          extract_fields_recursively(value, fields, field_name)
        elsif value.is_a?(Array) && value.first.is_a?(Hash)
          extract_fields_recursively(value.first, fields, "#{field_name}[]")
        end
      end
    end

    def generate_ai_field_mapping(detected_fields, sample_data)
      # Use AI to suggest field mappings
      mapping_prompt = build_field_mapping_prompt(detected_fields, sample_data)
      ai_response = @llm_service.analyze_business_metrics(
        { fields: detected_fields, sample_data: sample_data.first(3) },
        mapping_prompt
      )

      begin
        JSON.parse(ai_response)
      rescue JSON::ParserError
        {}
      end
    end

    def generate_pattern_based_mapping(detected_fields)
      mapping = {}

      detected_fields.each do |field_name|
        COMMON_FIELD_PATTERNS.each do |record_type, patterns|
          patterns.each do |pattern|
            if field_name.downcase.include?(pattern.downcase) ||
               pattern.downcase.include?(field_name.downcase)
              mapping[field_name] ||= []
              mapping[field_name] << {
                target_field: pattern,
                record_type: record_type,
                confidence: calculate_pattern_confidence(field_name, pattern)
              }
            end
          end
        end
      end

      mapping
    end

    def combine_mapping_suggestions(field_name, ai_mapping, pattern_mapping)
      suggestions = []

      # Add AI suggestions
      if ai_mapping[field_name]
        suggestions.concat(ai_mapping[field_name])
      end

      # Add pattern-based suggestions
      if pattern_mapping[field_name]
        suggestions.concat(pattern_mapping[field_name])
      end

      # Remove duplicates and sort by confidence
      suggestions.uniq { |s| s[:target_field] }
                .sort_by { |s| -(s[:confidence] || 0) }
                .first(3)
    end

    def calculate_field_confidence(field_name, ai_mapping, pattern_mapping)
      ai_confidence = ai_mapping[field_name]&.first&.dig(:confidence) || 0
      pattern_confidence = pattern_mapping[field_name]&.first&.dig(:confidence) || 0

      # Weighted average favoring AI analysis
      (ai_confidence * 0.7 + pattern_confidence * 0.3).round(2)
    end

    def calculate_pattern_confidence(field_name, pattern)
      # Calculate confidence based on string similarity
      field_clean = field_name.downcase.gsub(/[^a-z]/, "")
      pattern_clean = pattern.downcase.gsub(/[^a-z]/, "")

      if field_clean == pattern_clean
        0.95
      elsif field_clean.include?(pattern_clean) || pattern_clean.include?(field_clean)
        0.8
      elsif field_clean.start_with?(pattern_clean) || pattern_clean.start_with?(field_clean)
        0.7
      else
        0.5
      end
    end

    # Placeholder methods for complex operations

    def store_integration_analysis(analysis); Rails.logger.info "Storing integration analysis"; end
    def analyze_current_configuration(data_source); {}; end
    def gather_performance_metrics(data_source); {}; end
    def analyze_data_patterns(data_source); {}; end
    def optimize_sync_frequency(metrics, patterns); "hourly"; end
    def optimize_field_mappings(data_source); []; end
    def enhance_data_validation(data_source, patterns); []; end
    def optimize_transformations(data_source, patterns); []; end
    def improve_conflict_resolution(data_source); []; end
    def suggest_performance_improvements(metrics); []; end
    def recommend_quality_enhancements(data_source); []; end
    def analyze_cost_efficiency(data_source, metrics); {}; end
    def calculate_optimization_impact(suggestions); {}; end
    def create_optimization_plan(suggestions); []; end
    def analyze_current_data_ecosystem; {}; end
    def build_business_context; {}; end
    def identify_industry_patterns; {}; end
    def build_data_source_recommendation_prompt(sources, context); "Recommend data sources"; end
    def identify_high_priority_sources(sources, context); []; end
    def find_complementary_sources(sources); []; end
    def recommend_industry_standard_sources(patterns); []; end
    def suggest_advanced_analytics_sources(context); []; end
    def identify_cost_effective_sources(context); []; end
    def prioritize_data_source_suggestions(suggestions); suggestions; end
    def create_integration_roadmap(suggestions); []; end
    def assess_suggested_sources_impact(suggestions); {}; end
    def provide_implementation_guidance(suggestions); []; end
    def assess_data_completeness(data_source); 85.0; end
    def evaluate_data_accuracy(data_source); 90.0; end
    def check_data_consistency(data_source); 88.0; end
    def assess_data_timeliness(data_source); 92.0; end
    def validate_data_formats(data_source); 95.0; end
    def detect_duplicate_records(data_source); 2.5; end
    def check_referential_integrity(data_source); 87.0; end
    def build_quality_analysis_prompt(metrics, data_source); "Analyze data quality"; end
    def calculate_overall_quality_score(metrics); metrics.values.sum / metrics.length; end
    def determine_quality_grade(score); score > 90 ? "A" : score > 80 ? "B" : score > 70 ? "C" : "D"; end
    def generate_quality_improvements(metrics); []; end
    def suggest_quality_monitoring(data_source); []; end
    def identify_automated_fixes(metrics); []; end
    def validate_api_connection(params); { status: "success", message: "API connection valid" }; end
    def validate_database_connection(params); { status: "success", message: "Database connection valid" }; end
    def validate_file_access(params); { status: "success", message: "File access valid" }; end
    def validate_oauth_connection(type, params); { status: "success", message: "#{type.humanize} OAuth valid" }; end
    def fetch_api_sample(params); []; end
    def fetch_database_sample(params); []; end
    def fetch_file_sample(params); []; end
    def extract_field_analysis(data); {}; end
    def analyze_data_types(data); {}; end
    def detect_nested_structures(data); []; end
    def identify_array_fields(data); []; end
    def analyze_null_patterns(data); {}; end
    def detect_unique_fields(data); []; end
    def infer_relationships(data); []; end
    def calculate_missing_data_percentage(data); 5.0; end
    def calculate_duplicate_percentage(data); 2.0; end
    def detect_consistency_issues(data); []; end
    def quality_grade(score); score > 90 ? "Excellent" : score > 80 ? "Good" : score > 70 ? "Fair" : "Poor"; end
    def generate_quality_recommendations(issues); [ "Implement data validation", "Add data cleaning pipeline" ]; end
    def detect_field_data_type(field, data); "string"; end
    def extract_sample_values(field, data); []; end
    def suggest_validation_rules(field, data); []; end
    def assess_transformation_needs(field, data); false; end
    def build_field_mapping_prompt(fields, data); "Analyze field mappings for data integration"; end
  end
end
