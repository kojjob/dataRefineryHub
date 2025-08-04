class ApplicationJob < ActiveJob::Base
  include JobLogging

  # Automatically retry jobs that encountered a deadlock
  retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  discard_on ActiveJob::DeserializationError

  # Standard retry configuration for transient failures
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # Track job queue metrics
  before_enqueue do |job|
    # SolidQueue uses different method names
    begin
      queue_size = SolidQueue::ReadyExecution.count
      MetricsService.gauge("jobs.queue.size", queue_size)
    rescue => e
      Rails.logger.error "Failed to track queue metrics: #{e.message}"
    end
  end

  # Track queue latency
  around_perform do |job, block|
    if job.enqueued_at
      latency = Time.current - job.enqueued_at
      MetricsService.histogram("jobs.queue.latency", latency, tags: {
        job_class: job.class.name,
        queue: job.queue_name
      })
    end

    block.call
  end

  private

  def structured_logger
    @structured_logger ||= StructuredLogger.new
  end
end
