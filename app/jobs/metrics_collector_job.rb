# frozen_string_literal: true

# Background job to collect and report metrics periodically
class MetricsCollectorJob < ApplicationJob
  queue_as :low_priority

  def perform
    # Temporarily disabled due to missing database columns/tables
    # TODO: Re-enable after running solid_queue:install and adding subscription_tier column
    Rails.logger.info "MetricsCollectorJob is temporarily disabled"
    return
    
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
