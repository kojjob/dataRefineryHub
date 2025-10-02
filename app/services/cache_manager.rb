# frozen_string_literal: true

# Intelligent cache management service with multiple caching strategies
class CacheManager
  include Singleton

  CACHE_STRATEGIES = {
    aggressive: { ttl: 1.hour, refresh_threshold: 0.8 },
    moderate: { ttl: 15.minutes, refresh_threshold: 0.7 },
    conservative: { ttl: 5.minutes, refresh_threshold: 0.5 }
  }.freeze

  CACHE_NAMESPACES = %w[
    data_sources
    extraction_jobs
    analytics
    reports
    visualizations
    user_sessions
    api_responses
  ].freeze

  class << self
    delegate :fetch, :read, :write, :delete, :clear, :exists?, to: :instance
  end

  def initialize
    @cache = Rails.cache
    @metrics = CacheMetrics.new
    @strategies = {}
    setup_default_strategies
  end

  # Intelligent fetch with automatic strategy selection
  def fetch(key, options = {}, &block)
    namespace = extract_namespace(key)
    strategy = options[:strategy] || get_strategy(namespace)
    cache_options = build_cache_options(strategy, options)

    # Track cache metrics
    start_time = Time.current
    hit = exists?(key)

    result = @cache.fetch(key, cache_options) do
      @metrics.record_miss(namespace)
      value = block.call

      # Optionally compress large values
      if should_compress?(value)
        compress(value)
      else
        value
      end
    end

    # Record metrics
    duration = Time.current - start_time
    if hit
      @metrics.record_hit(namespace, duration)
    end

    # Check if we should refresh cache in background
    if should_refresh_cache?(key, strategy)
      RefreshCacheJob.perform_later(key, options)
    end

    decompress_if_needed(result)
  end

  # Multi-fetch for batch operations
  def fetch_multi(*keys, &block)
    options = keys.extract_options!

    # Read all keys at once
    cached_results = @cache.read_multi(*keys)
    missing_keys = keys - cached_results.keys

    # Fetch missing values
    if missing_keys.any? && block_given?
      new_values = block.call(missing_keys)

      # Write new values to cache
      new_values.each do |key, value|
        write(key, value, options)
        cached_results[key] = value
      end
    end

    cached_results
  end

  # Write with automatic expiration and versioning
  def write(key, value, options = {})
    namespace = extract_namespace(key)
    strategy = options[:strategy] || get_strategy(namespace)
    cache_options = build_cache_options(strategy, options)

    # Add version to key for cache busting
    versioned_key = versioned_key(key, options[:version])

    # Compress if needed
    final_value = should_compress?(value) ? compress(value) : value

    @cache.write(versioned_key, final_value, cache_options)
    @metrics.record_write(namespace, object_size(value))

    # Set expiration marker for background refresh
    if strategy[:refresh_threshold]
      set_refresh_marker(versioned_key, cache_options[:expires_in])
    end

    true
  end

  # Delete with pattern matching support
  def delete(key_or_pattern, options = {})
    if options[:pattern]
      delete_matched(key_or_pattern)
    else
      @cache.delete(key_or_pattern)
      @metrics.record_eviction(extract_namespace(key_or_pattern))
    end
  end

  # Clear entire namespace or all cache
  def clear(namespace = nil)
    if namespace
      clear_namespace(namespace)
    else
      @cache.clear
      @metrics.reset
    end
  end

  # Check if key exists
  def exists?(key)
    @cache.exist?(key)
  end

  # Get cache statistics
  def stats
    {
      metrics: @metrics.summary,
      memory_usage: calculate_memory_usage,
      namespace_stats: namespace_statistics,
      strategy_effectiveness: strategy_effectiveness
    }
  end

  # Warm up cache with frequently accessed data
  def warmup
    WarmupService.new(self).perform
  end

  # Register custom caching strategy
  def register_strategy(name, options)
    @strategies[name.to_sym] = options
  end

  private

  def setup_default_strategies
    # Data source caching - moderate
    @strategies[:data_sources] = CACHE_STRATEGIES[:moderate]

    # Analytics caching - aggressive for historical data
    @strategies[:analytics] = CACHE_STRATEGIES[:aggressive]

    # Real-time data - conservative
    @strategies[:extraction_jobs] = CACHE_STRATEGIES[:conservative]

    # API responses - moderate
    @strategies[:api_responses] = CACHE_STRATEGIES[:moderate]
  end

  def extract_namespace(key)
    key.to_s.split(":").first.to_sym
  end

  def get_strategy(namespace)
    @strategies[namespace] || CACHE_STRATEGIES[:moderate]
  end

  def build_cache_options(strategy, custom_options)
    {
      expires_in: custom_options[:expires_in] || strategy[:ttl],
      race_condition_ttl: custom_options[:race_condition_ttl] || 5.seconds,
      compress: custom_options[:compress] != false,
      version: custom_options[:version] || 1
    }
  end

  def versioned_key(key, version = nil)
    return key unless version
    "#{key}:v#{version}"
  end

  def should_compress?(value)
    object_size(value) > 1.kilobyte
  end

  def compress(value)
    # SECURITY FIX: Use JSON instead of Marshal to prevent code execution
    {
      compressed: true,
      data: ActiveSupport::Gzip.compress(safe_serialize(value)),
      format: "json"
    }
  end

  def decompress_if_needed(value)
    return value unless value.is_a?(Hash) && value[:compressed]
    
    decompressed_data = ActiveSupport::Gzip.decompress(value[:data])
    
    case value[:format]
    when "json"
      safe_deserialize(decompressed_data)
    else
      # Legacy format - handle carefully
      Rails.logger.warn "Legacy Marshal format detected - consider cache invalidation"
      begin
        # Only allow if we trust the source and it's simple data
        JSON.parse(decompressed_data)
      rescue
        nil
      end
    end
  end

  def object_size(obj)
    safe_serialize(obj).bytesize
  rescue
    0
  end

  private

  # SECURITY METHODS: Safe serialization

  def safe_serialize(obj)
    # Use JSON serialization instead of Marshal for security
    JSON.generate(serialize_for_json(obj))
  end

  def safe_deserialize(data)
    # Deserialize from JSON safely
    parsed = JSON.parse(data)
    deserialize_from_json(parsed)
  rescue JSON::ParserError
    Rails.logger.error "Failed to parse cached JSON data"
    nil
  end

  def serialize_for_json(obj)
    # Convert object to JSON-safe structure
    case obj
    when Hash
      obj.transform_values { |v| serialize_for_json(v) }
    when Array
      obj.map { |v| serialize_for_json(v) }
    when String, Numeric, TrueClass, FalseClass, NilClass
      obj
    when Time, DateTime, Date
      { "_type" => "time", "_value" => obj.iso8601 }
    when Symbol
      { "_type" => "symbol", "_value" => obj.to_s }
    else
      # For complex objects, store serializable attributes
      if obj.respond_to?(:attributes)
        { "_type" => "attributes", "_value" => obj.attributes }
      else
        # Fallback to string representation
        { "_type" => "string", "_value" => obj.to_s }
      end
    end
  end

  def deserialize_from_json(obj)
    # Convert JSON structure back to Ruby objects
    case obj
    when Hash
      if obj.key?("_type")
        case obj["_type"]
        when "time"
          Time.parse(obj["_value"])
        when "symbol"
          obj["_value"].to_sym
        when "attributes"
          obj["_value"]
        when "string"
          obj["_value"]
        else
          obj
        end
      else
        obj.transform_values { |v| deserialize_from_json(v) }
      end
    when Array
      obj.map { |v| deserialize_from_json(v) }
    else
      obj
    end
  end

  def should_refresh_cache?(key, strategy)
    return false unless strategy[:refresh_threshold]

    marker_key = "#{key}:refresh_marker"
    marker = @cache.read(marker_key)
    return false unless marker

    elapsed = Time.current - marker[:created_at]
    ttl = marker[:ttl]

    elapsed > (ttl * strategy[:refresh_threshold])
  end

  def set_refresh_marker(key, ttl)
    marker_key = "#{key}:refresh_marker"
    @cache.write(marker_key, {
      created_at: Time.current,
      ttl: ttl
    }, expires_in: ttl)
  end

  def delete_matched(pattern)
    if @cache.respond_to?(:delete_matched)
      @cache.delete_matched(pattern)
    else
      # Fallback for cache stores that don't support delete_matched
      Rails.logger.warn "Cache store doesn't support delete_matched"
    end
  end

  def clear_namespace(namespace)
    pattern = "#{namespace}:*"
    delete_matched(pattern)
    @metrics.record_namespace_clear(namespace)
  end

  def calculate_memory_usage
    if @cache.respond_to?(:stats)
      @cache.stats
    else
      { available: false }
    end
  end

  def namespace_statistics
    CACHE_NAMESPACES.each_with_object({}) do |namespace, stats|
      stats[namespace] = @metrics.namespace_stats(namespace)
    end
  end

  def strategy_effectiveness
    @strategies.each_with_object({}) do |(name, strategy), effectiveness|
      stats = @metrics.namespace_stats(name)
      hit_rate = stats[:hits].to_f / (stats[:hits] + stats[:misses] + 1)

      effectiveness[name] = {
        hit_rate: (hit_rate * 100).round(2),
        avg_response_time: stats[:avg_response_time],
        strategy: strategy
      }
    end
  end
