# frozen_string_literal: true

class ProcessingMetricsService
  include ActiveModel::Model

  attr_accessor :organization_id, :time_window

  def initialize(organization_id:, time_window: 1.hour)
    @organization_id = organization_id
    @time_window = time_window
    @start_time = Time.current - time_window
    @end_time = Time.current
  end

  def generate_metrics_report
    {
      processing_overview: processing_overview,
      performance_metrics: performance_metrics,
      error_analytics: error_analytics,
      data_quality_metrics: data_quality_metrics,
      resource_utilization: resource_utilization,
      circuit_breaker_status: circuit_breaker_status,
      real_time_stats: real_time_stats,
      generated_at: Time.current.iso8601
    }
  end

  def log_processing_event(event_type, data = {})
    structured_log = {
      timestamp: Time.current.iso8601,
      organization_id: @organization_id,
      event_type: event_type,
      data: data,
      environment: Rails.env,
      service: "data_refinery_platform"
    }

    # Log to Rails logger with structured format
    Rails.logger.info "[PROCESSING_METRICS] #{structured_log.to_json}"

    # Store in cache for real-time monitoring
    cache_key = "processing_events:#{@organization_id}:#{Date.current.strftime('%Y%m%d')}"
    cached_events = Rails.cache.read(cache_key) || []
    cached_events << structured_log

    # Keep only last 1000 events per day
    cached_events = cached_events.last(1000)
    Rails.cache.write(cache_key, cached_events, expires_in: 2.days)
  end

  private

  def processing_overview
    jobs = extraction_jobs_in_window

    {
      total_jobs: jobs.count,
      completed_jobs: jobs.completed.count,
      failed_jobs: jobs.failed.count,
      running_jobs: jobs.running.count,
      pending_jobs: jobs.pending.count,
      success_rate: calculate_success_rate(jobs),
      average_processing_time: calculate_average_processing_time(jobs),
      total_records_processed: jobs.sum(:records_processed) || 0
    }
  end

  def performance_metrics
    jobs = extraction_jobs_in_window.completed
    return {} if jobs.empty?

    processing_times = jobs.where.not(started_at: nil, completed_at: nil)
                          .map { |job| job.completed_at - job.started_at }

    records_per_minute = jobs.map do |job|
      next 0 unless job.started_at && job.completed_at && job.records_processed
      duration_minutes = (job.completed_at - job.started_at) / 60.0
      duration_minutes > 0 ? job.records_processed / duration_minutes : 0
    end.compact

    {
      processing_times: {
        min: processing_times.min&.round(2),
        max: processing_times.max&.round(2),
        average: (processing_times.sum / processing_times.length).round(2),
        median: calculate_median(processing_times)&.round(2)
      },
      throughput: {
        records_per_minute: {
          min: records_per_minute.min&.round(2),
          max: records_per_minute.max&.round(2),
          average: records_per_minute.empty? ? 0 : (records_per_minute.sum / records_per_minute.length).round(2)
        }
      },
      queue_metrics: queue_metrics
    }
  end

  def error_analytics
    failed_jobs = extraction_jobs_in_window.failed

    error_categories = failed_jobs.group_by do |job|
      job.error_metadata&.dig("error_category") || "unknown"
    end

    error_frequency = error_categories.transform_values(&:count)

    recent_errors = failed_jobs.order(created_at: :desc)
                              .limit(10)
                              .map do |job|
      {
        job_id: job.id,
        data_source_name: job.data_source.name,
        error_message: job.error_message,
        error_category: job.error_metadata&.dig("error_category"),
        occurred_at: job.completed_at&.iso8601,
        retry_count: job.retry_count || 0
      }
    end

    {
      total_errors: failed_jobs.count,
      error_rate: calculate_error_rate,
      error_categories: error_frequency,
      recent_errors: recent_errors,
      top_error_patterns: analyze_error_patterns(failed_jobs)
    }
  end

  def data_quality_metrics
    # Analyze validation results from recent jobs
    jobs_with_validation = extraction_jobs_in_window
                          .where("processing_summary -> 'validation_summary' IS NOT NULL")

    return {} if jobs_with_validation.empty?

    validation_scores = jobs_with_validation.map do |job|
      job.processing_summary&.dig("validation_summary", "quality_score") || 0
    end.compact

    total_records = jobs_with_validation.sum(:records_processed) || 0
    failed_validations = jobs_with_validation.sum do |job|
      job.processing_summary&.dig("validation_summary", "total_errors") || 0
    end

    {
      data_quality_score: validation_scores.empty? ? 0 : (validation_scores.sum / validation_scores.length).round(3),
      total_records_validated: total_records,
      total_validation_failures: failed_validations,
      validation_success_rate: total_records > 0 ? ((total_records - failed_validations).to_f / total_records * 100).round(2) : 0,
      quality_distribution: calculate_quality_distribution(validation_scores)
    }
  end

  def resource_utilization
    # Monitor system resource usage during processing
    current_memory = get_memory_usage
    current_cpu = get_cpu_usage

    {
      memory_usage: {
        current_mb: current_memory,
        status: memory_status(current_memory)
      },
      cpu_usage: {
        current_percent: current_cpu,
        status: cpu_status(current_cpu)
      },
      active_connections: get_active_connections,
      queue_depth: get_queue_depth
    }
  end

  def circuit_breaker_status
    # Get status of all circuit breakers for this organization
    data_sources = DataSource.where(organization_id: @organization_id)

    breaker_statuses = data_sources.map do |ds|
      breaker_name = "file_processing_#{ds.id}"
      breaker = CircuitBreakerService.for(breaker_name)

      {
        data_source_id: ds.id,
        data_source_name: ds.name,
        circuit_state: breaker.current_state,
        metrics: breaker.metrics
      }
    end

    {
      total_circuit_breakers: breaker_statuses.length,
      open_circuits: breaker_statuses.count { |b| b[:circuit_state] == "open" },
      half_open_circuits: breaker_statuses.count { |b| b[:circuit_state] == "half_open" },
      closed_circuits: breaker_statuses.count { |b| b[:circuit_state] == "closed" },
      circuit_details: breaker_statuses
    }
  end

  def real_time_stats
    {
      current_processing_jobs: ExtractionJob.running.joins(:data_source)
                                            .where(data_sources: { organization_id: @organization_id })
                                            .count,
      records_processed_last_hour: calculate_recent_records_processed(1.hour),
      records_processed_last_24h: calculate_recent_records_processed(24.hours),
      average_queue_wait_time: calculate_average_queue_wait_time,
      system_health_score: calculate_system_health_score
    }
  end

  def queue_metrics
    # Solid Queue metrics
    {
      pending_jobs: SolidQueue::Job.where(queue_name: "extraction").pending.count,
      running_jobs: SolidQueue::Job.where(queue_name: "extraction").running.count,
      failed_jobs: SolidQueue::Job.where(queue_name: "extraction").failed.count,
      average_wait_time: calculate_average_queue_wait_time
    }
  rescue => e
    Rails.logger.warn "Failed to get queue metrics: #{e.message}"
    {}
  end

  # Helper methods

  def extraction_jobs_in_window
    @extraction_jobs ||= ExtractionJob.joins(:data_source)
                                     .where(data_sources: { organization_id: @organization_id })
                                     .where(created_at: @start_time..@end_time)
  end

  def calculate_success_rate(jobs)
    return 0 if jobs.empty?
    (jobs.completed.count.to_f / jobs.count * 100).round(2)
  end

  def calculate_error_rate
    total_jobs = extraction_jobs_in_window.count
    return 0 if total_jobs == 0

    failed_jobs = extraction_jobs_in_window.failed.count
    (failed_jobs.to_f / total_jobs * 100).round(2)
  end

  def calculate_average_processing_time(jobs)
    completed_jobs = jobs.completed.where.not(started_at: nil, completed_at: nil)
    return 0 if completed_jobs.empty?

    total_time = completed_jobs.sum { |job| job.completed_at - job.started_at }
    (total_time / completed_jobs.count).round(2)
  end

  def calculate_median(array)
    return nil if array.empty?

    sorted = array.sort
    length = sorted.length

    if length.odd?
      sorted[length / 2]
    else
      (sorted[length / 2 - 1] + sorted[length / 2]) / 2.0
    end
  end

  def analyze_error_patterns(failed_jobs)
    # Group by error message patterns
    error_patterns = failed_jobs.group_by do |job|
      # Extract key words from error message
      error_msg = job.error_message || ""
      case error_msg
      when /timeout/i then "timeout_errors"
      when /memory/i then "memory_errors"
      when /connection/i then "connection_errors"
      when /validation/i then "validation_errors"
      when /format/i then "format_errors"
      else "other_errors"
      end
    end

    error_patterns.transform_values(&:count)
                  .sort_by { |_, count| -count }
                  .first(5)
                  .to_h
  end

  def calculate_quality_distribution(scores)
    return {} if scores.empty?

    {
      excellent: scores.count { |s| s >= 0.9 },
      good: scores.count { |s| s >= 0.7 && s < 0.9 },
      fair: scores.count { |s| s >= 0.5 && s < 0.7 },
      poor: scores.count { |s| s < 0.5 }
    }
  end

  def get_memory_usage
    # Simple memory usage check
    begin
      if RUBY_PLATFORM.include?("darwin") # macOS
        `ps -o rss= -p #{Process.pid}`.to_i / 1024 # Convert to MB
      else # Linux
        `cat /proc/#{Process.pid}/status | grep VmRSS`.split[1].to_i / 1024
      end
    rescue
      0
    end
  end

  def get_cpu_usage
    # Simplified CPU usage
    begin
      `ps -o %cpu= -p #{Process.pid}`.to_f
    rescue
      0.0
    end
  end

  def memory_status(memory_mb)
    case memory_mb
    when 0..500 then "low"
    when 501..1000 then "normal"
    when 1001..2000 then "high"
    else "critical"
    end
  end

  def cpu_status(cpu_percent)
    case cpu_percent
    when 0..30 then "low"
    when 31..70 then "normal"
    when 71..90 then "high"
    else "critical"
    end
  end

  def get_active_connections
    # ActiveRecord connection pool stats
    ActiveRecord::Base.connection_pool.stat
  rescue
    {}
  end

  def get_queue_depth
    # Current depth of processing queue
    SolidQueue::Job.where(queue_name: "extraction").pending.count
  rescue
    0
  end

  def calculate_recent_records_processed(time_period)
    RawDataRecord.joins(data_source: :organization)
                 .where(organizations: { id: @organization_id })
                 .where("raw_data_records.created_at >= ?", Time.current - time_period)
                 .count
  end

  def calculate_average_queue_wait_time
    # Calculate average time jobs spend waiting in queue
    recent_jobs = extraction_jobs_in_window.where.not(started_at: nil)

    wait_times = recent_jobs.map do |job|
      job.started_at - job.created_at if job.started_at && job.created_at
    end.compact

    return 0 if wait_times.empty?
    (wait_times.sum / wait_times.length).round(2)
  end

  def calculate_system_health_score
    # Overall system health based on multiple factors
    success_rate = calculate_success_rate(extraction_jobs_in_window)
    error_rate = calculate_error_rate

    # Weight factors
    health_score = (success_rate * 0.4) + ((100 - error_rate) * 0.3)

    # Add queue health factor
    queue_depth = get_queue_depth
    queue_health = queue_depth < 10 ? 30 : [ 30 - (queue_depth - 10), 0 ].max
    health_score += queue_health * 0.3

    [ health_score, 100 ].min.round(1)
  end

  # Class methods for logging common events
  class << self
    def log_job_started(organization_id, extraction_job)
      new(organization_id: organization_id).log_processing_event("job_started", {
        job_id: extraction_job.id,
        data_source_id: extraction_job.data_source_id,
        filename: extraction_job.config&.dig("filename")
      })
    end

    def log_job_completed(organization_id, extraction_job, result)
      new(organization_id: organization_id).log_processing_event("job_completed", {
        job_id: extraction_job.id,
        data_source_id: extraction_job.data_source_id,
        records_processed: result[:total_records],
        processing_time: extraction_job.completed_at - extraction_job.started_at,
        success_rate: result.dig(:processing_summary, :success_rate)
      })
    end

    def log_job_failed(organization_id, extraction_job, error)
      new(organization_id: organization_id).log_processing_event("job_failed", {
        job_id: extraction_job.id,
        data_source_id: extraction_job.data_source_id,
        error_class: error.class.name,
        error_message: error.message,
        retry_count: extraction_job.retry_count || 0
      })
    end

    def log_validation_completed(organization_id, data_source_id, validation_result)
      new(organization_id: organization_id).log_processing_event("validation_completed", {
        data_source_id: data_source_id,
        validation_success: validation_result[:success],
        total_errors: validation_result[:total_errors],
        total_records: validation_result[:total_records]
      })
    end
  end
end
