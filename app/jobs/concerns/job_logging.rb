# frozen_string_literal: true

# Concern for structured job logging
module JobLogging
  extend ActiveSupport::Concern

  included do
    around_perform :log_job_execution
  end

  private

  def log_job_execution
    job_logger = structured_logger.with_context(
      job_id: job_id,
      job_class: self.class.name,
      queue: queue_name,
      priority: priority
    )

    start_time = Time.current

    # Log job start
    job_logger.log_job_execution(
      self.class.name,
      job_id,
      "started",
      arguments: sanitized_arguments,
      enqueued_at: enqueued_at,
      queue: queue_name
    )

    # Track metrics
    MetricsService.increment("jobs.executed.total", tags: {
      job_class: self.class.name,
      queue: queue_name
    })

    begin
      yield

      # Log successful completion
      duration_seconds = Time.current - start_time
      job_logger.log_job_execution(
        self.class.name,
        job_id,
        "completed",
        duration_seconds: duration_seconds.round(2),
        queue: queue_name
      )

      # Track duration metrics
      MetricsService.histogram("jobs.executed.duration", duration_seconds, tags: {
        job_class: self.class.name,
        queue: queue_name,
        status: "success"
      })

    rescue => e
      # Log failure
      duration_seconds = Time.current - start_time
      job_logger.log_job_execution(
        self.class.name,
        job_id,
        "failed",
        error: e.message,
        error_class: e.class.name,
        duration_seconds: duration_seconds.round(2),
        queue: queue_name
      )

      # Track failure metrics
      MetricsService.increment("jobs.failed.total", tags: {
        job_class: self.class.name,
        queue: queue_name,
        error_class: e.class.name
      })

      # Track duration even for failures
      MetricsService.histogram("jobs.executed.duration", duration_seconds, tags: {
        job_class: self.class.name,
        queue: queue_name,
        status: "failed"
      })

      raise
    end
  end

  def sanitized_arguments
    # Sanitize job arguments to remove sensitive data
    arguments.map do |arg|
      case arg
      when Hash
        arg.except(:password, :token, :api_key, :credentials)
      when ActiveRecord::Base
        { model: arg.class.name, id: arg.id }
      else
        arg
      end
    end
  end
end