end

# Cache metrics tracking
class CacheMetrics
  def initialize
    @stats = Hash.new { |h, k| h[k] = default_stats }
  end

  def record_hit(namespace, duration)
    @stats[namespace][:hits] += 1
    @stats[namespace][:total_time] += duration
    update_avg_time(namespace)
  end

  def record_miss(namespace)
    @stats[namespace][:misses] += 1
  end

  def record_write(namespace, size)
    @stats[namespace][:writes] += 1
    @stats[namespace][:total_size] += size
  end

  def record_eviction(namespace)
    @stats[namespace][:evictions] += 1
  end

  def record_namespace_clear(namespace)
    @stats[namespace][:clears] += 1
  end

  def namespace_stats(namespace)
    @stats[namespace]
  end

  def summary
    total_hits = @stats.values.sum { |s| s[:hits] }
    total_misses = @stats.values.sum { |s| s[:misses] }

    {
      total_hits: total_hits,
      total_misses: total_misses,
      hit_rate: calculate_hit_rate(total_hits, total_misses),
      namespaces: @stats.keys.size,
      top_namespaces: top_namespaces(5)
    }
  end

  def reset
    @stats.clear
  end

  private

  def default_stats
    {
      hits: 0,
      misses: 0,
      writes: 0,
      evictions: 0,
      clears: 0,
      total_time: 0.0,
      total_size: 0,
      avg_response_time: 0.0
    }
  end

  def update_avg_time(namespace)
    stats = @stats[namespace]
    total_requests = stats[:hits] + stats[:misses]
    stats[:avg_response_time] = stats[:total_time] / total_requests if total_requests > 0
  end

  def calculate_hit_rate(hits, misses)
    total = hits + misses
    return 0.0 if total.zero?
    ((hits.to_f / total) * 100).round(2)
  end

  def top_namespaces(limit)
    @stats.sort_by { |_, stats| stats[:hits] + stats[:misses] }
          .reverse
          .first(limit)
          .to_h
  end
