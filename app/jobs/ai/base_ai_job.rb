# frozen_string_literal: true

module Ai
  class BaseAiJob < ApplicationJob
    include ActiveJob::Retry

    # Use high priority queue for AI operations
    queue_as :ai_processing

    # Retry configuration for AI operations
    retry_on StandardError, wait: :exponentially_longer, attempts: 3
    retry_on Net::TimeoutError, wait: 30.seconds, attempts: 5
    retry_on JSON::ParserError, wait: 10.seconds, attempts: 2

    # Discard jobs that consistently fail
    discard_on ActiveRecord::RecordNotFound
    discard_on ArgumentError

    before_perform :setup_ai_context
    after_perform :cleanup_ai_context
    around_perform :track_ai_job_performance

    protected

    def setup_ai_context
      @start_time = Time.current
      @organization = Organization.find(arguments.first[:organization_id]) if arguments.first.is_a?(Hash)
      @cache_service = Ai::CacheService.new(organization: @organization) if @organization

      Rails.logger.info "Starting AI job: #{self.class.name} for organization: #{@organization&.name}"
    end

    def cleanup_ai_context
      duration = Time.current - @start_time
      Rails.logger.info "Completed AI job: #{self.class.name} in #{duration.round(2)}s"

      # Clean up any temporary resources
      cleanup_temporary_resources
    end

    def track_ai_job_performance
      job_start = Time.current

      begin
        yield

        # Track successful job completion
        track_job_metric(:success, Time.current - job_start)

      rescue => error
        # Track job failure
        track_job_metric(:failure, Time.current - job_start)

        # Log detailed error information
        Rails.logger.error "AI Job failed: #{self.class.name}"
        Rails.logger.error "Error: #{error.message}"
        Rails.logger.error "Backtrace: #{error.backtrace.first(10).join('\n')}"

        # Notify monitoring system
        notify_job_failure(error)

        raise error
      end
    end

    def track_job_metric(status, duration)
      return unless @organization

      metric_data = {
        job_class: self.class.name,
        status: status,
        duration: duration,
        organization_id: @organization.id,
        executed_at: Time.current.iso8601
      }

      # Store metrics for monitoring
      Rails.cache.write(
        "ai_job_metrics:#{self.class.name}:#{job_id}",
        metric_data,
        expires_in: 7.days
      )
    end

    def notify_job_failure(error)
      # Integration point for monitoring services (Sentry, Honeybadger, etc.)
      if defined?(Sentry)
        Sentry.capture_exception(error, extra: {
          job_class: self.class.name,
          job_id: job_id,
          organization_id: @organization&.id,
          arguments: arguments
        })
      end

      # Send notification to team if critical
      if critical_job?
        send_failure_notification(error)
      end
    end

    def critical_job?
      # Override in subclasses to mark critical jobs
      false
    end

    def send_failure_notification(error)
      # Implement notification logic (Slack, email, etc.)
      Rails.logger.error "CRITICAL AI JOB FAILURE: #{self.class.name} - #{error.message}"
    end

    def cleanup_temporary_resources
      # Override in subclasses to clean up specific resources
    end

    # Helper methods for AI jobs
    def with_ai_cache(cache_key, ttl: 1.hour)
      return yield unless @cache_service

      cached_result = @cache_service.instance_variable_get(:@cache_store).read(cache_key)

      if cached_result
        Rails.logger.info "Using cached result for: #{cache_key}"
        return cached_result
      end

      result = yield

      @cache_service.instance_variable_get(:@cache_store).write(cache_key, result, expires_in: ttl)
      Rails.logger.info "Cached result for: #{cache_key}"

      result
    end

    def with_rate_limiting(operation_type, &block)
      rate_limiter = Ai::RateLimitService.new(
        organization: @organization,
        operation_type: operation_type
      )

      if rate_limiter.rate_limited?
        Rails.logger.warn "Rate limited for #{operation_type}, delaying job"
        retry_job(wait: rate_limiter.retry_after)
        return
      end

      rate_limiter.record_request
      yield
    end

    def update_job_progress(stage, percentage = nil, details = nil)
      progress_data = {
        stage: stage,
        percentage: percentage,
        details: details,
        updated_at: Time.current.iso8601
      }

      Rails.cache.write(
        "ai_job_progress:#{job_id}",
        progress_data,
        expires_in: 1.hour
      )

      # Broadcast progress update via ActionCable if needed
      broadcast_progress_update(progress_data)
    end

    def broadcast_progress_update(progress_data)
      return unless @organization

      ActionCable.server.broadcast(
        "ai_jobs_#{@organization.id}",
        {
          type: "job_progress",
          job_id: job_id,
          job_class: self.class.name,
          progress: progress_data
        }
      )
    end

    def ensure_organization_limits
      return unless @organization

      # Check if organization has reached AI usage limits
      usage_tracker = Ai::UsageTracker.new(organization: @organization)

      if usage_tracker.exceeded_monthly_limit?
        raise StandardError, "Organization has exceeded monthly AI usage limit"
      end

      if usage_tracker.exceeded_concurrent_limit?
        Rails.logger.warn "Organization approaching concurrent job limit, delaying"
        retry_job(wait: 30.seconds)
      end
    end

    def validate_job_arguments(required_keys)
      args = arguments.first

      unless args.is_a?(Hash)
        raise ArgumentError, "First argument must be a hash"
      end

      missing_keys = required_keys - args.keys.map(&:to_sym)

      if missing_keys.any?
        raise ArgumentError, "Missing required arguments: #{missing_keys.join(', ')}"
      end
    end
  end
end
