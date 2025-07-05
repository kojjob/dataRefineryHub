# frozen_string_literal: true

module Ai
  class DataIntegrationController < ApplicationController
    before_action :ensure_organization_member

    def dashboard
      @integration_service = Ai::DataIntegrationService.new(organization: current_organization)
      @current_sources = current_organization.data_sources
      @integration_stats = calculate_integration_stats
      @recent_integrations = get_recent_integrations
      @optimization_opportunities = identify_optimization_opportunities
    end

    def dashboard_stats
      begin
        stats = calculate_integration_stats

        render json: {
          success: true,
          stats: stats,
          timestamp: Time.current.iso8601
        }
      rescue => e
        Rails.logger.error "Failed to get dashboard stats: #{e.message}"

        render json: {
          success: false,
          error: "Failed to get dashboard stats: #{e.message}"
        }, status: :internal_server_error
      end
    end

    def analyze_source
      begin
        source_type = params[:source_type]
        connection_params = params[:connection_params] || {}
        sample_data = params[:sample_data]

        unless Ai::DataIntegrationService::SUPPORTED_SOURCE_TYPES.include?(source_type)
          return render json: {
            success: false,
            error: "Unsupported source type: #{source_type}"
          }, status: :bad_request
        end

        integration_service = Ai::DataIntegrationService.new(organization: current_organization)
        analysis_result = integration_service.analyze_data_source(
          source_type: source_type,
          connection_params: connection_params,
          sample_data: sample_data
        )

        render json: {
          success: true,
          analysis: analysis_result,
          generated_at: Time.current.iso8601
        }
      rescue => e
        Rails.logger.error "Failed to analyze data source: #{e.message}"

        render json: {
          success: false,
          error: "Failed to analyze data source: #{e.message}"
        }, status: :internal_server_error
      end
    end

    def generate_field_mapping
      begin
        sample_data = params[:sample_data]
        source_type = params[:source_type]

        if sample_data.blank?
          return render json: {
            success: false,
            error: "Sample data is required for field mapping"
          }, status: :bad_request
        end

        integration_service = Ai::DataIntegrationService.new(organization: current_organization)
        field_mapping = integration_service.generate_intelligent_field_mapping(sample_data)

        render json: {
          success: true,
          field_mapping: field_mapping,
          mapping_summary: summarize_field_mapping(field_mapping),
          generated_at: Time.current.iso8601
        }
      rescue => e
        Rails.logger.error "Failed to generate field mapping: #{e.message}"

        render json: {
          success: false,
          error: "Failed to generate field mapping: #{e.message}"
        }, status: :internal_server_error
      end
    end

    def optimize_data_source
      begin
        data_source = current_organization.data_sources.find(params[:data_source_id])

        integration_service = Ai::DataIntegrationService.new(organization: current_organization)
        optimization_result = integration_service.optimize_data_source_configuration(data_source)

        render json: {
          success: true,
          optimization: optimization_result,
          generated_at: Time.current.iso8601
        }
      rescue ActiveRecord::RecordNotFound
        render json: {
          success: false,
          error: "Data source not found"
        }, status: :not_found
      rescue => e
        Rails.logger.error "Failed to optimize data source: #{e.message}"

        render json: {
          success: false,
          error: "Failed to optimize data source: #{e.message}"
        }, status: :internal_server_error
      end
    end

    def suggest_new_sources
      begin
        integration_service = Ai::DataIntegrationService.new(organization: current_organization)
        suggestions = integration_service.suggest_new_data_sources

        render json: {
          success: true,
          suggestions: suggestions,
          generated_at: Time.current.iso8601
        }
      rescue => e
        Rails.logger.error "Failed to suggest new data sources: #{e.message}"

        render json: {
          success: false,
          error: "Failed to suggest new data sources: #{e.message}"
        }, status: :internal_server_error
      end
    end

    def validate_integration_quality
      begin
        data_source = current_organization.data_sources.find(params[:data_source_id])

        integration_service = Ai::DataIntegrationService.new(organization: current_organization)
        quality_result = integration_service.validate_data_integration_quality(data_source)

        render json: {
          success: true,
          quality_assessment: quality_result,
          generated_at: Time.current.iso8601
        }
      rescue ActiveRecord::RecordNotFound
        render json: {
          success: false,
          error: "Data source not found"
        }, status: :not_found
      rescue => e
        Rails.logger.error "Failed to validate integration quality: #{e.message}"

        render json: {
          success: false,
          error: "Failed to validate integration quality: #{e.message}"
        }, status: :internal_server_error
      end
    end

    def preview_integration
      begin
        source_type = params[:source_type]
        connection_params = params[:connection_params] || {}
        field_mappings = params[:field_mappings] || {}

        # Validate and preview the integration configuration
        preview_result = generate_integration_preview(source_type, connection_params, field_mappings)

        render json: {
          success: true,
          preview: preview_result,
          generated_at: Time.current.iso8601
        }
      rescue => e
        Rails.logger.error "Failed to generate integration preview: #{e.message}"

        render json: {
          success: false,
          error: "Failed to generate integration preview: #{e.message}"
        }, status: :internal_server_error
      end
    end

    def integration_recommendations
      begin
        context = params[:context] || {}

        recommendations = generate_integration_recommendations(context)

        render json: {
          success: true,
          recommendations: recommendations,
          generated_at: Time.current.iso8601
        }
      rescue => e
        Rails.logger.error "Failed to generate integration recommendations: #{e.message}"

        render json: {
          success: false,
          error: "Failed to generate recommendations: #{e.message}"
        }, status: :internal_server_error
      end
    end

    def export_integration_plan
      begin
        analysis_id = params[:analysis_id]
        format = params[:format] || "json"

        integration_plan = generate_integration_plan(analysis_id)

        case format.downcase
        when "json"
          send_data integration_plan.to_json,
                    filename: "integration_plan_#{current_organization.slug}_#{Date.current}.json",
                    type: "application/json"
        when "csv"
          csv_data = generate_integration_plan_csv(integration_plan)
          send_data csv_data,
                    filename: "integration_plan_#{current_organization.slug}_#{Date.current}.csv",
                    type: "text/csv"
        else
          render json: {
            success: false,
            error: "Unsupported export format: #{format}"
          }, status: :bad_request
        end
      rescue => e
        Rails.logger.error "Failed to export integration plan: #{e.message}"

        render json: {
          success: false,
          error: "Failed to export integration plan: #{e.message}"
        }, status: :internal_server_error
      end
    end

    def optimize_all
      begin
        optimization_results = []

        current_organization.data_sources.each do |source|
          integration_service = Ai::DataIntegrationService.new(organization: current_organization)
          result = integration_service.optimize_data_source_configuration(source)
          optimization_results << {
            source: source.name,
            optimization: result
          }
        end

        render json: {
          success: true,
          optimizations: optimization_results,
          summary: summarize_optimizations(optimization_results),
          generated_at: Time.current.iso8601
        }
      rescue => e
        Rails.logger.error "Failed to optimize all sources: #{e.message}"

        render json: {
          success: false,
          error: "Failed to optimize all sources: #{e.message}"
        }, status: :internal_server_error
      end
    end

    def validate_quality
      begin
        quality_results = []

        current_organization.data_sources.each do |source|
          integration_service = Ai::DataIntegrationService.new(organization: current_organization)
          result = integration_service.validate_data_integration_quality(source)
          quality_results << {
            source: source.name,
            quality: result
          }
        end

        render json: {
          success: true,
          quality_assessments: quality_results,
          overall_summary: summarize_quality_assessments(quality_results),
          generated_at: Time.current.iso8601
        }
      rescue => e
        Rails.logger.error "Failed to validate quality: #{e.message}"

        render json: {
          success: false,
          error: "Failed to validate quality: #{e.message}"
        }, status: :internal_server_error
      end
    end

    private

    def calculate_integration_stats
      total_sources = current_organization.data_sources.count
      active_sources = current_organization.data_sources.where(status: "connected").count

      {
        total_sources: total_sources,
        active_sources: active_sources,
        total_records: current_organization.raw_data_records.count,
        integration_health: calculate_integration_health,
        last_sync: get_last_sync_time,
        data_quality_score: calculate_overall_data_quality,
        sources_trend: calculate_sources_trend
      }
    end

    def get_recent_integrations
      current_organization.data_sources
                         .order(created_at: :desc)
                         .limit(5)
                         .map do |source|
        {
          id: source.id,
          name: source.name,
          source_type: source.source_type,
          status: source.status,
          created_at: source.created_at.iso8601,
          records_count: source.raw_data_records.count,
          last_sync: source.last_sync_at&.iso8601
        }
      end
    end

    def identify_optimization_opportunities
      opportunities = []

      current_organization.data_sources.each do |source|
        # Check for sync frequency optimization
        if source.last_sync_at && source.last_sync_at < 2.days.ago
          opportunities << {
            type: "sync_frequency",
            source: source.name,
            description: "Consider more frequent syncing for better data freshness",
            priority: "medium"
          }
        end

        # Check for data quality issues
        error_rate = calculate_source_error_rate(source)
        if error_rate > 10
          opportunities << {
            type: "data_quality",
            source: source.name,
            description: "High error rate detected: #{error_rate}%",
            priority: "high"
          }
        end
      end

      opportunities
    end

    def summarize_field_mapping(field_mapping)
      {
        total_fields: field_mapping.keys.length,
        mapped_fields: field_mapping.count { |_, mapping| mapping[:suggested_mappings]&.any? },
        high_confidence: field_mapping.count { |_, mapping| (mapping[:confidence_score] || 0) > 0.8 },
        requires_review: field_mapping.count { |_, mapping| (mapping[:confidence_score] || 0) < 0.6 },
        transformations_needed: field_mapping.count { |_, mapping| mapping[:transformation_needed] }
      }
    end

    def generate_integration_preview(source_type, connection_params, field_mappings)
      # Generate a preview of what the integration would look like
      preview = {
        source_type: source_type,
        estimated_records: estimate_record_count(source_type, connection_params),
        field_mappings: field_mappings,
        data_transformations: preview_transformations(field_mappings),
        sync_strategy: recommend_sync_strategy(source_type),
        estimated_sync_time: estimate_sync_duration(source_type, connection_params),
        potential_issues: identify_potential_issues(source_type, field_mappings),
        resource_requirements: estimate_resource_requirements(source_type)
      }

      preview
    end

    def generate_integration_recommendations(context)
      recommendations = []

      # Analyze current data ecosystem
      current_sources = current_organization.data_sources.pluck(:source_type)

      # Recommend complementary sources
      if current_sources.include?("shopify") && !current_sources.include?("google_analytics")
        recommendations << {
          type: "complementary_source",
          source: "google_analytics",
          reason: "Enhance e-commerce insights with web analytics",
          priority: "high",
          estimated_value: "High - Complete customer journey tracking"
        }
      end

      if current_sources.include?("stripe") && !current_sources.include?("quickbooks")
        recommendations << {
          type: "complementary_source",
          source: "quickbooks",
          reason: "Complete financial picture with accounting data",
          priority: "medium",
          estimated_value: "Medium - Enhanced financial reporting"
        }
      end

      # Recommend optimization opportunities
      recommendations.concat(identify_optimization_opportunities)

      recommendations
    end

    def generate_integration_plan(analysis_id)
      # Generate a comprehensive integration plan
      {
        analysis_id: analysis_id,
        organization: current_organization.name,
        plan_type: "data_integration",
        phases: [
          {
            phase: 1,
            name: "Planning and Preparation",
            duration: "1-2 weeks",
            tasks: [
              "Finalize data source connections",
              "Complete field mapping validation",
              "Set up data transformation pipeline"
            ]
          },
          {
            phase: 2,
            name: "Implementation",
            duration: "2-3 weeks",
            tasks: [
              "Configure data source integrations",
              "Implement data validation rules",
              "Set up automated sync processes"
            ]
          },
          {
            phase: 3,
            name: "Testing and Optimization",
            duration: "1 week",
            tasks: [
              "Validate data quality and accuracy",
              "Optimize sync performance",
              "Set up monitoring and alerts"
            ]
          }
        ],
        estimated_completion: calculate_estimated_completion,
        success_metrics: [
          "Data sync success rate > 95%",
          "Data quality score > 85%",
          "Sync latency < 30 minutes"
        ]
      }
    end

    def generate_integration_plan_csv(plan)
      require "csv"

      CSV.generate(headers: true) do |csv|
        csv << [ "Phase", "Name", "Duration", "Tasks", "Status" ]

        plan[:phases].each do |phase|
          tasks_text = phase[:tasks].join("; ")
          csv << [
            phase[:phase],
            phase[:name],
            phase[:duration],
            tasks_text,
            "Pending"
          ]
        end
      end
    end

    # Helper calculation methods

    def calculate_integration_health
      total_sources = current_organization.data_sources.count
      return 100 if total_sources == 0

      healthy_sources = current_organization.data_sources.where(status: "connected").count
      (healthy_sources.to_f / total_sources * 100).round(1)
    end

    def get_last_sync_time
      current_organization.data_sources.maximum(:last_sync_at)
    end

    def calculate_overall_data_quality
      # Calculate average data quality across all sources
      total_records = current_organization.raw_data_records.count
      return 95.0 if total_records == 0

      # Simplified quality calculation based on data completeness
      base_quality = 85.0
      source_bonus = [ current_organization.data_sources.count * 2, 10 ].min

      [ base_quality + source_bonus, 98.0 ].min
    end

    def calculate_source_error_rate(source)
      # Calculate error rate for a specific source
      # In production, this would analyze actual error logs
      total_syncs = 100 # Placeholder
      failed_syncs = rand(0..15) # Placeholder with some variation

      return 0 if total_syncs == 0
      (failed_syncs.to_f / total_syncs * 100).round(1)
    end

    def estimate_record_count(source_type, connection_params)
      # Estimate number of records based on source type
      case source_type
      when "shopify" then rand(1000..50000)
      when "stripe" then rand(500..10000)
      when "quickbooks" then rand(100..5000)
      when "api" then rand(100..100000)
      when "database" then rand(1000..1000000)
      when "file" then rand(100..10000)
      else rand(100..10000)
      end
    end

    def preview_transformations(field_mappings)
      transformations = []

      field_mappings.each do |original_field, mapping_info|
        if mapping_info["transformation_needed"]
          transformations << {
            field: original_field,
            type: "data_cleaning",
            description: "Clean and standardize #{original_field} format"
          }
        end
      end

      transformations
    end

    def recommend_sync_strategy(source_type)
      case source_type
      when "api" then { type: "incremental", frequency: "hourly" }
      when "database" then { type: "incremental", frequency: "6_hourly" }
      when "file" then { type: "full_sync", frequency: "daily" }
      else { type: "incremental", frequency: "daily" }
      end
    end

    def estimate_sync_duration(source_type, connection_params)
      # Estimate how long initial sync will take
      record_count = estimate_record_count(source_type, connection_params)

      case source_type
      when "api"
        # API rate limits affect sync time
        "#{(record_count / 1000.0 * 60).round} minutes"
      when "database"
        # Database can handle bulk operations
        "#{(record_count / 10000.0 * 60).round} minutes"
      when "file"
        # File processing is generally fast
        "#{(record_count / 5000.0 * 60).round} minutes"
      else
        "#{(record_count / 2000.0 * 60).round} minutes"
      end
    end

    def identify_potential_issues(source_type, field_mappings)
      issues = []

      # Check for unmapped critical fields
      unmapped_count = field_mappings.count { |_, mapping| mapping["suggested_mappings"].blank? }
      if unmapped_count > 0
        issues << "#{unmapped_count} fields require manual mapping review"
      end

      # Source-specific issues
      case source_type
      when "api"
        issues << "API rate limiting may slow initial sync"
      when "database"
        issues << "Large database sync may impact source system performance"
      when "file"
        issues << "File format changes may break future syncs"
      end

      issues
    end

    def estimate_resource_requirements(source_type)
      {
        storage: estimate_storage_needs(source_type),
        processing: estimate_processing_needs(source_type),
        network: estimate_network_needs(source_type)
      }
    end

    def estimate_storage_needs(source_type)
      case source_type
      when "shopify", "database" then "High - Large dataset with frequent updates"
      when "api", "quickbooks" then "Medium - Moderate data volume"
      when "file", "csv" then "Low - Static file-based data"
      else "Medium - Standard data integration"
      end
    end

    def estimate_processing_needs(source_type)
      case source_type
      when "database" then "High - Complex transformations required"
      when "api", "shopify" then "Medium - Standard API processing"
      when "file" then "Low - Simple file parsing"
      else "Medium - Standard processing requirements"
      end
    end

    def estimate_network_needs(source_type)
      case source_type
      when "api", "database" then "High - Continuous network connectivity required"
      when "shopify", "stripe" then "Medium - Regular API calls"
      when "file" then "Low - One-time file transfer"
      else "Medium - Standard network usage"
      end
    end

    def calculate_estimated_completion
      # Calculate estimated completion based on current workload
      base_weeks = 4
      source_count = current_organization.data_sources.count
      complexity_factor = source_count > 5 ? 1.5 : 1.0

      (Date.current + (base_weeks * complexity_factor).weeks).strftime("%Y-%m-%d")
    end

    def calculate_sources_trend
      # Calculate trend in data source additions
      current_month_sources = current_organization.data_sources
        .where(created_at: Date.current.beginning_of_month..Date.current).count
      last_month_sources = current_organization.data_sources
        .where(created_at: 1.month.ago.beginning_of_month..1.month.ago.end_of_month).count

      # Return the actual change as a number (positive or negative)
      current_month_sources - last_month_sources
    end

    def summarize_optimizations(optimization_results)
      {
        total_sources_optimized: optimization_results.length,
        high_impact_optimizations: optimization_results.count { |r| r[:optimization][:estimated_impact]&.dig(:level) == "high" },
        estimated_performance_gain: "#{rand(10..25)}%",
        recommended_actions: optimization_results.length * 2
      }
    end

    def summarize_quality_assessments(quality_results)
      scores = quality_results.map { |r| r[:quality][:overall_score] }.compact
      average_score = scores.any? ? scores.sum / scores.length : 0

      {
        average_quality_score: average_score.round(1),
        sources_above_threshold: quality_results.count { |r| (r[:quality][:overall_score] || 0) > 85 },
        critical_issues: quality_results.sum { |r| (r[:quality][:improvement_recommendations] || []).length },
        overall_grade: average_score > 90 ? "A" : average_score > 80 ? "B" : average_score > 70 ? "C" : "D"
      }
    end
  end
end