end

# Cache warmup service
class WarmupService
  def initialize(cache_manager)
    @cache = cache_manager
  end

  def perform
    warm_data_sources
    warm_analytics
    warm_user_preferences
  end

  private

  def warm_data_sources
    DataSource.active.includes(:extraction_jobs).find_each do |source|
      key = "data_sources:#{source.id}"
      @cache.write(key, source.attributes, strategy: :moderate)
    end
  end

  def warm_analytics
    # Cache frequently accessed analytics
    Organization.find_each do |org|
      key = "analytics:dashboard:#{org.id}"
      data = {
        revenue_metrics: calculate_revenue_metrics(org),
        customer_metrics: calculate_customer_metrics(org),
        recent_activity: recent_activity(org)
      }
      @cache.write(key, data, strategy: :aggressive)
    end
  end

  def warm_user_preferences
    User.active.find_each do |user|
      key = "user_preferences:#{user.id}"
      @cache.write(key, user.preferences, strategy: :moderate)
    end
  end

  def calculate_revenue_metrics(org)
    # Placeholder for revenue calculation
    {}
  end

  def calculate_customer_metrics(org)
    # Placeholder for customer metrics
    {}
  end

  def recent_activity(org)
    # Placeholder for recent activity
    []
  end
end

# Background job for cache refresh
class RefreshCacheJob < ApplicationJob
  queue_as :low_priority

  def perform(key, options = {})
    # Re-execute the original block to refresh cache
    # This would need to be implemented based on your specific needs
  end
end
