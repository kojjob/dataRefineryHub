# frozen_string_literal: true

class PerformanceMonitorService
  include Singleton

  def self.track(operation, metadata = {})
    instance.track(operation, metadata)
  end

  def self.track_with_result(operation, metadata = {})
    instance.track_with_result(operation, metadata) { yield }
  end

  def track(operation, metadata = {})
    start_time = Time.current
    
    begin
      result = yield if block_given?
      duration = (Time.current - start_time) * 1000 # Convert to milliseconds
      
      log_performance(
        operation: operation,
        duration: duration,
        status: 'success',
        metadata: metadata
      )
      
      result
    rescue => e
      duration = (Time.current - start_time) * 1000
      
      log_performance(
        operation: operation,
        duration: duration,
        status: 'error',
        error: e.class.name,
        metadata: metadata
      )
      
      raise
    end
  end

  def track_with_result(operation, metadata = {})
    start_time = Time.current
    
    result = yield
    duration = (Time.current - start_time) * 1000
    
    status = result.respond_to?(:success?) ? (result.success? ? 'success' : 'failure') : 'unknown'
    
    log_performance(
      operation: operation,
      duration: duration,
      status: status,
      metadata: metadata.merge(result_metadata(result))
    )
    
    result
  end

  def log_slow_queries(threshold_ms = 1000)
    ActiveSupport::Notifications.subscribe('sql.active_record') do |name, start, finish, id, payload|
      duration = (finish - start) * 1000
      
      if duration > threshold_ms
        Rails.logger.warn({
          event: 'slow_query',
          duration_ms: duration.round(2),
          sql: payload[:sql],
          name: payload[:name]
        }.to_json)
      end
    end
  end

  def memory_usage
    {
      rss: `ps -o rss= -p #{Process.pid}`.to_i, # Resident Set Size in KB
      heap_size: GC.stat[:heap_live_slots],
      heap_free: GC.stat[:heap_free_slots],
      gc_count: GC.count
    }
  end

  def system_metrics
    {
      timestamp: Time.current.iso8601,
      memory: memory_usage,
      active_record_pool: ActiveRecord::Base.connection_pool.stat,
      redis_info: redis_info
    }
  end

  private

  def log_performance(data)
    Rails.logger.info({
      event: 'performance_metric',
      **data,
      timestamp: Time.current.iso8601
    }.to_json)
    
    # Send to external monitoring service if configured
    send_to_monitoring_service(data) if monitoring_service_configured?
  end

  def result_metadata(result)
    return {} unless result.respond_to?(:metadata)
    
    {
      result_data_size: result.data&.size,
      result_errors_count: result.errors&.size || 0
    }
  end

  def redis_info
    return {} unless defined?(Redis)
    
    begin
      Redis.current.info.slice('used_memory', 'connected_clients', 'total_commands_processed')
    rescue => e
      { error: e.message }
    end
  end

  def monitoring_service_configured?
    Rails.application.credentials.dig(:monitoring, :enabled) || false
  end

  def send_to_monitoring_service(data)
    # Implement integration with monitoring services like DataDog, New Relic, etc.
    # This is a placeholder for external monitoring integration
  end
end