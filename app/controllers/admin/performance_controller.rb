# frozen_string_literal: true

module Admin
  # Controller for monitoring application performance
  class PerformanceController < ApplicationController
    before_action :require_admin!

    def index
      @metrics = gather_performance_metrics
      @health_status = check_system_health
      @cache_stats = CacheManager.stats
      @query_report = QueryAnalyzer.report if QueryAnalyzer.enabled
    end

    def queries
      return redirect_to admin_performance_path, alert: "Query Analyzer not enabled" unless QueryAnalyzer.enabled

      @report = QueryAnalyzer.report
      @slow_queries = @report[:slowest_queries]
      @n_plus_one_queries = @report[:n_plus_one_queries]
      @recommendations = @report[:recommendations]
    end

    def cache
      @cache_stats = CacheManager.stats
      @namespace_stats = @cache_stats[:namespace_stats]
      @strategy_effectiveness = @cache_stats[:strategy_effectiveness]

      respond_to do |format|
        format.html
        format.json { render json: @cache_stats }
      end
    end

    def circuit_breakers
      @circuit_breakers = CircuitBreakerFactory.status_all

      respond_to do |format|
        format.html
        format.json { render json: @circuit_breakers }
      end
    end

    def clear_cache
      namespace = params[:namespace]

      if namespace.present?
        CacheManager.clear(namespace)
        message = "Cache cleared for namespace: #{namespace}"
      else
        CacheManager.clear
        message = "All cache cleared"
      end

      redirect_to admin_performance_cache_path, notice: message
    end

    def reset_circuit_breaker
      name = params[:name]

      if name.present?
        circuit_breaker = CircuitBreakerFactory.get(name)
        circuit_breaker.reset!
        message = "Circuit breaker '#{name}' reset successfully"
      else
        CircuitBreakerFactory.reset_all
        message = "All circuit breakers reset"
      end

      redirect_to admin_performance_circuit_breakers_path, notice: message
    end

    def database_stats
      @connection_pool = database_pool_stats
      @table_sizes = calculate_table_sizes
      @index_usage = analyze_index_usage
      @slow_queries = recent_slow_queries
    end

    def job_queue_stats
      @queue_stats = {
        enqueued: SolidQueue::Job.where(finished_at: nil).count,
        failed: SolidQueue::Job.where("failed_at IS NOT NULL").count,
        processing: SolidQueue::Job.where(finished_at: nil, failed_at: nil)
                                  .where("started_at IS NOT NULL").count,
        scheduled: SolidQueue::Job.where("scheduled_at > ?", Time.current).count
      }

      @queue_performance = calculate_queue_performance
      @job_types = job_type_breakdown
    end

    private

    def require_admin!
      unless current_user&.admin?
        redirect_to root_path, alert: "Admin access required"
      end
    end

    def gather_performance_metrics
      {
        request_rate: calculate_request_rate,
        average_response_time: calculate_average_response_time,
        error_rate: calculate_error_rate,
        memory_usage: memory_usage_stats,
        cpu_usage: cpu_usage_stats,
        active_connections: ActiveRecord::Base.connection_pool.connections.size,
        cache_hit_rate: CacheManager.stats[:metrics][:hit_rate]
      }
    end

    def check_system_health
      health_controller = HealthController.new
      health_controller.request = request

      # Call the private method through send (only for internal use)
      checks = health_controller.send(:perform_readiness_checks)
      health_controller.send(:calculate_overall_status, checks)
    end

    def database_pool_stats
      pool = ActiveRecord::Base.connection_pool
      {
        size: pool.size,
        connections: pool.connections.size,
        busy: pool.connections.count(&:in_use?),
        dead: pool.connections.count(&:dead?),
        idle: pool.connections.count { |c| !c.in_use? && !c.dead? },
        waiting: pool.num_waiting_in_queue
      }
    end

    def calculate_table_sizes
      query = <<-SQL
        SELECT#{' '}
          schemaname,
          tablename,
          pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
          pg_total_relation_size(schemaname||'.'||tablename) AS size_bytes
        FROM pg_tables
        WHERE schemaname = 'public'
        ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
        LIMIT 20
      SQL

      ActiveRecord::Base.connection.execute(query).to_a
    rescue
      []
    end

    def analyze_index_usage
      query = <<-SQL
        SELECT#{' '}
          schemaname,
          tablename,
          indexname,
          idx_scan,
          idx_tup_read,
          idx_tup_fetch,
          pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
        FROM pg_stat_user_indexes
        WHERE schemaname = 'public'
        ORDER BY idx_scan DESC
        LIMIT 20
      SQL

      ActiveRecord::Base.connection.execute(query).to_a
    rescue
      []
    end

    def recent_slow_queries
      # This would integrate with pg_stat_statements or your query logging
      # For now, return QueryAnalyzer data if available
      if QueryAnalyzer.enabled
        QueryAnalyzer.report[:slowest_queries] || []
      else
        []
      end
    end

    def calculate_request_rate
      # Calculate from logs or APM tool
      Rails.cache.read("metrics:request_rate") || 0
    end

    def calculate_average_response_time
      Rails.cache.read("metrics:avg_response_time") || 0
    end

    def calculate_error_rate
      Rails.cache.read("metrics:error_rate") || 0
    end

    def memory_usage_stats
      if defined?(GetProcessMem)
        mem = GetProcessMem.new
        {
          rss_mb: (mem.rss / 1024.0 / 1024.0).round(2),
          percentage: mem.percent_memory.round(2)
        }
      else
        rss = `ps -o rss= -p #{Process.pid}`.to_i / 1024.0
        { rss_mb: rss.round(2), percentage: 0.0 }
      end
    rescue
      { rss_mb: 0, percentage: 0.0 }
    end

    def cpu_usage_stats
      # Get CPU usage for current process
      cpu_info = `ps -o %cpu= -p #{Process.pid}`.strip.to_f
      { percentage: cpu_info }
    rescue
      { percentage: 0.0 }
    end

    def calculate_queue_performance
      jobs = SolidQueue::Job.where("finished_at IS NOT NULL")
                           .where("created_at > ?", 1.hour.ago)
                           .limit(100)

      if jobs.any?
        processing_times = jobs.map { |j| (j.finished_at - j.started_at).to_f }
        {
          avg_processing_time: (processing_times.sum / processing_times.size).round(2),
          min_processing_time: processing_times.min.round(2),
          max_processing_time: processing_times.max.round(2)
        }
      else
        { avg_processing_time: 0, min_processing_time: 0, max_processing_time: 0 }
      end
    rescue
      { avg_processing_time: 0, min_processing_time: 0, max_processing_time: 0 }
    end

    def job_type_breakdown
      SolidQueue::Job.group(:queue_name)
                    .where("created_at > ?", 1.day.ago)
                    .count
    rescue
      {}
    end
  end
end
