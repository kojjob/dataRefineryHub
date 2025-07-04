# frozen_string_literal: true

module Ai
  class NaturalLanguageQueryJob < BaseAiJob
    def perform(args)
      validate_job_arguments([:organization_id, :query_text, :user_id, :session_id])
      
      organization = Organization.find(args[:organization_id])
      user = User.find(args[:user_id])
      
      update_job_progress('initializing', 0, 'Setting up natural language query processing')
      
      # Ensure we don't exceed rate limits
      with_rate_limiting(:natural_language_query) do
        process_natural_language_query(organization, user, args)
      end
    end
    
    private
    
    def process_natural_language_query(organization, user, args)
      query_service = Ai::NaturalLanguageQueryService.new(organization: organization)
      cache_key = generate_query_cache_key(args[:query_text], organization.id)
      
      update_job_progress('analyzing', 20, 'Analyzing query intent and context')
      
      # Try to get cached result first
      result = with_ai_cache(cache_key, ttl: 10.minutes) do
        update_job_progress('processing', 50, 'Processing natural language query')
        
        query_result = query_service.process_query(args[:query_text])
        
        update_job_progress('formatting', 80, 'Formatting results and insights')
        
        # Enhance result with additional context
        enhance_query_result(query_result, organization, user)
      end
      
      update_job_progress('completing', 100, 'Finalizing query response')
      
      # Store result for retrieval
      store_query_result(args[:session_id], result)
      
      # Broadcast result to user
      broadcast_query_result(organization, user, args[:session_id], result)
      
      # Track query analytics
      track_query_analytics(organization, user, args[:query_text], result)
      
      Rails.logger.info "Completed natural language query for user #{user.id}"
    end
    
    def enhance_query_result(base_result, organization, user)
      base_result.merge(
        user_context: {
          user_id: user.id,
          user_role: user.role_in_organization(organization),
          query_history_count: get_user_query_count(user, organization)
        },
        organization_context: {
          data_sources_count: organization.data_sources.count,
          data_freshness: organization.data_sources.maximum(:last_synced_at),
          available_metrics: get_available_metrics(organization)
        },
        suggestions: generate_follow_up_suggestions(base_result, organization),
        confidence_score: calculate_result_confidence(base_result)
      )
    end
    
    def generate_query_cache_key(query_text, organization_id)
      query_hash = Digest::SHA256.hexdigest(query_text.downcase.strip)[0..12]
      "ai:nlq:#{organization_id}:#{query_hash}"
    end
    
    def store_query_result(session_id, result)
      Rails.cache.write(
        "nlq_result:#{session_id}",
        result,
        expires_in: 30.minutes
      )
    end
    
    def broadcast_query_result(organization, user, session_id, result)
      ActionCable.server.broadcast(
        "natural_language_queries_#{organization.id}",
        {
          type: 'query_result',
          session_id: session_id,
          user_id: user.id,
          result: result,
          completed_at: Time.current.iso8601
        }
      )
    end
    
    def track_query_analytics(organization, user, query_text, result)
      analytics_data = {
        organization_id: organization.id,
        user_id: user.id,
        query_text: query_text,
        result_type: result[:result_type],
        confidence_score: result[:confidence_score],
        processing_time: Time.current - @start_time,
        data_points_returned: result[:data]&.length || 0,
        executed_at: Time.current.iso8601
      }
      
      # Store for analytics dashboard
      Rails.cache.write(
        "nlq_analytics:#{SecureRandom.hex(8)}",
        analytics_data,
        expires_in: 30.days
      )
    end
    
    def get_user_query_count(user, organization)
      # Count cached queries for this user in the last 30 days
      Rails.cache.read("user_query_count:#{user.id}:#{organization.id}") || 0
    end
    
    def get_available_metrics(organization)
      # Get list of metrics available based on connected data sources
      organization.data_sources.where(status: 'connected').pluck(:source_type).uniq
    end
    
    def generate_follow_up_suggestions(result, organization)
      suggestions = []
      
      case result[:result_type]
      when 'revenue_analysis'
        suggestions << "Show me revenue trends over the last 6 months"
        suggestions << "Compare this quarter's revenue to last quarter"
        suggestions << "What are the top performing products by revenue?"
      when 'customer_analysis'
        suggestions << "Show me customer acquisition trends"
        suggestions << "What's our customer retention rate?"
        suggestions << "Who are our highest value customers?"
      when 'order_analysis'
        suggestions << "Show me order volume trends"
        suggestions << "What's the average order value this month?"
        suggestions << "Which products are ordered most frequently?"
      else
        suggestions << "Show me a summary of key business metrics"
        suggestions << "What trends should I be aware of?"
        suggestions << "Compare this month to last month"
      end
      
      suggestions.first(3)
    end
    
    def calculate_result_confidence(result)
      confidence = 0.5 # Base confidence
      
      # Increase confidence based on data availability
      confidence += 0.2 if result[:data]&.any?
      confidence += 0.1 if result[:visualization_data]&.any?
      confidence += 0.1 if result[:insights]&.any?
      confidence += 0.1 if result[:sql_query].present?
      
      # Decrease confidence if there are warnings
      confidence -= 0.1 if result[:warnings]&.any?
      confidence -= 0.2 if result[:errors]&.any?
      
      [confidence, 1.0].min.round(2)
    end
    
    def critical_job?
      # Natural language queries are user-facing, so they're critical
      true
    end
  end
end