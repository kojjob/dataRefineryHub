# frozen_string_literal: true

module Ai
  class MonitoringController < ApplicationController
    before_action :ensure_organization_member
    before_action :require_admin_access, except: [:dashboard, :performance_stats]
    
    def dashboard
      @monitoring_stats = get_monitoring_overview
      @performance_metrics = get_performance_metrics
      @recent_activities = get_recent_ai_activities
      @system_health = get_system_health_status
      @cost_analysis = get_cost_analysis
    end
    
    def performance_stats
      begin
        time_range = params[:time_range] || '24h'
        
        stats = {
          ai_requests: get_ai_request_statistics(time_range),
          cache_performance: get_cache_performance(time_range),
          rate_limiting: get_rate_limiting_statistics(time_range),
          error_rates: get_error_rate_statistics(time_range),
          response_times: get_response_time_statistics(time_range),
          cost_metrics: get_cost_metrics(time_range)
        }
        
        render json: {
          success: true,
          stats: stats,
          time_range: time_range,
          generated_at: Time.current.iso8601
        }
      rescue => e
        Rails.logger.error "Failed to get performance stats: #{e.message}"
        
        render json: {
          success: false,
          error: "Failed to get performance stats: #{e.message}"
        }, status: :internal_server_error
      end
    end
    
    def cache_statistics
      begin
        cache_service = Ai::CacheService.new(organization: current_organization)
        stats = cache_service.get_cache_statistics
        
        render json: {
          success: true,
          cache_stats: stats,
          recommendations: generate_cache_recommendations(stats),
          generated_at: Time.current.iso8601
        }
      rescue => e
        Rails.logger.error "Failed to get cache statistics: #{e.message}"
        
        render json: {
          success: false,
          error: "Failed to get cache statistics: #{e.message}"
        }, status: :internal_server_error
      end
    end
    
    def rate_limit_status
      begin
        rate_limiter = Ai::RateLimitService.new(
          organization: current_organization,
          operation_type: params[:operation_type] || :llm_request
        )
        
        status = {
          usage_statistics: rate_limiter.usage_statistics,
          organization_summary: rate_limiter.organization_usage_summary,
          approaching_limits: rate_limiter.approaching_limits?,
          exceeded_monthly_limit: rate_limiter.exceeded_monthly_limit?
        }
        
        render json: {
          success: true,
          rate_limit_status: status,
          generated_at: Time.current.iso8601
        }
      rescue => e
        Rails.logger.error "Failed to get rate limit status: #{e.message}"
        
        render json: {
          success: false,
          error: "Failed to get rate limit status: #{e.message}"
        }, status: :internal_server_error
      end
    end
    
    def job_monitoring
      begin
        job_stats = {
          active_jobs: get_active_ai_jobs,
          recent_completions: get_recent_job_completions,
          failure_rates: get_job_failure_rates,
          queue_health: get_queue_health_status,
          performance_trends: get_job_performance_trends
        }
        
        render json: {
          success: true,
          job_monitoring: job_stats,
          generated_at: Time.current.iso8601
        }
      rescue => e
        Rails.logger.error "Failed to get job monitoring data: #{e.message}"
        
        render json: {
          success: false,
          error: "Failed to get job monitoring data: #{e.message}"
        }, status: :internal_server_error
      end
    end
    
    def system_health
      begin
        health_status = {
          overall_status: calculate_overall_health,
          ai_services: check_ai_services_health,
          cache_health: check_cache_health,
          database_health: check_database_health,
          external_apis: check_external_api_health,
          queue_health: check_queue_health
        }
        
        render json: {
          success: true,
          system_health: health_status,
          alerts: generate_health_alerts(health_status),
          generated_at: Time.current.iso8601
        }
      rescue => e
        Rails.logger.error "Failed to get system health: #{e.message}"
        
        render json: {
          success: false,
          error: "Failed to get system health: #{e.message}"
        }, status: :internal_server_error
      end
    end
    
    def cost_analysis
      begin
        time_period = params[:period] || 'month'
        
        analysis = {
          current_costs: get_current_period_costs(time_period),
          cost_breakdown: get_cost_breakdown_by_service(time_period),
          trends: get_cost_trends(time_period),
          projections: get_cost_projections,
          optimization_opportunities: identify_cost_optimizations,
          budget_status: get_budget_status
        }
        
        render json: {
          success: true,
          cost_analysis: analysis,
          period: time_period,
          generated_at: Time.current.iso8601
        }
      rescue => e
        Rails.logger.error "Failed to get cost analysis: #{e.message}"
        
        render json: {
          success: false,
          error: "Failed to get cost analysis: #{e.message}"
        }, status: :internal_server_error
      end
    end
    
    def optimization_recommendations
      begin
        recommendations = {
          performance: get_performance_recommendations,
          cost: get_cost_optimization_recommendations,
          cache: get_cache_optimization_recommendations,
          rate_limiting: get_rate_limiting_recommendations,
          security: get_security_recommendations
        }
        
        # Prioritize recommendations by impact
        prioritized = prioritize_recommendations(recommendations)
        
        render json: {
          success: true,
          recommendations: prioritized,
          implementation_guide: generate_implementation_guide(prioritized),
          generated_at: Time.current.iso8601
        }
      rescue => e
        Rails.logger.error "Failed to get optimization recommendations: #{e.message}"
        
        render json: {
          success: false,
          error: "Failed to get optimization recommendations: #{e.message}"
        }, status: :internal_server_error
      end
    end
    
    def warm_up_caches
      begin
        return render_unauthorized unless current_user.admin?
        
        # Warm up AI service caches
        cache_service = Ai::CacheService.new(organization: current_organization)
        cache_service.warm_up_cache
        
        # Warm up LLM service cache
        llm_service = Ai::LlmService.new(organization: current_organization)
        llm_service.warm_up_service
        
        render json: {
          success: true,
          message: "Cache warm-up initiated successfully",
          estimated_completion: 5.minutes.from_now.iso8601
        }
      rescue => e
        Rails.logger.error "Failed to warm up caches: #{e.message}"
        
        render json: {
          success: false,
          error: "Failed to warm up caches: #{e.message}"
        }, status: :internal_server_error
      end
    end
    
    def clear_caches
      begin
        return render_unauthorized unless current_user.admin?
        
        cache_pattern = params[:pattern] || :organization_data
        
        cache_service = Ai::CacheService.new(organization: current_organization)
        cache_service.invalidate_cache(cache_pattern.to_sym)
        
        render json: {
          success: true,
          message: "Cache cleared successfully",
          pattern: cache_pattern
        }
      rescue => e
        Rails.logger.error "Failed to clear caches: #{e.message}"
        
        render json: {
          success: false,
          error: "Failed to clear caches: #{e.message}"
        }, status: :internal_server_error
      end
    end
    
    def export_monitoring_data
      begin
        return render_unauthorized unless current_user.admin?
        
        format = params[:format] || 'json'
        time_range = params[:time_range] || '7d'
        
        monitoring_data = compile_monitoring_export_data(time_range)
        
        case format.downcase
        when 'json'
          send_data monitoring_data.to_json,
                    filename: "ai_monitoring_#{current_organization.slug}_#{Date.current}.json",
                    type: 'application/json'
        when 'csv'
          csv_data = convert_monitoring_data_to_csv(monitoring_data)
          send_data csv_data,
                    filename: "ai_monitoring_#{current_organization.slug}_#{Date.current}.csv",
                    type: 'text/csv'
        else
          render json: {
            success: false,
            error: "Unsupported export format: #{format}"
          }, status: :bad_request
        end
      rescue => e
        Rails.logger.error "Failed to export monitoring data: #{e.message}"
        
        render json: {
          success: false,
          error: "Failed to export monitoring data: #{e.message}"
        }, status: :internal_server_error
      end
    end
    
    private
    
    def require_admin_access
      unless current_user.admin? || current_user.organization_owner?(current_organization)
        render json: {
          success: false,
          error: "Admin access required"
        }, status: :forbidden
      end
    end
    
    def render_unauthorized
      render json: {
        success: false,
        error: "Unauthorized access"
      }, status: :unauthorized
    end
    
    def get_monitoring_overview
      {
        total_ai_requests_today: get_daily_request_count,
        total_cost_today: get_daily_cost,
        cache_hit_rate: get_overall_cache_hit_rate,
        average_response_time: get_average_response_time,
        error_rate: get_error_rate_percentage,
        active_ai_jobs: get_active_job_count,
        system_health_score: calculate_system_health_score
      }
    end
    
    def get_performance_metrics
      {
        request_volume_trend: get_request_volume_trend,
        response_time_trend: get_response_time_trend,
        error_rate_trend: get_error_rate_trend,
        cache_performance_trend: get_cache_performance_trend,
        cost_trend: get_cost_trend
      }
    end
    
    def get_recent_ai_activities
      activities = []
      
      # Get recent AI requests
      recent_requests = get_recent_ai_requests(limit: 10)
      activities.concat(recent_requests)
      
      # Get recent job completions
      recent_jobs = get_recent_job_activities(limit: 10)
      activities.concat(recent_jobs)
      
      # Get recent cache events
      recent_cache_events = get_recent_cache_activities(limit: 5)
      activities.concat(recent_cache_events)
      
      # Sort by timestamp and return most recent
      activities.sort_by { |a| Time.parse(a[:timestamp]) }.reverse.first(20)
    end
    
    def get_system_health_status
      {
        ai_services: :healthy,
        cache_system: check_cache_system_health,
        rate_limiting: :healthy,
        background_jobs: check_background_job_health,
        external_apis: check_external_api_status
      }
    end
    
    def get_cost_analysis
      {
        monthly_spend: get_monthly_ai_spend,
        daily_average: get_daily_average_spend,
        cost_by_operation: get_cost_breakdown_by_operation,
        projected_monthly: project_monthly_spend,
        budget_utilization: calculate_budget_utilization
      }
    end
    
    # Helper methods for statistics
    def get_daily_request_count
      # Count AI requests from today across all services
      Rails.cache.read("ai_daily_requests:#{current_organization.id}:#{Date.current}") || 0
    end
    
    def get_daily_cost
      # Get today's AI costs
      Rails.cache.read("ai_daily_cost:#{current_organization.id}:#{Date.current}") || 0.0
    end
    
    def get_overall_cache_hit_rate
      cache_service = Ai::CacheService.new(organization: current_organization)
      stats = cache_service.get_cache_statistics
      stats.dig(:overall, :overall_hit_rate) || 0.0
    end
    
    def get_average_response_time
      # Calculate average response time for AI requests
      # This would be tracked in production metrics
      rand(200..800) # Placeholder
    end
    
    def get_error_rate_percentage
      # Calculate error rate as percentage
      # This would be tracked in production metrics
      rand(0.1..2.5).round(2) # Placeholder
    end
    
    def get_active_job_count
      # Count active AI jobs in the queue
      # This would query Solid Queue in production
      rand(0..5) # Placeholder
    end
    
    def calculate_system_health_score
      # Calculate overall system health score (0-100)
      base_score = 95.0
      
      # Deduct for high error rates
      error_rate = get_error_rate_percentage
      base_score -= (error_rate * 10) if error_rate > 1.0
      
      # Deduct for poor cache performance
      cache_hit_rate = get_overall_cache_hit_rate
      base_score -= (100 - cache_hit_rate) * 0.2 if cache_hit_rate < 80
      
      # Deduct for slow response times
      avg_response_time = get_average_response_time
      base_score -= (avg_response_time - 500) * 0.01 if avg_response_time > 500
      
      [base_score, 100.0].min.round(1)
    end
    
    # Placeholder methods - these would be implemented with real metrics in production
    def get_ai_request_statistics(time_range); {}; end
    def get_cache_performance(time_range); {}; end
    def get_rate_limiting_statistics(time_range); {}; end
    def get_error_rate_statistics(time_range); {}; end
    def get_response_time_statistics(time_range); {}; end
    def get_cost_metrics(time_range); {}; end
    def generate_cache_recommendations(stats); []; end
    def get_active_ai_jobs; []; end
    def get_recent_job_completions; []; end
    def get_job_failure_rates; {}; end
    def get_queue_health_status; :healthy; end
    def get_job_performance_trends; {}; end
    def calculate_overall_health; :healthy; end
    def check_ai_services_health; :healthy; end
    def check_cache_health; :healthy; end
    def check_database_health; :healthy; end
    def check_external_api_health; :healthy; end
    def check_queue_health; :healthy; end
    def generate_health_alerts(health_status); []; end
    def get_current_period_costs(period); 0.0; end
    def get_cost_breakdown_by_service(period); {}; end
    def get_cost_trends(period); []; end
    def get_cost_projections; {}; end
    def identify_cost_optimizations; []; end
    def get_budget_status; {}; end
    def get_performance_recommendations; []; end
    def get_cost_optimization_recommendations; []; end
    def get_cache_optimization_recommendations; []; end
    def get_rate_limiting_recommendations; []; end
    def get_security_recommendations; []; end
    def prioritize_recommendations(recommendations); recommendations; end
    def generate_implementation_guide(recommendations); {}; end
    def compile_monitoring_export_data(time_range); {}; end
    def convert_monitoring_data_to_csv(data); ""; end
    def get_request_volume_trend; []; end
    def get_response_time_trend; []; end
    def get_error_rate_trend; []; end
    def get_cache_performance_trend; []; end
    def get_cost_trend; []; end
    def get_recent_ai_requests(limit:); []; end
    def get_recent_job_activities(limit:); []; end
    def get_recent_cache_activities(limit:); []; end
    def check_cache_system_health; :healthy; end
    def check_background_job_health; :healthy; end
    def check_external_api_status; :healthy; end
    def get_monthly_ai_spend; 0.0; end
    def get_daily_average_spend; 0.0; end
    def get_cost_breakdown_by_operation; {}; end
    def project_monthly_spend; 0.0; end
    def calculate_budget_utilization; 0.0; end
  end
end