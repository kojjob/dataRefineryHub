# frozen_string_literal: true

# Job to send rate limit warning notifications
class RateLimitWarningJob < ApplicationJob
  queue_as :notifications

  def perform(organization_id:, window:, current_usage:, limit:)
    organization = Organization.find(organization_id)

    # Calculate usage percentage
    usage_percentage = (current_usage.to_f / limit * 100).round(1)

    # Find organization admins
    admins = organization.users.where(role: [ "owner", "admin" ])

    # Send email notifications
    admins.each do |admin|
      RateLimitMailer.usage_warning(
        user: admin,
        organization: organization,
        window: window,
        current_usage: current_usage,
        limit: limit,
        usage_percentage: usage_percentage
      ).deliver_later
    end

    # Create in-app notification
    Notification.create!(
      organization: organization,
      notification_type: "rate_limit_warning",
      title: "API Rate Limit Warning",
      message: "Your organization has used #{usage_percentage}% of its #{window}ly API rate limit (#{current_usage}/#{limit} requests)",
      metadata: {
        window: window,
        current_usage: current_usage,
        limit: limit,
        usage_percentage: usage_percentage,
        timestamp: Time.current
      }
    )

    # Log for monitoring
    Rails.logger.warn "Rate limit warning sent for organization #{organization.name} (#{organization.id}): #{usage_percentage}% of #{window}ly limit used"

    # Track in analytics
    track_analytics_event(organization, window, usage_percentage)
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Organization not found for rate limit warning: #{organization_id}"
  end

  private

  def track_analytics_event(organization, window, usage_percentage)
    # Track event for analytics/monitoring
    Analytics.track(
      organization_id: organization.id,
      event: "api_rate_limit_warning",
      properties: {
        window: window,
        usage_percentage: usage_percentage,
        tier: organization.subscription_tier,
        timestamp: Time.current
      }
    )
  rescue => e
    Rails.logger.error "Failed to track rate limit analytics: #{e.message}"
  end
end
