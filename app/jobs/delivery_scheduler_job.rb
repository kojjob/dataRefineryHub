# frozen_string_literal: true

class DeliverySchedulerJob < ApplicationJob
  queue_as :scheduled_deliveries

  # Run scheduled deliveries for all organizations
  def perform
    DeliveryPreference.active
                      .scheduled
                      .includes(:user, :organization)
                      .find_each do |preference|
      next unless preference.should_deliver_now?

      # Queue individual delivery job
      ScheduledDeliveryJob.perform_later(preference)
    end
  end

  # Schedule a specific preference
  def self.schedule_preference(preference)
    return unless preference.active? && preference.schedule.present?

    # Calculate next run time
    next_run = preference.next_delivery_time

    # Schedule job using Sidekiq-cron or whenever gem
    # For now, we'll use a simple delayed job
    ScheduledDeliveryJob.set(wait_until: next_run).perform_later(preference)
  end

  # Remove scheduled job for a preference
  def self.remove_scheduled_preference(preference)
    # This would integrate with your job scheduling system
    # to remove any scheduled jobs for this preference
    Rails.logger.info "Removing scheduled jobs for preference #{preference.id}"
  end
end
