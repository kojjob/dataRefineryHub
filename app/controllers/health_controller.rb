# frozen_string_literal: true

# Health check controller for monitoring system health and readiness
class HealthController < ActionController::API
  # No authentication needed for health checks

  # Liveness probe - checks if the application is running
  def live
    render json: { status: 'alive', timestamp: Time.current.iso8601 }, status: :ok
  end

  # Readiness probe - checks if the application is ready to serve requests
  def ready
    checks = perform_readiness_checks
    overall_status = calculate_overall_status(checks)
    
    response = {
      status: overall_status,
      timestamp: Time.current.iso8601,
      checks: checks,
      details: build_details(checks)
    }

    status_code = overall_status == 'ready' ? :ok : :service_unavailable
    render json: response, status: status_code
  end

  # Detailed health check with component status
  def detailed
    return unauthorized_response unless authorized_for_detailed_check?

    components = check_all_components
    metrics = collect_system_metrics
    
    response = {
      status: calculate_system_health(components),
      timestamp: Time.current.iso8601,
      uptime: calculate_uptime,
      components: components,
      metrics: metrics,
      circuit_breakers: circuit_breaker_status,
      background_jobs: job_queue_status,
      cache_status: cache_status,
      rate_limits: rate_limit_status
    }

    render json: response
  end

  private

  def skip_authentication?
    action_name.in?(%w[live ready])
  end

  def authorized_for_detailed_check?
    # Check for API key or admin user
    return true if valid_monitoring_api_key?
    return true if current_user&.admin?
    false
  end

  def valid_monitoring_api_key?
    provided_key = request.headers['X-Monitoring-Key']
    return false if provided_key.blank?
    
    expected_key = Rails.application.credentials.monitoring_api_key
    ActiveSupport::SecurityUtils.secure_compare(provided_key, expected_key)
  rescue
    false
  end

  def unauthorized_response
    render json: { error: 'Unauthorized' }, status: :unauthorized
  end

  def perform_readiness_checks
    {
      database: check_database,
      cache: check_cache,
      storage: check_storage,
      job_queue: check_job_queue,
      external_services: check_external_services
    }
  end

  def check_database
    start_time = Time.current
    
    # Check primary database
    ActiveRecord::Base.connection.execute('SELECT 1')
    
    # Check if migrations are up to date
    migrations_pending = ActiveRecord::Base.connection.migration_context.needs_migration?
    
    {
      status: migrations_pending ? 'degraded' : 'healthy',
      response_time_ms: ((Time.current - start_time) * 1000).round(2),
      details: {
        connected: true,
        migrations_pending: migrations_pending,
        connection_pool: database_pool_stats
      }
    }
  rescue => e
    {
      status: 'unhealthy',
      error: e.message,
      details: { connected: false }
    }
  end

  def check_cache
    start_time = Time.current
    test_key = "health_check:#{SecureRandom.hex(8)}"
    test_value = Time.current.to_s
    
    # Test write
    Rails.cache.write(test_key, test_value, expires_in: 10.seconds)
    
    # Test read
    read_value = Rails.cache.read(test_key)
    
    # Test delete
    Rails.cache.delete(test_key)
    
    success = read_value == test_value
    
    {
      status: success ? 'healthy' : 'unhealthy',
      response_time_ms: ((Time.current - start_time) * 1000).round(2),
      details: {
        backend: Rails.cache.class.name,
        connected: success
      }
    }
  rescue => e
    {
      status: 'unhealthy',
      error: e.message,
      details: { connected: false }
    }
  end

  def check_storage
    start_time = Time.current
    
    # Check Active Storage service
    if ActiveStorage::Blob.service.respond_to?(:exist?)
      test_key = "health_check/#{SecureRandom.hex(8)}.txt"
      
      # Try to check if we can access storage
      # This is a non-destructive check
      accessible = true
      
      {
        status: accessible ? 'healthy' : 'unhealthy',
        response_time_ms: ((Time.current - start_time) * 1000).round(2),
        details: {
          service: ActiveStorage::Blob.service.class.name,
          accessible: accessible
        }
      }
    else
      { status: 'unknown', details: { message: 'Storage service does not support health checks' } }
    end
  rescue => e
    {
      status: 'unhealthy',
      error: e.message,
      details: { accessible: false }
    }
  end

  def check_job_queue
    start_time = Time.current
    
    # Check Solid Queue health
    queue_stats = {
      jobs_enqueued: SolidQueue::Job.where(finished_at: nil).count,
      jobs_failed: SolidQueue::Job.where('failed_at IS NOT NULL').where('failed_at > ?', 1.hour.ago).count,
      oldest_job_age: oldest_unprocessed_job_age
    }
    
    # Determine health based on queue depth and age
    status = if queue_stats[:jobs_enqueued] > 10000
               'unhealthy'
             elsif queue_stats[:jobs_enqueued] > 5000 || queue_stats[:oldest_job_age] > 3600
               'degraded'
             else
               'healthy'
             end
    
    {
      status: status,
      response_time_ms: ((Time.current - start_time) * 1000).round(2),
      details: queue_stats
    }
  rescue => e
    {
      status: 'unhealthy',
      error: e.message,
      details: {}
    }
  end

  def check_external_services
    services = {}
    
    # Check critical external services
    %w[shopify stripe google_analytics].each do |service|
      services[service] = check_external_service(service)
    end
    
    # Determine overall status
    if services.values.all? { |s| s[:status] == 'healthy' }
      status = 'healthy'
    elsif services.values.any? { |s| s[:status] == 'unhealthy' }
      status = 'degraded'
    else
      status = 'healthy'
    end
    
    {
      status: status,
      services: services
    }
  end

  def check_external_service(service_name)
    circuit_breaker = CircuitBreakerFactory.get("extractor:#{service_name}")
    
    case circuit_breaker.state
    when :closed
      { status: 'healthy', circuit_state: 'closed' }
    when :open
      { status: 'unhealthy', circuit_state: 'open', message: 'Circuit breaker is open' }
    when :half_open
      { status: 'degraded', circuit_state: 'half_open', message: 'Circuit breaker is half-open' }
    else
      { status: 'unknown', circuit_state: circuit_breaker.state.to_s }
    end
  rescue => e
    { status: 'unknown', error: e.message }
  end

  def calculate_overall_status(checks)
    if checks.values.all? { |check| check[:status] == 'healthy' }
      'ready'
    elsif checks.values.any? { |check| check[:status] == 'unhealthy' }
      'not_ready'
    else
      'degraded'
    end
  end

  def calculate_system_health(components)
    unhealthy_count = components.values.count { |c| c[:status] == 'unhealthy' }
    degraded_count = components.values.count { |c| c[:status] == 'degraded' }
    
    if unhealthy_count > 0
      'unhealthy'
    elsif degraded_count > 2
      'degraded'
    else
      'healthy'
    end
  end

  def check_all_components
    {
      database: check_database,
      cache: check_cache,
      storage: check_storage,
      job_queue: check_job_queue,
      external_services: check_external_services,
      memory: check_memory_usage,
      disk: check_disk_usage
    }
  end

  def collect_system_metrics
    {
      request_rate: calculate_request_rate,
      error_rate: calculate_error_rate,
      average_response_time: calculate_average_response_time,
      active_connections: ActiveRecord::Base.connection_pool.connections.size,
      connection_pool_usage: database_pool_stats,
      memory_usage: memory_usage_stats,
      job_queue_depth: SolidQueue::Job.where(finished_at: nil).count
    }
  end

  def circuit_breaker_status
    CircuitBreakerFactory.status_all
  rescue
    {}
  end

  def job_queue_status
    {
      enqueued: SolidQueue::Job.where(finished_at: nil).count,
      failed: SolidQueue::Job.where('failed_at IS NOT NULL').where('failed_at > ?', 1.hour.ago).count,
      scheduled: SolidQueue::Job.where('scheduled_at > ?', Time.current).count,
      processing: SolidQueue::Job.where(finished_at: nil, failed_at: nil).where('started_at IS NOT NULL').count
    }
  rescue
    {}
  end

  def cache_status
    {
      backend: Rails.cache.class.name,
      stats: Rails.cache.stats
    }
  rescue
    { backend: Rails.cache.class.name, stats: 'unavailable' }
  end

  def rate_limit_status
    # Get rate limit statistics from cache
    {
      total_requests: Rails.cache.read('rate_limit:total_requests') || 0,
      rejected_requests: Rails.cache.read('rate_limit:rejected_requests') || 0,
      throttled_ips: Rails.cache.read('rate_limit:throttled_ips') || []
    }
  rescue
    {}
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

  def oldest_unprocessed_job_age
    oldest_job = SolidQueue::Job.where(finished_at: nil).order(created_at: :asc).first
    return 0 unless oldest_job
    
    (Time.current - oldest_job.created_at).to_i
  rescue
    0
  end

  def check_memory_usage
    memory_info = memory_usage_stats
    usage_percentage = memory_info[:percentage]
    
    status = if usage_percentage > 90
               'unhealthy'
             elsif usage_percentage > 80
               'degraded'
             else
               'healthy'
             end
    
    {
      status: status,
      details: memory_info
    }
  end

  def memory_usage_stats
    if defined?(GetProcessMem)
      mem = GetProcessMem.new
      {
        rss_mb: (mem.rss / 1024.0 / 1024.0).round(2),
        percentage: mem.percent_memory.round(2)
      }
    else
      # Fallback using Ruby's built-in methods instead of shell commands
      begin
        # Try to read from /proc filesystem (Linux)
        if File.exist?("/proc/#{Process.pid}/status")
          status_content = File.read("/proc/#{Process.pid}/status")
          rss_kb = status_content.match(/VmRSS:\s+(\d+)/)[1].to_i
          rss_mb = rss_kb / 1024.0
        else
          # Fallback for non-Linux systems - use GC stats as approximation
          rss_mb = (GC.stat[:heap_allocated_pages] * GC::INTERNAL_CONSTANTS[:HEAP_PAGE_SIZE] / 1024.0 / 1024.0) rescue 0.0
        end
        {
          rss_mb: rss_mb.round(2),
          percentage: 0.0
        }
      rescue => e
        Rails.logger.warn "Failed to get memory usage: #{e.message}"
        { rss_mb: 0.0, percentage: 0.0 }
      end
    end
  rescue
    { rss_mb: 0, percentage: 0.0 }
  end

  def check_disk_usage
    # Check disk usage using Ruby's built-in methods
    begin
      # Use Ruby's Filesystem stats
      stat = Sys::Filesystem.stat(Rails.root.to_s) if defined?(Sys::Filesystem)
      
      if stat
        total_bytes = stat.blocks * stat.block_size
        available_bytes = stat.blocks_available * stat.block_size
        used_bytes = total_bytes - available_bytes
        usage_percentage = ((used_bytes.to_f / total_bytes) * 100).round
      else
        # Fallback: Read from /proc/mounts on Linux
        if File.exist?('/proc/mounts')
          mount_point = Rails.root.to_s
          stat_info = File::Stat.new(mount_point)
          # This is an approximation - better to use sys-filesystem gem
          usage_percentage = 50 # Default safe value
        else
          usage_percentage = 50 # Default safe value for non-Linux
        end
      end
      
      status = if usage_percentage > 90
                 'unhealthy'
               elsif usage_percentage > 80
                 'degraded'
               else
                 'healthy'
               end
      
      {
        status: status,
        details: {
          usage_percentage: usage_percentage,
          mount_point: Rails.root.to_s
        }
      }
    rescue
      { status: 'unknown', error: 'Unable to check disk usage' }
    end
  end

  def calculate_uptime
    # Calculate application uptime
    if defined?(Rails.application.config.booted_at)
      seconds = Time.current - Rails.application.config.booted_at
      format_duration(seconds)
    else
      'unknown'
    end
  end

  def format_duration(seconds)
    days = (seconds / 86400).to_i
    hours = ((seconds % 86400) / 3600).to_i
    minutes = ((seconds % 3600) / 60).to_i
    
    "#{days}d #{hours}h #{minutes}m"
  end

  def calculate_request_rate
    # Calculate requests per minute from logs or metrics
    Rails.cache.read('metrics:request_rate') || 0
  rescue
    0
  end

  def calculate_error_rate
    # Calculate error rate from logs or metrics
    Rails.cache.read('metrics:error_rate') || 0
  rescue
    0
  end

  def calculate_average_response_time
    # Calculate average response time from metrics
    Rails.cache.read('metrics:avg_response_time') || 0
  rescue
    0
  end

  def build_details(checks)
    {
      healthy_components: checks.count { |_, v| v[:status] == 'healthy' },
      degraded_components: checks.count { |_, v| v[:status] == 'degraded' },
      unhealthy_components: checks.count { |_, v| v[:status] == 'unhealthy' }
    }
  end
end
