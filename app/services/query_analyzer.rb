# frozen_string_literal: true

# Service for analyzing and monitoring database query performance
class QueryAnalyzer
  class << self
    attr_accessor :enabled, :slow_query_threshold, :logger

    def configure
      yield self if block_given?
      self.enabled ||= Rails.env.development? || Rails.env.staging?
      self.slow_query_threshold ||= 100 # milliseconds
      self.logger ||= Rails.logger
      subscribe_to_queries if enabled
    end

    def analyze
      return unless enabled
      
      subscribe_to_queries
      logger.info "Query Analyzer enabled with threshold: #{slow_query_threshold}ms"
    end

    def report
      {
        total_queries: query_stats[:total_queries],
        slow_queries: query_stats[:slow_queries].size,
        n_plus_one_detected: query_stats[:n_plus_one_queries].size,
        average_time: calculate_average_time,
        slowest_queries: query_stats[:slow_queries].first(10),
        most_frequent: calculate_most_frequent,
        recommendations: generate_recommendations
      }
    end

    def reset_stats
      @query_stats = {
        total_queries: 0,
        slow_queries: [],
        n_plus_one_queries: [],
        query_counts: Hash.new(0),
        query_times: [],
        table_access_patterns: Hash.new(0)
      }
    end

    private

    def query_stats
      @query_stats ||= reset_stats
    end

    def subscribe_to_queries
      return if @subscribed
      
      ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
        event = ActiveSupport::Notifications::Event.new(*args)
        analyze_query(event) if should_analyze?(event)
      end
      
      @subscribed = true
    end

    def should_analyze?(event)
      # Skip SCHEMA queries and transaction management
      sql = event.payload[:sql]
      return false if sql.nil?
      return false if sql.match?(/^(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE SAVEPOINT)/i)
      return false if sql.match?(/^(SHOW|SET|PRAGMA)/i)
      return false if sql.match?(/schema_migrations|ar_internal_metadata/i)
      
      true
    end

    def analyze_query(event)
      sql = event.payload[:sql]
      duration = event.duration
      name = event.payload[:name] || 'SQL'
      
      # Update stats
      query_stats[:total_queries] += 1
      query_stats[:query_times] << duration
      
      # Track query patterns
      normalized_sql = normalize_sql(sql)
      query_stats[:query_counts][normalized_sql] += 1
      
      # Detect slow queries
      if duration > slow_query_threshold
        record_slow_query(sql, duration, name, event)
      end
      
      # Detect N+1 queries
      detect_n_plus_one(sql, normalized_sql, event)
      
      # Track table access patterns
      track_table_access(sql)
      
      # Log if in development
      if Rails.env.development? && duration > slow_query_threshold
        logger.warn "SLOW QUERY (#{duration.round(2)}ms): #{sql[0..200]}"
      end
    end

    def normalize_sql(sql)
      # Safely normalize SQL for pattern matching
      # Remove specific values to group similar queries
      sanitized = sql.dup
      sanitized.gsub!(/\b\d+\b/, '?')           # Replace numbers with ?
      sanitized.gsub!(/'(?:[^']|'')*'/, '?')     # Replace string literals with ? (handle escaped quotes)
      sanitized.gsub!(/"(?:[^"]|"")*"/, '?') # Replace double-quoted identifiers
      sanitized.gsub!(/\s+/, ' ')                # Normalize whitespace
      sanitized.strip!
      sanitized.downcase!
      sanitized
    end

    def record_slow_query(sql, duration, name, event)
      slow_query = {
        sql: sql,
        duration: duration,
        name: name,
        timestamp: Time.current,
        backtrace: filtered_backtrace,
        binds: event.payload[:binds],
        cached: event.payload[:cached],
        connection: event.payload[:connection]&.object_id
      }
      
      query_stats[:slow_queries] << slow_query
      query_stats[:slow_queries].sort_by! { |q| -q[:duration] }
      query_stats[:slow_queries] = query_stats[:slow_queries].first(100) # Keep top 100
    end

    def detect_n_plus_one(sql, normalized_sql, event)
      # N+1 detection with improved pattern matching
      threshold = 10
      query_count = query_stats[:query_counts][normalized_sql]
      
      return unless query_count > threshold
      
      # Improved N+1 pattern detection
      n_plus_one_patterns = [
        /\ASELECT\s+.+\s+FROM\s+\S+\s+WHERE\s+\S+\.\w+\s*=\s*\?/i,
        /\ASELECT\s+.+\s+FROM\s+\S+\s+WHERE\s+\w+\s*=\s*\?/i
      ]
      
      is_n_plus_one = n_plus_one_patterns.any? { |pattern| sql.match?(pattern) }
      is_batch_query = sql.match?(/LIMIT\s+[2-9]|LIMIT\s+\d{2,}|IN\s*\([^)]+,[^)]+\)/i)
      
      if is_n_plus_one && !is_batch_query
        existing = query_stats[:n_plus_one_queries].find { |q| q[:pattern] == normalized_sql }
        
        if existing
          existing[:count] = query_count
          existing[:last_seen] = Time.current
        else
          query_stats[:n_plus_one_queries] << {
            pattern: normalized_sql,
            count: query_count,
            example: sql.truncate(500), # Limit example size
            timestamp: Time.current,
            last_seen: Time.current,
            backtrace: filtered_backtrace
          }
        end
      end
    end

    def track_table_access(sql)
      # Extract table names from SQL
      tables = extract_table_names(sql)
      tables.each do |table|
        query_stats[:table_access_patterns][table] += 1
      end
    end

    def extract_table_names(sql)
      tables = []
      
      # Safely extract table names using more robust regex
      # Match FROM clause (handle schema.table format)
      sql.scan(/FROM\s+["`]?(?:(\w+)\.)?([\w]+)["`]?/i) do |schema, table|
        tables << (table || schema)
      end
      
      # Match JOIN clauses (handle schema.table format)
      sql.scan(/JOIN\s+["`]?(?:(\w+)\.)?([\w]+)["`]?/i) do |schema, table|
        tables << (table || schema)
      end
      
      # Match UPDATE/INSERT/DELETE (handle schema.table format)
      sql.scan(/(?:UPDATE|INSERT\s+INTO|DELETE\s+FROM)\s+["`]?(?:(\w+)\.)?([\w]+)["`]?/i) do |schema, table|
        tables << (table || schema)
      end
      
      tables.compact.uniq
    end

    def filtered_backtrace
      # Get the application backtrace, excluding gems and framework
      caller.select { |line| line.include?(Rails.root.to_s) }
            .reject { |line| line.include?('/gems/') }
            .first(5)
    end

    def calculate_average_time
      return 0 if query_stats[:query_times].empty?
      query_stats[:query_times].sum / query_stats[:query_times].size.to_f
    end

    def calculate_most_frequent
      query_stats[:query_counts]
        .sort_by { |_, count| -count }
        .first(10)
        .map { |sql, count| { sql: sql[0..200], count: count } }
    end

    def generate_recommendations
      recommendations = []
      
      # Check for N+1 queries
      if query_stats[:n_plus_one_queries].any?
        recommendations << {
          type: 'n_plus_one',
          severity: 'high',
          message: "Detected #{query_stats[:n_plus_one_queries].size} potential N+1 query patterns",
          details: query_stats[:n_plus_one_queries].first(3).map { |q| 
            "Pattern repeated #{q[:count]} times: #{q[:pattern][0..100]}"
          }
        }
      end
      
      # Check for missing indexes
      slow_selects = query_stats[:slow_queries].select { |q| q[:sql].match?(/^SELECT/i) }
      if slow_selects.any?
        recommendations << {
          type: 'missing_index',
          severity: 'medium',
          message: "#{slow_selects.size} slow SELECT queries detected",
          details: ["Consider adding indexes for frequently accessed columns"]
        }
      end
      
      # Check for large result sets
      large_queries = query_stats[:slow_queries].select { |q| 
        q[:sql].match?(/SELECT \* FROM/i) && !q[:sql].match?(/LIMIT/i)
      }
      if large_queries.any?
        recommendations << {
          type: 'large_result_set',
          severity: 'medium',
          message: "Detected queries without LIMIT clauses",
          details: ["Consider adding pagination or limiting result sets"]
        }
      end
      
      # Check for high frequency tables
      hot_tables = query_stats[:table_access_patterns]
        .select { |_, count| count > 100 }
        .sort_by { |_, count| -count }
        .first(3)
      
      if hot_tables.any?
        recommendations << {
          type: 'hot_tables',
          severity: 'low',
          message: "High frequency table access detected",
          details: hot_tables.map { |table, count| 
            "Table '#{table}' accessed #{count} times"
          }
        }
      end
      
      recommendations
    end
  end
end

# Performance monitoring middleware
class QueryAnalyzerMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    QueryAnalyzer.reset_stats if QueryAnalyzer.enabled
    
    result = @app.call(env)
    
    if QueryAnalyzer.enabled && should_report?(env)
      report = QueryAnalyzer.report
      log_performance_issues(report, env)
    end
    
    result
  end

  private

  def should_report?(env)
    # Report on non-asset requests
    !env['PATH_INFO'].match?(/\.(css|js|png|jpg|gif|ico|woff|ttf)$/i)
  end

  def log_performance_issues(report, env)
    if report[:slow_queries] > 0 || report[:n_plus_one_detected] > 0
      Rails.logger.warn "Query Performance Issues - Path: #{env['PATH_INFO']}"
      Rails.logger.warn "  Slow queries: #{report[:slow_queries]}"
      Rails.logger.warn "  N+1 queries detected: #{report[:n_plus_one_detected]}"
      Rails.logger.warn "  Average query time: #{report[:average_time].round(2)}ms"
      
      report[:recommendations].each do |rec|
        Rails.logger.warn "  Recommendation (#{rec[:severity]}): #{rec[:message]}"
      end
    end
  end
end
