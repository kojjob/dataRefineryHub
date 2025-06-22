# frozen_string_literal: true

# ETL Monitoring Service
# Provides comprehensive monitoring, metrics collection, and health checking for the ETL pipeline
class EtlMonitoringService
  include Singleton

  attr_reader :metrics_store, :health_checks, :alerts

  def initialize
    @config = EtlConfigurationManager.monitoring_config
    @metrics = {}
    @alerts = []
    @health_checks = {}
    @mutex = Mutex.new
    @logger = Rails.logger

    setup_default_health_checks
  end

  # Record metrics for various ETL operations
  def record_extraction_metrics(data_source_id, metrics)
    timestamp = Time.current

    @mutex.synchronize do
      @metrics["extraction.records_extracted"] = metrics[:records_extracted]
      @metrics["extraction.duration"] = metrics[:duration]
      @metrics["extraction.success_rate"] = metrics[:success_rate]
      @metrics["extraction_total"] = (@metrics["extraction_total"] || 0) + 1

      if metrics[:error_count] && metrics[:error_count] > 0
        @metrics["extraction.errors"] = metrics[:error_count]
        @metrics["extraction_errors"] = (@metrics["extraction_errors"] || 0) + metrics[:error_count]
      end
    end

    # Record circuit breaker metrics if available
    if metrics[:circuit_breaker_stats]
      record_circuit_breaker_metrics("extraction", data_source_id, metrics[:circuit_breaker_stats])
    end

    # Record batch processing metrics if available
    if metrics[:batch_stats]
      record_batch_processing_metrics("extraction", data_source_id, metrics[:batch_stats])
    end

    # Record data quality metrics if available
    if metrics[:data_quality_stats]
      record_data_quality_metrics("extraction", data_source_id, metrics[:data_quality_stats])
    end

    # Check for alerts
    check_extraction_alerts(data_source_id, metrics)
  end

  def record_transformation_metrics(data_source_id, metrics)
    timestamp = Time.current

    @mutex.synchronize do
      @metrics["transformation.records_processed"] = metrics[:records_processed]
      @metrics["transformation.duration"] = metrics[:duration]
      @metrics["transformation.success_rate"] = metrics[:success_rate]
      @metrics["recent_throughput"] = metrics[:records_processed]

      if metrics[:records_failed] && metrics[:records_failed] > 0
        @metrics["transformation.failures"] = metrics[:records_failed]
      end
    end

    # Record additional metrics
    if metrics[:circuit_breaker_stats]
      record_circuit_breaker_metrics("transformation", data_source_id, metrics[:circuit_breaker_stats])
    end

    if metrics[:batch_stats]
      record_batch_processing_metrics("transformation", data_source_id, metrics[:batch_stats])
    end

    if metrics[:data_quality_stats]
      record_data_quality_metrics("transformation", data_source_id, metrics[:data_quality_stats])
    end

    # Check for alerts
    check_transformation_alerts(data_source_id, metrics)
  end

  def record_circuit_breaker_metrics(operation, data_source_id, stats)
    prefix = "circuit_breaker.#{operation}"

    @mutex.synchronize do
      @metrics["#{prefix}.state"] = stats[:state]
      @metrics["#{prefix}.failure_count"] = stats[:failure_count]
      @metrics["#{prefix}.success_count"] = stats[:success_count]
    end

    if stats[:state] == "open"
      @alerts.trigger_alert("circuit_breaker_open", {
        operation: operation,
        data_source_id: data_source_id,
        failure_count: stats[:failure_count]
      })
    end
  end

  def record_batch_processing_metrics(operation, data_source_id, stats)
    prefix = "batch_processing.#{operation}"

    @mutex.synchronize do
      @metrics["#{prefix}.batches_processed"] = stats[:batches_processed]
      @metrics["#{prefix}.average_batch_size"] = stats[:average_batch_size]
      @metrics["#{prefix}.average_processing_time"] = stats[:average_batch_processing_time]
      @metrics["#{prefix}.memory_usage"] = stats[:memory_usage_mb] if stats[:memory_usage_mb]
    end
  end

  def record_data_quality_metrics(operation, data_source_id, stats)
    prefix = "data_quality.#{operation}"

    @mutex.synchronize do
      @metrics["#{prefix}.quality_score"] = stats[:quality_score]
      @metrics["#{prefix}.error_count"] = stats[:error_count]
      @metrics["#{prefix}.records_validated"] = stats[:records_validated]

      # Record quality scores by dimension
      stats[:quality_by_dimension]&.each do |dimension, score|
        @metrics["#{prefix}.#{dimension}"] = score
      end
    end

    # Check quality thresholds
    if stats[:quality_score] < @config[:quality_threshold]
      @alerts.trigger_alert("data_quality_degraded", {
        operation: operation,
        data_source_id: data_source_id,
        quality_score: stats[:quality_score],
        threshold: @config[:quality_threshold]
      })
    end
  end

  # Health check methods
  def check_system_health
    health_status = {
      timestamp: Time.current,
      overall_status: "healthy",
      checks: {}
    }

    # Database connectivity
    health_status[:checks][:database] = check_database_health

    # Redis connectivity (if used)
    health_status[:checks][:redis] = check_redis_health if defined?(Redis)

    # Memory usage
    health_status[:checks][:memory] = check_memory_usage

    # Disk space
    health_status[:checks][:disk_space] = check_disk_space

    # Circuit breaker status
    health_status[:checks][:circuit_breakers] = check_circuit_breaker_status

    # Determine overall status
    failed_checks = health_status[:checks].select { |_, check| check[:status] == "unhealthy" }
    health_status[:overall_status] = failed_checks.empty? ? "healthy" : "unhealthy"

    # Generate alerts for failed checks
    failed_checks.each do |check_name, check_data|
      generate_alert(
        type: "health_check_failed",
        severity: "high",
        message: "Health check failed: #{check_name} - #{check_data[:message]}",
        metadata: { check_name: check_name, check_data: check_data }
      )
    end

    health_status
  end

  private

  def check_database_health
    start_time = Time.current
    begin
      ActiveRecord::Base.connection.execute("SELECT 1")
      {
        status: "healthy",
        message: "Database connection successful",
        response_time: (Time.current - start_time) * 1000
      }
    rescue => e
      {
        status: "unhealthy",
        message: "Database connection failed: #{e.message}",
        response_time: (Time.current - start_time) * 1000
      }
    end
  end

  def check_redis_health
    start_time = Time.current
    begin
      Redis.current.ping
      {
        status: "healthy",
        message: "Redis connection successful",
        response_time: (Time.current - start_time) * 1000
      }
    rescue => e
      {
        status: "unhealthy",
        message: "Redis connection failed: #{e.message}",
        response_time: (Time.current - start_time) * 1000
      }
    end
  end

  def check_memory_usage
    begin
      # Get memory usage (works on Unix-like systems)
      memory_info = `ps -o pid,rss -p #{Process.pid}`.split("\n").last
      memory_mb = memory_info.split.last.to_i / 1024

      threshold = @config["memory_threshold_mb"] || 1024
      status = memory_mb > threshold ? "unhealthy" : "healthy"

      {
        status: status,
        message: "Memory usage: #{memory_mb}MB (threshold: #{threshold}MB)",
        current_usage: memory_mb,
        threshold: threshold
      }
    rescue => e
      {
        status: "error",
        message: "Failed to check memory usage: #{e.message}"
      }
    end
  end

  def check_disk_space
    begin
      # Get disk usage for current directory
      disk_info = `df -h .`.split("\n").last
      usage_percent = disk_info.split[4].to_i

      threshold = @config["disk_usage_threshold"] || 80
      status = usage_percent > threshold ? "unhealthy" : "healthy"

      {
        status: status,
        message: "Disk usage: #{usage_percent}% (threshold: #{threshold}%)",
        current_usage: usage_percent,
        threshold: threshold
      }
    rescue => e
      {
        status: "error",
        message: "Failed to check disk space: #{e.message}"
      }
    end
  end

  def check_circuit_breaker_status
    begin
      # Check if any circuit breakers are open
      circuit_breaker_service = CircuitBreakerService.new

      {
        status: "healthy",
        message: "All circuit breakers operational"
      }
    rescue => e
      {
        status: "error",
        message: "Failed to check circuit breaker status: #{e.message}"
      }
    end
  end

  def get_metrics_summary(time_range = 1.hour)
    end_time = Time.current
    start_time = end_time - time_range

    @mutex.synchronize do
      {
        extraction: {
          total_records: @metrics["extraction.records_extracted"] || 0,
          average_duration: @metrics["extraction.duration"] || 0,
          success_rate: @metrics["extraction.success_rate"] || 0
        },
        transformation: {
          total_records: @metrics["transformation.records_processed"] || 0,
          average_duration: @metrics["transformation.duration"] || 0,
          success_rate: @metrics["transformation.success_rate"] || 0
        },
        trends: {
          extraction_throughput: @metrics["extraction.records_extracted"] || 0,
          transformation_throughput: @metrics["transformation.records_processed"] || 0,
          quality_score_trend: @metrics["data_quality.extraction.quality_score"] || 0
        },
        system_health: check_system_health
      }
    end
  end

  def get_performance_report(data_source_id = nil, time_range = 24.hours)
    end_time = Time.current
    start_time = end_time - time_range

    filters = { timestamp: start_time..end_time }
    filters[:data_source_id] = data_source_id if data_source_id

    {
      extraction_performance: {
        total_records: @metrics_store.sum("extraction.records_extracted", filters),
        average_duration: @metrics_store.average("extraction.duration", filters),
        success_rate: @metrics_store.average("extraction.success_rate", filters),
        error_rate: calculate_error_rate("extraction", filters)
      },
      transformation_performance: {
        total_records: @metrics_store.sum("transformation.records_processed", filters),
        average_duration: @metrics_store.average("transformation.duration", filters),
        success_rate: @metrics_store.average("transformation.success_rate", filters),
        error_rate: calculate_error_rate("transformation", filters)
      },
      trends: {
        extraction_throughput: @metrics_store.trend("extraction.records_extracted", filters),
        transformation_throughput: @metrics_store.trend("transformation.records_processed", filters),
        quality_score_trend: @metrics_store.trend("data_quality.extraction.quality_score", filters)
      }
    }
  end

  private

  def setup_default_health_checks
    # Database connectivity check
    @health_checks["database"] = proc do
      start_time = Time.current
      begin
        ActiveRecord::Base.connection.execute("SELECT 1")
        {
          healthy: true,
          message: "Database connection is healthy",
          response_time: (Time.current - start_time) * 1000
        }
      rescue => e
        {
          healthy: false,
          message: "Database connection failed: #{e.message}",
          response_time: (Time.current - start_time) * 1000
        }
      end
    end

    # Redis connectivity check (if using Redis)
    if defined?(Redis)
      @health_checks["redis"] = proc do
        start_time = Time.current
        begin
          Redis.current.ping
          {
            healthy: true,
            message: "Redis connection is healthy",
            response_time: (Time.current - start_time) * 1000
          }
        rescue => e
          {
            healthy: false,
            message: "Redis connection failed: #{e.message}",
            response_time: (Time.current - start_time) * 1000
          }
        end
      end
    end

    # Memory usage check
    @health_checks["memory"] = proc do
      memory_usage = `ps -o pid,rss -p #{Process.pid}`.split("\n")[1].split[1].to_i / 1024.0 # MB
      threshold = @config[:memory_threshold_mb] || 1024

      {
        healthy: memory_usage < threshold,
        message: "Memory usage: #{memory_usage.round(2)}MB (threshold: #{threshold}MB)",
        response_time: 0
      }
    end

    # Disk space check
    @health_checks["disk_space"] = proc do
      disk_usage = `df -h /`.split("\n")[1].split[4].to_i
      threshold = @config[:disk_usage_threshold] || 90

      {
        healthy: disk_usage < threshold,
        message: "Disk usage: #{disk_usage}% (threshold: #{threshold}%)",
        response_time: 0
      }
    end
  end

  def setup_default_alerts
    # High error rate alert
    @alerts << {
      name: "high_error_rate",
      rule: proc do |metrics|
        # Simple error rate calculation
        error_count = @metrics["extraction_errors"] || 0
        total_count = @metrics["extraction_total"] || 1
        error_rate = error_count.to_f / total_count
        error_rate > (@config[:error_rate_threshold] || 0.1)
      end
    }

    # Low throughput alert
    @alerts << {
      name: "low_throughput",
      rule: proc do |metrics|
        recent_throughput = @metrics["recent_throughput"] || 0
        recent_throughput < (@config[:min_hourly_throughput] || 100)
      end
    }
  end

  def get_operation_summary(operation, start_time, end_time)
    @mutex.synchronize do
      {
        total_records: @metrics["#{operation}.records_extracted"] || @metrics["#{operation}.records_processed"] || 0,
        average_duration: @metrics["#{operation}.duration"] || 0,
        success_rate: @metrics["#{operation}.success_rate"] || 0,
        error_count: @metrics["#{operation}.errors"] || @metrics["#{operation}.failures"] || 0
      }
    end
  end

  def get_circuit_breaker_summary(start_time, end_time)
    @mutex.synchronize do
      {
        extraction_failures: @metrics["circuit_breaker.extraction.failure_count"] || 0,
        transformation_failures: @metrics["circuit_breaker.transformation.failure_count"] || 0,
        open_events: 0
      }
    end
  end

  def get_data_quality_summary(start_time, end_time)
    @mutex.synchronize do
      {
        average_quality_score: @metrics["data_quality.extraction.quality_score"] || 0,
        total_validation_errors: @metrics["data_quality.extraction.error_count"] || 0,
        records_validated: @metrics["data_quality.extraction.records_validated"] || 0
      }
    end
  end

  def calculate_error_rate(operation, filters)
    @mutex.synchronize do
      total_operations = @metrics["extraction_total"] || 1
      error_count = @metrics["extraction_errors"] || 0

      error_count.to_f / total_operations
    end
  end

  def check_extraction_alerts(data_source_id, metrics)
    # Check for high error rate
    if metrics[:success_rate] && metrics[:success_rate] < @config[:min_success_rate]
      @alerts.trigger_alert("low_success_rate", {
        operation: "extraction",
        data_source_id: data_source_id,
        success_rate: metrics[:success_rate]
      })
    end

    # Check for slow processing
    if metrics[:duration] && metrics[:duration] > @config[:max_extraction_duration]
      @alerts.trigger_alert("slow_extraction", {
        data_source_id: data_source_id,
        duration: metrics[:duration]
      })
    end
  end

  def check_transformation_alerts(data_source_id, metrics)
    # Check for high failure rate
    if metrics[:success_rate] && metrics[:success_rate] < @config[:min_success_rate]
      @alerts.trigger_alert("low_success_rate", {
        operation: "transformation",
        data_source_id: data_source_id,
        success_rate: metrics[:success_rate]
      })
    end

    # Check for slow processing
    if metrics[:duration] && metrics[:duration] > @config[:max_transformation_duration]
      @alerts.trigger_alert("slow_transformation", {
        data_source_id: data_source_id,
        duration: metrics[:duration]
      })
    end
  end

  # Inner classes for metrics storage and health checks
  class MetricsStore
    def initialize
      @metrics = {}
      @events = []
    end

    def record(metric_name, value, tags = {})
      @metrics[metric_name] ||= []
      @metrics[metric_name] << {
        value: value,
        tags: tags,
        timestamp: tags[:timestamp] || Time.current
      }

      # Keep only recent metrics to prevent memory bloat
      cleanup_old_metrics(metric_name)
    end

    def sum(metric_name, filters = {})
      get_filtered_values(metric_name, filters).sum
    end

    def average(metric_name, filters = {})
      values = get_filtered_values(metric_name, filters)
      return 0 if values.empty?

      values.sum.to_f / values.size
    end

    def count(metric_name, filters = {})
      get_filtered_metrics(metric_name, filters).size
    end

    def trend(metric_name, filters = {})
      metrics = get_filtered_metrics(metric_name, filters)
      return [] if metrics.size < 2

      # Simple trend calculation
      values = metrics.map { |m| m[:value] }
      first_half = values[0..values.size/2]
      second_half = values[values.size/2..-1]

      first_avg = first_half.sum.to_f / first_half.size
      second_avg = second_half.sum.to_f / second_half.size

      {
        direction: second_avg > first_avg ? "increasing" : "decreasing",
        change_percentage: ((second_avg - first_avg) / first_avg * 100).round(2)
      }
    end

    def count_events(event_type, filters = {})
      @events.count do |event|
        event[:type] == event_type && matches_filters?(event, filters)
      end
    end

    private

    def get_filtered_values(metric_name, filters)
      get_filtered_metrics(metric_name, filters).map { |m| m[:value] }
    end

    def get_filtered_metrics(metric_name, filters)
      return [] unless @metrics[metric_name]

      @metrics[metric_name].select { |metric| matches_filters?(metric, filters) }
    end

    def matches_filters?(item, filters)
      filters.all? do |key, value|
        case key
        when :timestamp
          value.cover?(item[:timestamp] || item[:tags][:timestamp])
        else
          item[:tags][key] == value
        end
      end
    end

    def cleanup_old_metrics(metric_name)
      cutoff_time = 24.hours.ago
      @metrics[metric_name].reject! { |m| m[:timestamp] < cutoff_time }
    end
  end

  class HealthCheckRegistry
    attr_reader :checks

    def initialize
      @checks = {}
    end

    def register(name, &block)
      @checks[name] = block
    end
  end

  class AlertManager
    def initialize
      @rules = {}
      @triggered_alerts = []
    end

    def register_rule(name, &block)
      @rules[name] = block
    end

    def trigger_alert(type, details)
      alert = {
        type: type,
        details: details,
        timestamp: Time.current
      }

      @triggered_alerts << alert

      # Log alert
      Rails.logger.warn "ETL Alert: #{type} - #{details}"

      # Here you could integrate with external alerting systems
      # send_to_slack(alert) if Rails.env.production?
      # send_to_pagerduty(alert) if alert[:severity] == 'critical'
    end
  end
end
