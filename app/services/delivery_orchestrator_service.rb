# frozen_string_literal: true

# Orchestrates multi-channel delivery of reports
class DeliveryOrchestratorService
  include ActiveModel::Model
  
  attr_accessor :organization, :report_type, :report_data, :options
  
  def initialize(organization:, report_type:, report_data:, options: {})
    @organization = organization
    @report_type = report_type
    @report_data = report_data
    @options = options
  end
  
  # Deliver report to all configured channels for all users
  def deliver_to_all
    results = {
      total_users: 0,
      successful_deliveries: 0,
      failed_deliveries: 0,
      delivery_logs: []
    }
    
    # Get all active users with delivery preferences
    users_with_preferences.find_each do |user|
      user_results = deliver_to_user(user)
      
      results[:total_users] += 1
      results[:successful_deliveries] += user_results[:successful]
      results[:failed_deliveries] += user_results[:failed]
      results[:delivery_logs].concat(user_results[:logs])
    end
    
    results
  end
  
  # Deliver report to specific user via their preferred channels
  def deliver_to_user(user)
    results = {
      successful: 0,
      failed: 0,
      logs: []
    }
    
    # Get user's delivery preferences for this report type
    preferences = user.delivery_preferences
                      .active
                      .by_report_type(report_type)
    
    # If no preferences, use default channels
    preferences = create_default_preferences(user) if preferences.empty?
    
    # Deliver via each preferred channel
    preferences.each do |preference|
      begin
        log = deliver_via_preference(preference)
        results[:logs] << log
        
        if log.successful?
          results[:successful] += 1
        else
          results[:failed] += 1
        end
      rescue => e
        Rails.logger.error "Delivery failed for user #{user.id}: #{e.message}"
        results[:failed] += 1
      end
    end
    
    results
  end
  
  # Deliver report via specific channel
  def deliver_via_channel(user:, channel:, format: nil)
    report = build_report(format)
    
    channel_service = get_channel_service(channel)
    channel_service.new(
      organization: organization,
      user: user,
      report: report,
      options: options
    ).deliver
  end
  
  # Preview report in specific format
  def preview(format:, channel: nil)
    report = build_report(format)
    
    case format
    when 'pdf'
      PdfReportGenerator.new(
        report: report,
        organization: organization,
        user: User.new(email: 'preview@example.com')
      ).generate_pdf_content
    when 'html'
      render_html_preview(report)
    when 'text'
      render_text_preview(report)
    when 'pptx'
      # Return sample slide data
      {
        slides_count: 5,
        titles: generate_slide_titles(report)
      }
    else
      report
    end
  end
  
  private
  
  def users_with_preferences
    if options[:user_ids].present?
      organization.users.active.where(id: options[:user_ids])
    elsif options[:roles].present?
      organization.users.active.joins(:roles).where(roles: { name: options[:roles] })
    else
      organization.users.active
    end
  end
  
  def deliver_via_preference(preference)
    report = build_report(preference.format)
    
    channel_service = get_channel_service(preference.channel)
    delivery_result = channel_service.new(
      organization: organization,
      user: preference.user,
      report: report,
      options: preference.options.merge(options)
    ).deliver
    
    # Return the delivery log created by the channel
    DeliveryLog.where(
      user: preference.user,
      organization: organization,
      channel: preference.channel
    ).order(created_at: :desc).first
  end
  
  def create_default_preferences(user)
    # Create temporary preferences based on available contact info
    preferences = []
    
    if user.email.present?
      preferences << DeliveryPreference.new(
        user: user,
        organization: organization,
        report_type: report_type,
        channel: 'email',
        format: 'html',
        active: true
      )
    end
    
    if user.phone_number.present? && organization.settings['twilio'].present?
      preferences << DeliveryPreference.new(
        user: user,
        organization: organization,
        report_type: report_type,
        channel: 'sms',
        format: 'text',
        active: true
      )
    end
    
    if user.phone_number.present? && organization.settings['whatsapp'].present?
      preferences << DeliveryPreference.new(
        user: user,
        organization: organization,
        report_type: report_type,
        channel: 'whatsapp',
        format: 'text',
        active: true
      )
    end
    
    # If no contact methods available, default to email
    if preferences.empty?
      preferences << DeliveryPreference.new(
        user: user,
        organization: organization,
        report_type: report_type,
        channel: 'email',
        format: 'html',
        active: true
      )
    end
    
    preferences
  end
  
  def build_report(format)
    {
      id: SecureRandom.uuid,
      type: report_type,
      data: report_data,
      format: format,
      generated_at: Time.current,
      organization_id: organization.id
    }
  end
  
  def get_channel_service(channel)
    case channel
    when 'whatsapp'
      DeliveryChannels::WhatsappChannel
    when 'email'
      DeliveryChannels::EmailChannel
    when 'sms'
      DeliveryChannels::SmsChannel
    when 'pdf'
      DeliveryChannels::PdfChannel
    when 'slides'
      DeliveryChannels::SlidesChannel
    else
      raise ArgumentError, "Unknown delivery channel: #{channel}"
    end
  end
  
  def render_html_preview(report)
    ApplicationController.render(
      template: 'reports/preview',
      layout: false,
      assigns: {
        report: report,
        organization: organization
      }
    )
  end
  
  def render_text_preview(report)
    content = "#{report[:type].humanize} Preview\n"
    content += "="*50 + "\n\n"
    
    report[:data].each do |section, data|
      content += "#{section.to_s.humanize}:\n"
      
      case data
      when Hash
        data.each do |key, value|
          content += "  #{key}: #{value}\n"
        end
      when Array
        data.each_with_index do |item, i|
          content += "  #{i + 1}. #{item}\n"
        end
      else
        content += "  #{data}\n"
      end
      
      content += "\n"
    end
    
    content
  end
  
  def generate_slide_titles(report)
    titles = ["#{report[:type].humanize} Report"]
    
    case report[:type]
    when 'daily_summary'
      titles += [
        'Executive Summary',
        'Top Products',
        'Performance Metrics',
        'Thank You'
      ]
    when 'weekly_report'
      titles += [
        'Week Overview',
        'Daily Performance',
        'Key Insights',
        'Recommendations',
        'Thank You'
      ]
    when 'monthly_analysis'
      titles += [
        'Monthly Executive Summary',
        'Performance Metrics',
        'Trends Analysis',
        'Strategic Recommendations',
        'Thank You'
      ]
    else
      report[:data].keys.each do |section|
        titles << section.to_s.humanize
      end
      titles << 'Thank You'
    end
    
    titles
  end
end