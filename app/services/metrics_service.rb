# frozen_string_literal: true

# Service for application metrics and monitoring
class MetricsService
  include Singleton

  # Null implementation for when OpenTelemetry isn't available
  class NullMeter
    def create_counter(name, **options)
      NullInstrument.new
    end

    def create_histogram(name, **options)
      NullInstrument.new
    end
  end

  class NullInstrument
    def add(value, attributes: {}); end
    def record(value, attributes: {}); end
  end

  METRIC_TYPES = {
    counter: "Counter for cumulative values",
    gauge: "Gauge for point-in-time measurements",
    histogram: "Histogram for value distributions"
  }.freeze

  # Business metrics to track
  BUSINESS_METRICS = {
    # API metrics
    "api.requests.total" => { type: :counter, description: "Total API requests" },
    "api.requests.duration" => { type: :histogram, description: "API request duration", unit: "ms" },
    "api.requests.errors" => { type: :counter, description: "API request errors" },
    "api.rate_limit.exceeded" => { type: :counter, description: "Rate limit exceeded events" },

    # Data pipeline metrics
    "pipeline.executions.total" => { type: :counter, description: "Total pipeline executions" },
    "pipeline.executions.duration" => { type: :histogram, description: "Pipeline execution duration", unit: "seconds" },
    "pipeline.executions.failed" => { type: :counter, description: "Failed pipeline executions" },
    "pipeline.records.processed" => { type: :counter, description: "Records processed by pipelines" },
    "pipeline.records.failed" => { type: :counter, description: "Failed record processing" },

    # Data source metrics
    "datasource.syncs.total" => { type: :counter, description: "Total data source syncs" },
    "datasource.syncs.duration" => { type: :histogram, description: "Data sync duration", unit: "seconds" },
    "datasource.syncs.failed" => { type: :counter, description: "Failed data syncs" },
    "datasource.connections.active" => { type: :gauge, description: "Active data source connections" },

    # Job metrics
    "jobs.executed.total" => { type: :counter, description: "Total background jobs executed" },
    "jobs.executed.duration" => { type: :histogram, description: "Job execution duration", unit: "seconds" },
    "jobs.failed.total" => { type: :counter, description: "Failed background jobs" },
    "jobs.queue.size" => { type: :gauge, description: "Job queue size" },
    "jobs.queue.latency" => { type: :histogram, description: "Job queue latency", unit: "seconds" },

    # Business metrics
    "organizations.total" => { type: :gauge, description: "Total organizations" },
    "organizations.active" => { type: :gauge, description: "Active organizations" },
    "users.total" => { type: :gauge, description: "Total users" },
    "users.active.daily" => { type: :gauge, description: "Daily active users" },
    "subscriptions.active" => { type: :gauge, description: "Active subscriptions by tier" },
    "revenue.mrr" => { type: :gauge, description: "Monthly recurring revenue", unit: "USD" },

    # System metrics
    "system.memory.used" => { type: :gauge, description: "Memory usage", unit: "bytes" },
    "system.cpu.usage" => { type: :gauge, description: "CPU usage percentage" },
    "database.connections.active" => { type: :gauge, description: "Active database connections" },
    "database.queries.slow" => { type: :counter, description: "Slow database queries" }
  }.freeze

  attr_reader :meter, :metrics

  def initialize
    setup_opentelemetry
    @metrics = {}
    initialize_metrics
  end

  # Increment a counter metric
  def self.increment(metric_name, value: 1, tags: {})
    instance.increment(metric_name, value: value, tags: tags)
  end

  # Set a gauge value
  def self.gauge(metric_name, value, tags: {})
    instance.gauge(metric_name, value, tags: tags)
  end

  # Record a histogram value
  def self.histogram(metric_name, value, tags: {})
    instance.histogram(metric_name, value, tags: tags)
  end

  # Time a block and record duration
  def self.time(metric_name, tags: {})
    instance.time(metric_name, tags: tags) { yield }
  end

  # Record business metrics
  def self.record_business_metrics
    instance.record_business_metrics
  end

  def increment(metric_name, value: 1, tags: {})
    metric = get_or_create_metric(metric_name, :counter)
    metric.add(value, attributes: format_tags(tags))
  rescue => e
    Rails.logger.error "Failed to increment metric #{metric_name}: #{e.message}"
  end

  def gauge(metric_name, value, tags: {})
    # For gauges, we'll use a histogram and take the last value
    metric = get_or_create_metric(metric_name, :histogram)
    metric.record(value, attributes: format_tags(tags))
  rescue => e
    Rails.logger.error "Failed to set gauge #{metric_name}: #{e.message}"
  end

  def histogram(metric_name, value, tags: {})
    metric = get_or_create_metric(metric_name, :histogram)
    metric.record(value, attributes: format_tags(tags))
  rescue => e
    Rails.logger.error "Failed to record histogram #{metric_name}: #{e.message}"
  end

  def time(metric_name, tags: {})
    start_time = Time.current
    result = yield
    duration_ms = (Time.current - start_time) * 1000

    histogram(metric_name, duration_ms, tags: tags)
    result
  rescue => e
    duration_ms = (Time.current - start_time) * 1000
    histogram(metric_name, duration_ms, tags: tags.merge(status: "error"))
    raise
  end

  def record_business_metrics
    # Organization metrics
    gauge("organizations.total", Organization.count)
    gauge("organizations.active", Organization.active.count)

    # User metrics
    gauge("users.total", User.count)
    gauge("users.active.daily", User.where("last_sign_in_at > ?", 24.hours.ago).count)

    # Subscription metrics by tier
    Organization.group(:subscription_tier).count.each do |tier, count|
      gauge("subscriptions.active", count, tags: { tier: tier })
    end

    # Data source metrics
    DataSource.group(:status).count.each do |status, count|
      gauge("datasource.connections.active", count, tags: { status: status })
    end

    # Job queue metrics
    begin
      gauge("jobs.queue.size", SolidQueue::ReadyExecution.count)
    rescue => e
      Rails.logger.error "Failed to get queue size: #{e.message}"
      gauge("jobs.queue.size", 0)
    end

    # System metrics
    record_system_metrics
  rescue => e
    Rails.logger.error "Failed to record business metrics: #{e.message}"
  end

  private

  def setup_opentelemetry
    # Skip OpenTelemetry setup for now - it's causing initialization issues
    # We'll use a null implementation
    @meter = NullMeter.new
  rescue => e
    Rails.logger.error "Failed to setup OpenTelemetry: #{e.message}"
    @meter = NullMeter.new
  end

  def initialize_metrics
    BUSINESS_METRICS.each do |name, config|
      create_metric(name, config[:type], config[:description], config[:unit])
    end
  end

  def get_or_create_metric(name, type)
    @metrics[name] ||= create_metric(name, type)
  end

  def create_metric(name, type, description = nil, unit = nil)
    return NullInstrument.new unless @meter

    case type
    when :counter
      @meter.create_counter(
        name,
        unit: unit || "1",
        description: description || "Counter for #{name}"
      )
    when :histogram
      @meter.create_histogram(
        name,
        unit: unit || "1",
        description: description || "Histogram for #{name}"
      )
    else
      NullInstrument.new
    end
  rescue => e
    Rails.logger.error "Failed to create metric #{name}: #{e.message}"
    NullInstrument.new
  end

  def format_tags(tags)
    # Convert tags to OpenTelemetry attributes format
    tags.transform_keys(&:to_s).transform_values(&:to_s)
  end

  def record_system_metrics
    # Memory metrics
    memory_info = get_memory_info
    gauge("system.memory.used", memory_info[:used_bytes])

    # CPU metrics
    cpu_usage = get_cpu_usage
    gauge("system.cpu.usage", cpu_usage)

    # Database metrics
    db_stats = ActiveRecord::Base.connection_pool.stat
    gauge("database.connections.active", db_stats[:busy])
    gauge("database.connections.idle", db_stats[:idle])
  end

  def get_memory_info
    # Get memory usage from system
    if File.exist?("/proc/meminfo")
      meminfo = File.read("/proc/meminfo")
      total = meminfo.match(/MemTotal:\s+(\d+)/).captures.first.to_i * 1024
      available = meminfo.match(/MemAvailable:\s+(\d+)/).captures.first.to_i * 1024
      {
        total_bytes: total,
        available_bytes: available,
        used_bytes: total - available
      }
    else
      # Fallback for non-Linux systems
      {
        total_bytes: 0,
        available_bytes: 0,
        used_bytes: 0
      }
    end
  end

  def get_cpu_usage
    # Simple CPU usage calculation
    if File.exist?("/proc/stat")
      stat1 = File.read("/proc/stat").lines.first.split.map(&:to_i)
      sleep 0.1
      stat2 = File.read("/proc/stat").lines.first.split.map(&:to_i)

      idle_diff = stat2[4] - stat1[4]
      total_diff = stat2[1..-1].sum - stat1[1..-1].sum

      ((total_diff - idle_diff).to_f / total_diff * 100).round(2)
    else
      0.0
    end
  end
end

# Initialize metrics collection job
if defined?(Rails::Server) && !Rails.env.test?
  Rails.application.config.after_initialize do
    # Record business metrics every minute
    begin
      MetricsCollectorJob.perform_later
    rescue => e
      Rails.logger.error "Failed to enqueue MetricsCollectorJob: #{e.message}"
    end
  end
end
