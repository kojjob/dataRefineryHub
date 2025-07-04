# frozen_string_literal: true

module Ai
  class CacheService
    include ActiveModel::Model
    
    # Cache key prefixes for different AI operations
    CACHE_PREFIXES = {
      llm_response: 'ai:llm:response',
      analytics: 'ai:analytics',
      bi_insights: 'ai:bi:insights',
      query_result: 'ai:query:result',
      presentation: 'ai:presentation',
      data_integration: 'ai:integration',
      real_time_metrics: 'ai:realtime:metrics'
    }.freeze
    
    # Cache TTL settings (in seconds)
    CACHE_TTL = {
      llm_response: 1.hour,           # LLM responses can be cached longer
      analytics: 5.minutes,           # Analytics need frequent updates
      bi_insights: 15.minutes,        # BI insights update periodically
      query_result: 10.minutes,       # Query results depend on data freshness
      presentation: 30.minutes,       # Presentations update moderately
      data_integration: 1.hour,       # Integration analysis is stable
      real_time_metrics: 1.minute     # Real-time metrics expire quickly
    }.freeze
    
    attr_accessor :organization, :cache_store
    
    def initialize(organization:, cache_store: nil)
      @organization = organization
      @cache_store = cache_store || Rails.cache
    end
    
    # Cache LLM responses with intelligent key generation
    def cache_llm_response(prompt_hash, model_config, response_data)
      cache_key = generate_llm_cache_key(prompt_hash, model_config)
      
      cached_data = {
        response: response_data,
        model_config: model_config,
        organization_id: @organization.id,
        cached_at: Time.current.iso8601,
        cache_version: ai_cache_version
      }
      
      @cache_store.write(
        cache_key,
        cached_data,
        expires_in: CACHE_TTL[:llm_response],
        compress: true
      )
      
      # Track cache metrics
      increment_cache_metric(:llm_response, :write)
      
      Rails.logger.info "Cached LLM response: #{cache_key}"
      cached_data
    end
    
    # Retrieve cached LLM response
    def get_cached_llm_response(prompt_hash, model_config)
      cache_key = generate_llm_cache_key(prompt_hash, model_config)
      cached_data = @cache_store.read(cache_key)
      
      if cached_data&.dig(:cache_version) == ai_cache_version
        increment_cache_metric(:llm_response, :hit)
        Rails.logger.info "Cache hit for LLM response: #{cache_key}"
        cached_data
      else
        increment_cache_metric(:llm_response, :miss)
        nil
      end
    end
    
    # Cache analytics data with time-based keys
    def cache_analytics_data(metric_type, time_range, data)
      cache_key = generate_analytics_cache_key(metric_type, time_range)
      
      cached_data = {
        data: data,
        metric_type: metric_type,
        time_range: time_range,
        organization_id: @organization.id,
        cached_at: Time.current.iso8601
      }
      
      @cache_store.write(
        cache_key,
        cached_data,
        expires_in: CACHE_TTL[:analytics],
        compress: true
      )
      
      increment_cache_metric(:analytics, :write)
      cached_data
    end
    
    # Get cached analytics data
    def get_cached_analytics_data(metric_type, time_range)
      cache_key = generate_analytics_cache_key(metric_type, time_range)
      cached_data = @cache_store.read(cache_key)
      
      if cached_data
        increment_cache_metric(:analytics, :hit)
        cached_data
      else
        increment_cache_metric(:analytics, :miss)
        nil
      end
    end
    
    # Cache BI insights with content-based invalidation
    def cache_bi_insights(insight_type, context_hash, insights_data)
      cache_key = generate_bi_insights_cache_key(insight_type, context_hash)
      
      cached_data = {
        insights: insights_data,
        insight_type: insight_type,
        context_hash: context_hash,
        organization_id: @organization.id,
        cached_at: Time.current.iso8601,
        data_freshness: calculate_data_freshness
      }
      
      @cache_store.write(
        cache_key,
        cached_data,
        expires_in: CACHE_TTL[:bi_insights],
        compress: true
      )
      
      increment_cache_metric(:bi_insights, :write)
      cached_data
    end
    
    # Get cached BI insights
    def get_cached_bi_insights(insight_type, context_hash)
      cache_key = generate_bi_insights_cache_key(insight_type, context_hash)
      cached_data = @cache_store.read(cache_key)
      
      if cached_data && data_still_fresh?(cached_data[:data_freshness])
        increment_cache_metric(:bi_insights, :hit)
        cached_data
      else
        increment_cache_metric(:bi_insights, :miss)
        nil
      end
    end
    
    # Cache query results with smart invalidation
    def cache_query_result(query_hash, result_data)
      cache_key = generate_query_cache_key(query_hash)
      
      cached_data = {
        result: result_data,
        query_hash: query_hash,
        organization_id: @organization.id,
        cached_at: Time.current.iso8601,
        data_sources_updated_at: get_data_sources_last_updated
      }
      
      @cache_store.write(
        cache_key,
        cached_data,
        expires_in: CACHE_TTL[:query_result],
        compress: true
      )
      
      increment_cache_metric(:query_result, :write)
      cached_data
    end
    
    # Get cached query result
    def get_cached_query_result(query_hash)
      cache_key = generate_query_cache_key(query_hash)
      cached_data = @cache_store.read(cache_key)
      
      if cached_data && data_sources_unchanged?(cached_data[:data_sources_updated_at])
        increment_cache_metric(:query_result, :hit)
        cached_data
      else
        increment_cache_metric(:query_result, :miss)
        nil
      end
    end
    
    # Cache presentation data
    def cache_presentation_data(presentation_id, presentation_data)
      cache_key = generate_presentation_cache_key(presentation_id)
      
      cached_data = {
        presentation: presentation_data,
        presentation_id: presentation_id,
        organization_id: @organization.id,
        cached_at: Time.current.iso8601
      }
      
      @cache_store.write(
        cache_key,
        cached_data,
        expires_in: CACHE_TTL[:presentation],
        compress: true
      )
      
      increment_cache_metric(:presentation, :write)
      cached_data
    end
    
    # Get cached presentation data
    def get_cached_presentation_data(presentation_id)
      cache_key = generate_presentation_cache_key(presentation_id)
      cached_data = @cache_store.read(cache_key)
      
      if cached_data
        increment_cache_metric(:presentation, :hit)
        cached_data
      else
        increment_cache_metric(:presentation, :miss)
        nil
      end
    end
    
    # Cache real-time metrics with very short TTL
    def cache_real_time_metrics(metrics_data)
      cache_key = generate_real_time_metrics_cache_key
      
      cached_data = {
        metrics: metrics_data,
        organization_id: @organization.id,
        cached_at: Time.current.iso8601
      }
      
      @cache_store.write(
        cache_key,
        cached_data,
        expires_in: CACHE_TTL[:real_time_metrics],
        compress: true
      )
      
      increment_cache_metric(:real_time_metrics, :write)
      cached_data
    end
    
    # Get cached real-time metrics
    def get_cached_real_time_metrics
      cache_key = generate_real_time_metrics_cache_key
      cached_data = @cache_store.read(cache_key)
      
      if cached_data
        increment_cache_metric(:real_time_metrics, :hit)
        cached_data
      else
        increment_cache_metric(:real_time_metrics, :miss)
        nil
      end
    end
    
    # Invalidate cache for specific patterns
    def invalidate_cache(pattern)
      case pattern
      when :all_analytics
        invalidate_pattern("#{CACHE_PREFIXES[:analytics]}:org:#{@organization.id}:*")
      when :all_bi_insights
        invalidate_pattern("#{CACHE_PREFIXES[:bi_insights]}:org:#{@organization.id}:*")
      when :all_queries
        invalidate_pattern("#{CACHE_PREFIXES[:query_result]}:org:#{@organization.id}:*")
      when :all_presentations
        invalidate_pattern("#{CACHE_PREFIXES[:presentation]}:org:#{@organization.id}:*")
      when :all_real_time
        invalidate_pattern("#{CACHE_PREFIXES[:real_time_metrics]}:org:#{@organization.id}:*")
      when :organization_data
        invalidate_pattern("*:org:#{@organization.id}:*")
      end
      
      Rails.logger.info "Invalidated cache pattern: #{pattern}"
    end
    
    # Get cache statistics
    def get_cache_statistics
      stats = {}
      
      CACHE_PREFIXES.keys.each do |cache_type|
        stats[cache_type] = {
          hits: get_cache_metric(cache_type, :hit),
          misses: get_cache_metric(cache_type, :miss),
          writes: get_cache_metric(cache_type, :write),
          hit_rate: calculate_hit_rate(cache_type)
        }
      end
      
      stats[:overall] = calculate_overall_statistics(stats)
      stats
    end
    
    # Warm up commonly used caches
    def warm_up_cache
      Rails.logger.info "Warming up AI caches for organization: #{@organization.name}"
      
      # Warm up common analytics queries
      warm_up_analytics_cache
      
      # Warm up BI insights
      warm_up_bi_insights_cache
      
      # Warm up real-time metrics
      warm_up_real_time_metrics_cache
      
      Rails.logger.info "Cache warm-up completed"
    end
    
    private
    
    # Generate cache keys
    def generate_llm_cache_key(prompt_hash, model_config)
      model_key = Digest::SHA256.hexdigest(model_config.to_json)[0..8]
      "#{CACHE_PREFIXES[:llm_response]}:org:#{@organization.id}:prompt:#{prompt_hash}:model:#{model_key}"
    end
    
    def generate_analytics_cache_key(metric_type, time_range)
      time_key = time_range.is_a?(String) ? time_range : "#{time_range.begin.to_i}-#{time_range.end.to_i}"
      "#{CACHE_PREFIXES[:analytics]}:org:#{@organization.id}:metric:#{metric_type}:time:#{time_key}"
    end
    
    def generate_bi_insights_cache_key(insight_type, context_hash)
      "#{CACHE_PREFIXES[:bi_insights]}:org:#{@organization.id}:type:#{insight_type}:context:#{context_hash}"
    end
    
    def generate_query_cache_key(query_hash)
      "#{CACHE_PREFIXES[:query_result]}:org:#{@organization.id}:query:#{query_hash}"
    end
    
    def generate_presentation_cache_key(presentation_id)
      "#{CACHE_PREFIXES[:presentation]}:org:#{@organization.id}:pres:#{presentation_id}"
    end
    
    def generate_real_time_metrics_cache_key
      "#{CACHE_PREFIXES[:real_time_metrics]}:org:#{@organization.id}:current"
    end
    
    # Cache versioning for invalidation
    def ai_cache_version
      # Version based on organization's data freshness and AI model updates
      "#{@organization.updated_at.to_i}_#{Rails.application.config.ai_cache_version || '1'}"
    end
    
    # Data freshness calculations
    def calculate_data_freshness
      @organization.data_sources.maximum(:last_synced_at)&.to_i || 0
    end
    
    def data_still_fresh?(cached_freshness)
      current_freshness = calculate_data_freshness
      (current_freshness - cached_freshness.to_i).abs < 3600 # 1 hour tolerance
    end
    
    def get_data_sources_last_updated
      @organization.data_sources.maximum(:updated_at)&.to_i || 0
    end
    
    def data_sources_unchanged?(cached_updated_at)
      current_updated_at = get_data_sources_last_updated
      current_updated_at <= cached_updated_at.to_i
    end
    
    # Cache metrics tracking
    def increment_cache_metric(cache_type, operation)
      metric_key = "ai_cache_metrics:#{cache_type}:#{operation}:#{Date.current}"
      @cache_store.increment(metric_key, 1, expires_in: 7.days)
    end
    
    def get_cache_metric(cache_type, operation)
      metric_key = "ai_cache_metrics:#{cache_type}:#{operation}:#{Date.current}"
      @cache_store.read(metric_key) || 0
    end
    
    def calculate_hit_rate(cache_type)
      hits = get_cache_metric(cache_type, :hit)
      misses = get_cache_metric(cache_type, :miss)
      total = hits + misses
      
      return 0.0 if total == 0
      (hits.to_f / total * 100).round(2)
    end
    
    def calculate_overall_statistics(stats)
      total_hits = stats.values.sum { |s| s[:hits] }
      total_misses = stats.values.sum { |s| s[:misses] }
      total_writes = stats.values.sum { |s| s[:writes] }
      total_requests = total_hits + total_misses
      
      {
        total_hits: total_hits,
        total_misses: total_misses,
        total_writes: total_writes,
        total_requests: total_requests,
        overall_hit_rate: total_requests > 0 ? (total_hits.to_f / total_requests * 100).round(2) : 0.0,
        cache_efficiency: calculate_cache_efficiency(total_hits, total_writes)
      }
    end
    
    def calculate_cache_efficiency(hits, writes)
      return 0.0 if writes == 0
      (hits.to_f / writes).round(2)
    end
    
    # Cache invalidation
    def invalidate_pattern(pattern)
      # Note: This requires Redis as the cache store for pattern-based deletion
      if @cache_store.respond_to?(:delete_matched)
        @cache_store.delete_matched(pattern)
      else
        Rails.logger.warn "Cache store doesn't support pattern deletion"
      end
    end
    
    # Cache warm-up methods
    def warm_up_analytics_cache
      common_metrics = ['revenue', 'customers', 'orders', 'conversion_rate']
      common_time_ranges = ['1d', '7d', '30d']
      
      common_metrics.each do |metric|
        common_time_ranges.each do |time_range|
          # This would trigger actual analytics calculation and caching
          Rails.logger.debug "Warming up cache for #{metric} over #{time_range}"
        end
      end
    end
    
    def warm_up_bi_insights_cache
      common_insight_types = ['revenue_trends', 'customer_segments', 'performance_summary']
      
      common_insight_types.each do |insight_type|
        context_hash = Digest::SHA256.hexdigest("#{insight_type}_#{@organization.id}")[0..8]
        Rails.logger.debug "Warming up BI insights cache for #{insight_type}"
      end
    end
    
    def warm_up_real_time_metrics_cache
      Rails.logger.debug "Warming up real-time metrics cache"
      # This would trigger real-time metrics calculation and caching
    end
  end
end