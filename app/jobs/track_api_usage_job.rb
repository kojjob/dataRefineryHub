# TrackApiUsageJob
# Records API usage for rate limiting and analytics
class TrackApiUsageJob < ApplicationJob
  queue_as :low

  def perform(api_key_id:, endpoint:, method:, ip_address:, user_agent:)
    api_key = ApiKey.find_by(id: api_key_id)
    return unless api_key

    # Record the API usage
    api_usage = api_key.api_usages.create!(
      endpoint: endpoint,
      http_method: method,
      ip_address: ip_address,
      user_agent: user_agent,
      requested_at: Time.current
    )

    # Update usage counters
    api_key.increment!(:usage_count)
    api_key.increment!(:monthly_usage_count) if api_key.respond_to?(:monthly_usage_count)

    # Check if approaching rate limit and send notification
    check_rate_limit_warning(api_key)

    # Log usage for analytics
    Rails.logger.info "API Usage: #{api_key.name} - #{method} #{endpoint} from #{ip_address}"
  rescue => e
    Rails.logger.error "Failed to track API usage: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  private

  def check_rate_limit_warning(api_key)
    return unless api_key.organization

    limit = api_key.organization.monthly_api_requests_limit
    usage = api_key.monthly_usage_count || 0

    # Send warning at 80% and 95% usage
    usage_percentage = (usage.to_f / limit * 100).round

    if usage_percentage == 80 || usage_percentage == 95
      ApiUsageNotificationJob.perform_later(
        organization: api_key.organization,
        usage_percentage: usage_percentage
      )
    end
  end
end
