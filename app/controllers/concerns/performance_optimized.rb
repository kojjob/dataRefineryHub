# frozen_string_literal: true

# Concern for adding performance optimizations to controllers
module PerformanceOptimized
  extend ActiveSupport::Concern

  included do
    # Add query analyzer in development
    if Rails.env.development?
      around_action :analyze_queries
    end

    # Add caching helpers
    helper_method :cache_key_for_collection, :cache_key_for_record
  end

  private

  # Query analysis wrapper
  def analyze_queries
    return yield unless QueryAnalyzer.enabled

    QueryAnalyzer.reset_stats
    result = yield

    report = QueryAnalyzer.report
    if report[:slow_queries] > 0 || report[:n_plus_one_detected] > 0
      logger.warn "Performance issues detected in #{controller_name}##{action_name}"
      logger.warn "  Slow queries: #{report[:slow_queries]}"
      logger.warn "  N+1 queries: #{report[:n_plus_one_detected]}"

      report[:recommendations].each do |rec|
        logger.warn "  #{rec[:severity].upcase}: #{rec[:message]}"
      end
    end

    result
  end

  # Generate cache key for collections with proper versioning
  def cache_key_for_collection(collection, prefix = nil)
    key_parts = [
      prefix || controller_name,
      action_name,
      current_organization&.id,
      collection.maximum(:updated_at)&.to_i,
      collection.count
    ].compact

    key_parts.join(":")
  end

  # Generate cache key for single record with associations
  def cache_key_for_record(record, associations = [])
    key_parts = [
      record.cache_key_with_version
    ]

    associations.each do |assoc|
      if record.respond_to?(assoc)
        associated = record.send(assoc)
        if associated.respond_to?(:maximum)
          key_parts << associated.maximum(:updated_at)&.to_i
        elsif associated.respond_to?(:updated_at)
          key_parts << associated.updated_at&.to_i
        end
      end
    end

    key_parts.compact.join(":")
  end

  # Optimized data fetching with caching
  def fetch_with_cache(cache_key, options = {}, &block)
    expires_in = options[:expires_in] || determine_cache_duration

    CacheManager.fetch(cache_key, expires_in: expires_in) do
      ActiveRecord::Base.connection_pool.with_connection do
        result = yield
        # Force load if it's an ActiveRecord relation
        result.respond_to?(:load) ? result.load : result
      end
    end
  end

  # Multi-fetch for batch operations
  def fetch_multi_with_cache(keys, options = {}, &block)
    CacheManager.fetch_multi(*keys, options, &block)
  end

  # Invalidate cache for a pattern
  def expire_cache_pattern(pattern)
    CacheManager.delete(pattern, pattern: true)
  end

  # Determine appropriate cache duration based on data type
  def determine_cache_duration
    case action_name
    when "index"
      5.minutes
    when "show"
      10.minutes
    when "dashboard", "analytics"
      15.minutes
    else
      2.minutes
    end
  end

  # Batch load associations to prevent N+1
  def batch_load_associations(records, *associations)
    ActiveRecord::Associations::Preloader.new(
      records: records,
      associations: associations
    ).call
    records
  end

  # Optimized pagination with caching
  def paginate_with_cache(scope, page_param = :page)
    page = params[page_param] || 1
    per_page = params[:per_page] || 25

    cache_key = "#{cache_key_for_collection(scope)}:page:#{page}:per:#{per_page}"

    fetch_with_cache(cache_key, expires_in: 5.minutes) do
      scope.page(page).per(per_page).load
    end
  end

  # Stream large datasets to avoid memory issues
  def stream_large_dataset(scope, batch_size = 1000)
    scope.find_in_batches(batch_size: batch_size) do |batch|
      yield batch
    end
  end

  # Use database views for complex queries
  def use_materialized_view(view_name, refresh: false)
    if refresh
      ActiveRecord::Base.connection.execute(
        "REFRESH MATERIALIZED VIEW CONCURRENTLY #{view_name}"
      )
    end

    ActiveRecord::Base.connection.execute("SELECT * FROM #{view_name}")
  end

  # Optimize JSON rendering with includes
  def render_json_optimized(records, options = {})
    # Preload associations if specified
    if options[:include]
      records = records.includes(options[:include])
    end

    # Use fast_jsonapi or similar for serialization
    render json: serialize_optimized(records, options)
  end

  def serialize_optimized(records, options = {})
    # Basic optimization - override in specific controllers for custom serialization
    if records.respond_to?(:to_a)
      records.as_json(options)
    else
      records.as_json(options)
    end
  end
end

# Module for adding query scopes to models for optimization
module OptimizedScopes
  extend ActiveSupport::Concern

  included do
    # Common optimized scopes
    scope :with_associations, -> { includes(default_includes) if respond_to?(:default_includes) }
    scope :recent, -> { order(created_at: :desc) }
    scope :by_date_range, ->(start_date, end_date) { where(created_at: start_date..end_date) }
    scope :active, -> { where(active: true) if column_names.include?("active") }

    # Batch loading scope
    scope :in_batches_of, ->(size) { find_in_batches(batch_size: size) }
  end

  class_methods do
    # Define default includes for the model
    def default_includes(*associations)
      @default_includes = associations
    end

    # Get default includes
    def get_default_includes
      @default_includes || []
    end

    # Optimized count with caching
    def cached_count(cache_key = nil, expires_in: 5.minutes)
      cache_key ||= "#{table_name}:count:#{maximum(:updated_at)&.to_i}"

      Rails.cache.fetch(cache_key, expires_in: expires_in) do
        count
      end
    end

    # Find with caching
    def find_cached(id, expires_in: 10.minutes)
      Rails.cache.fetch("#{table_name}:#{id}", expires_in: expires_in) do
        find(id)
      end
    end
  end
end
