# frozen_string_literal: true

# Controller for monitoring and health check endpoints
class MonitoringController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :verify_authenticity_token

  # Health check endpoint
  def health
    health_status = perform_health_checks

    if health_status[:overall_status] == "healthy"
      render json: health_status, status: :ok
    else
      render json: health_status, status: :service_unavailable
    end
  end

  # Metrics endpoint (Prometheus format)
  def metrics
    # Authenticate metrics endpoint
    authenticate_metrics_request!

    metrics_text = generate_prometheus_metrics
    render plain: metrics_text, content_type: "text/plain"
  end

  # Readiness probe for k8s
  def ready
    if application_ready?
      render json: { status: "ready" }, status: :ok
    else
      render json: { status: "not_ready" }, status: :service_unavailable
    end
  end

  # Liveness probe for k8s
  def alive
    render json: { status: "alive", timestamp: Time.current }, status: :ok
  end

  private

  def perform_health_checks
    checks = {
      database: check_database,
      cache: check_cache,
      job_queue: check_job_queue,
      storage: check_storage,
      external_apis: check_external_apis
    }

    overall_status = checks.values.all? { |check| check[:status] == "healthy" } ? "healthy" : "unhealthy"

    {
      status: overall_status,
      timestamp: Time.current,
      version: "1.0.0",
      checks: checks
    }
  end

  def check_database
    start_time = Time.current
    ActiveRecord::Base.connection.execute("SELECT 1")
    response_time = (Time.current - start_time) * 1000

    {
      status: "healthy",
      response_time_ms: response_time.round(2)
    }
  rescue => e
    {
      status: "unhealthy",
      error: e.message
    }
  end

  def check_cache
    start_time = Time.current
    test_key = "health_check_#{SecureRandom.hex(8)}"
    Rails.cache.write(test_key, "test", expires_in: 1.minute)
    value = Rails.cache.read(test_key)
    Rails.cache.delete(test_key)
    response_time = (Time.current - start_time) * 1000

    if value == "test"
      {
        status: "healthy",
        response_time_ms: response_time.round(2)
      }
    else
      {
        status: "unhealthy",
        error: "Cache read/write test failed"
      }
    end
  rescue => e
    {
      status: "unhealthy",
      error: e.message
    }
  end

  def check_job_queue
    pending_jobs = SolidQueue::ReadyExecution.count
    failed_jobs = SolidQueue::FailedExecution.where("created_at > ?", 1.hour.ago).count

    status = if failed_jobs > 100
      "unhealthy"
    elsif pending_jobs > 1000
      "degraded"
    else
      "healthy"
    end

    {
      status: status,
      pending_jobs: pending_jobs,
      recent_failed_jobs: failed_jobs
    }
  rescue => e
    {
      status: "unhealthy",
      error: e.message
    }
  end

  def check_storage
    # Check Active Storage
    if ActiveStorage::Blob.service.respond_to?(:exist?)
      test_key = "health_check_#{SecureRandom.hex(8)}"
      ActiveStorage::Blob.service.upload(test_key, StringIO.new("test"))
      exists = ActiveStorage::Blob.service.exist?(test_key)
      ActiveStorage::Blob.service.delete(test_key) if exists

      {
        status: exists ? "healthy" : "unhealthy"
      }
    else
      {
        status: "healthy",
        note: "Storage service does not support existence check"
      }
    end
  rescue => e
    {
      status: "unhealthy",
      error: e.message
    }
  end

  def check_external_apis
    # Check critical external services
    critical_sources = %w[shopify quickbooks stripe]
    unhealthy_sources = []

    critical_sources.each do |source_type|
      circuit_breaker = CircuitBreakerService.for("extractor_#{source_type}")
      if circuit_breaker.open?
        unhealthy_sources << source_type
      end
    end

    if unhealthy_sources.any?
      {
        status: "degraded",
        unhealthy_sources: unhealthy_sources
      }
    else
      {
        status: "healthy"
      }
    end
  end

  def application_ready?
    # Check if application is ready to serve requests
    ActiveRecord::Base.connection.active? &&
      Rails.application.initialized? &&
      check_job_queue[:status] != "unhealthy"
  rescue
    false
  end

  def authenticate_metrics_request!
    authenticate_or_request_with_http_basic do |username, password|
      username == ENV["METRICS_USERNAME"] && password == ENV["METRICS_PASSWORD"]
    end
  end

  def generate_prometheus_metrics
    # Generate metrics in Prometheus format
    metrics = []

    # Add business metrics
    metrics << "# HELP organizations_total Total number of organizations"
    metrics << "# TYPE organizations_total gauge"
    metrics << "organizations_total #{Organization.count}"

    metrics << "# HELP users_total Total number of users"
    metrics << "# TYPE users_total gauge"
    metrics << "users_total #{User.count}"

    metrics << "# HELP active_users_daily Daily active users"
    metrics << "# TYPE active_users_daily gauge"
    metrics << "active_users_daily #{User.where('last_sign_in_at > ?', 24.hours.ago).count}"

    # Add data source metrics
    DataSource.group(:status).count.each do |status, count|
      metrics << "# HELP data_sources_by_status Data sources by status"
      metrics << "# TYPE data_sources_by_status gauge"
      metrics << "data_sources_by_status{status=\"#{status}\"} #{count}"
    end

    # Add job queue metrics
    metrics << "# HELP job_queue_size Current job queue size"
    metrics << "# TYPE job_queue_size gauge"
    metrics << "job_queue_size #{SolidQueue::ReadyExecution.count}"

    metrics << "# HELP job_queue_failed Failed jobs in last hour"
    metrics << "# TYPE job_queue_failed gauge"
    metrics << "job_queue_failed #{SolidQueue::FailedExecution.where('created_at > ?', 1.hour.ago).count}"

    # Add database metrics
    db_stats = ActiveRecord::Base.connection_pool.stat
    metrics << "# HELP database_connections_active Active database connections"
    metrics << "# TYPE database_connections_active gauge"
    metrics << "database_connections_active #{db_stats[:busy]}"

    metrics << "# HELP database_connections_idle Idle database connections"
    metrics << "# TYPE database_connections_idle gauge"
    metrics << "database_connections_idle #{db_stats[:idle]}"

    metrics.join("\n")
  end
end
