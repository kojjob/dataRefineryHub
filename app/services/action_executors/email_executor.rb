# frozen_string_literal: true

module ActionExecutors
  class EmailExecutor
    attr_reader :action, :organization

    def initialize(action)
      @action = action
      @organization = action.organization
    end

    def execute
      validate_parameters!

      recipients = build_recipient_list
      email_content = prepare_email_content

      # Create email campaign
      campaign = create_email_campaign(recipients, email_content)

      # Queue emails for sending
      queue_emails(campaign, recipients)

      # Return execution result
      {
        success: true,
        campaign_id: campaign.id,
        recipients_count: recipients.count,
        scheduled_at: Time.current,
        estimated_completion: estimate_completion_time(recipients.count),
        preview_url: Rails.application.routes.url_helpers.campaign_url(campaign)
      }
    rescue StandardError => e
      Rails.logger.error "Email execution failed: #{e.message}"
      raise e
    end

    private

    def validate_parameters!
      required = %w[subject content recipient_type]
      missing = required - action.parameters.keys

      raise ArgumentError, "Missing required parameters: #{missing.join(', ')}" if missing.any?
    end

    def build_recipient_list
      case action.parameters["recipient_type"]
      when "all_customers"
        organization.users.active.with_email_consent
      when "segment"
        build_segment_recipients(action.parameters["segment_id"])
      when "custom_list"
        parse_custom_recipients(action.parameters["recipient_emails"])
      when "at_risk_customers"
        organization.users.at_churn_risk
      else
        raise ArgumentError, "Unknown recipient type: #{action.parameters['recipient_type']}"
      end
    end

    def build_segment_recipients(segment_id)
      segment = organization.customer_segments.find(segment_id)
      segment.users.active.with_email_consent
    end

    def parse_custom_recipients(email_list)
      return [] unless email_list.present?

      emails = email_list.is_a?(String) ? email_list.split(",").map(&:strip) : email_list
      organization.users.where(email: emails).with_email_consent
    end

    def prepare_email_content
      template = fetch_or_create_template

      {
        subject: personalize_content(action.parameters["subject"]),
        body_html: render_html_content(template, action.parameters["content"]),
        body_text: render_text_content(action.parameters["content"]),
        from_name: action.parameters["from_name"] || organization.name,
        from_email: action.parameters["from_email"] || organization.default_email,
        reply_to: action.parameters["reply_to"] || organization.support_email
      }
    end

    def fetch_or_create_template
      if action.parameters["template_id"].present?
        organization.email_templates.find(action.parameters["template_id"])
      else
        create_default_template
      end
    end

    def create_default_template
      EmailTemplate.create!(
        organization: organization,
        name: "AI Generated - #{Time.current.strftime('%Y-%m-%d')}",
        category: "ai_generated",
        content: default_template_html
      )
    end

    def create_email_campaign(recipients, content)
      EmailCampaign.create!(
        organization: organization,
        name: action.parameters["campaign_name"] || "AI Campaign - #{action.description}",
        subject: content[:subject],
        from_name: content[:from_name],
        from_email: content[:from_email],
        reply_to: content[:reply_to],
        body_html: content[:body_html],
        body_text: content[:body_text],
        recipient_count: recipients.count,
        status: "queued",
        triggered_by: "ai_agent",
        automated_action_id: action.id,
        scheduled_for: action.parameters["send_at"] || Time.current
      )
    end

    def queue_emails(campaign, recipients)
      # Batch recipients to avoid memory issues
      recipients.find_in_batches(batch_size: 100) do |recipient_batch|
        email_jobs = recipient_batch.map do |recipient|
          {
            campaign_id: campaign.id,
            recipient_id: recipient.id,
            recipient_email: recipient.email,
            personalization_data: build_personalization_data(recipient),
            send_at: calculate_send_time(campaign.scheduled_for)
          }
        end

        # Queue jobs for sending
        EmailSenderJob.perform_bulk(email_jobs)
      end
    end

    def personalize_content(content)
      # Basic personalization - would be expanded with more variables
      content.gsub("{{organization_name}}", organization.name)
             .gsub("{{current_date}}", Date.current.strftime("%B %d, %Y"))
    end

    def render_html_content(template, content)
      # Render content within template
      ApplicationController.render(
        template: "email_templates/ai_generated",
        layout: "email",
        assigns: {
          content: content,
          organization: organization,
          template: template
        }
      )
    end

    def render_text_content(content)
      # Strip HTML and format for plain text
      ActionView::Base.full_sanitizer.sanitize(content)
                      .gsub(/\s+/, " ")
                      .strip
    end

    def build_personalization_data(recipient)
      {
        first_name: recipient.first_name,
        last_name: recipient.last_name,
        email: recipient.email,
        customer_since: recipient.created_at.strftime("%B %Y"),
        last_purchase_date: recipient.last_purchase_at&.strftime("%B %d, %Y"),
        lifetime_value: recipient.lifetime_value,
        preferred_products: recipient.preferred_product_categories
      }
    end

    def calculate_send_time(scheduled_for)
      # Add small random delay to avoid sending all at once
      scheduled_for + rand(0..300).seconds
    end

    def estimate_completion_time(recipient_count)
      # Estimate based on sending rate (e.g., 100 emails per minute)
      minutes = (recipient_count / 100.0).ceil
      Time.current + minutes.minutes
    end

    def default_template_html
      <<~HTML
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <div style="background-color: #f8f9fa; padding: 20px; text-align: center;">
            <h1 style="color: #333; margin: 0;">{{organization_name}}</h1>
          </div>
          <div style="padding: 30px;">
            {{content}}
          </div>
          <div style="background-color: #f8f9fa; padding: 20px; text-align: center; font-size: 12px; color: #666;">
            <p>© {{current_year}} {{organization_name}}. All rights reserved.</p>
            <p>
              <a href="{{unsubscribe_url}}" style="color: #666;">Unsubscribe</a> |
              <a href="{{preferences_url}}" style="color: #666;">Update Preferences</a>
            </p>
          </div>
        </div>
      HTML
    end
  end
end
