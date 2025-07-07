# frozen_string_literal: true

# Background job to collect and report metrics periodically
class MetricsCollectorJob < ApplicationJob
  queue_as :low_priority

  def perform
    # Record business metrics
    MetricsService.record_business_metrics

    # Schedule next run
    self.class.set(wait: 1.minute).perform_later
  rescue => e
    Rails.logger.error "Failed to collect metrics: #{e.message}"
    # Retry in 5 minutes if failed
    self.class.set(wait: 5.minutes).perform_later
  end
end
