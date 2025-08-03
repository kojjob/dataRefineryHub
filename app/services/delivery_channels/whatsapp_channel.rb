# frozen_string_literal: true

require 'net/http'
require 'json'

module DeliveryChannels
  # WhatsApp Business API delivery channel
  class WhatsappChannel < BaseChannel
    WHATSAPP_API_URL = 'https://graph.facebook.com/v17.0'
    
    def deliver
      return handle_delivery_error(StandardError.new('Channel not configured')) unless configured?
      return handle_delivery_error(StandardError.new('Invalid delivery parameters')) unless valid_delivery?
      
      begin
        formatted_content = format_content
        response = send_whatsapp_message(formatted_content)
        
        if response[:success]
          log_delivery(
            status: 'delivered',
            metadata: {
              message_id: response[:message_id],
              phone_number: recipient_phone,
              content_length: formatted_content[:text].length
            }
          )
          { success: true, message_id: response[:message_id] }
        else
          handle_delivery_error(StandardError.new(response[:error]))
        end
      rescue => e
        handle_delivery_error(e)
      end
    end
    
    def configured?
      whatsapp_config.present? &&
        whatsapp_config['phone_number_id'].present? &&
        whatsapp_config['access_token'].present?
    end
    
    def format_content
      case report[:format] || 'text'
      when 'pdf'
        format_pdf_content
      when 'image'
        format_image_content
      else
        format_text_content
      end
    end
    
    private
    
    def whatsapp_config
      @whatsapp_config ||= organization.settings['whatsapp'] || {}
    end
    
    def recipient_phone
      user.phone_number || user.mobile_number || options[:phone_number]
    end
    
    def send_whatsapp_message(content)
      uri = URI("#{WHATSAPP_API_URL}/#{whatsapp_config['phone_number_id']}/messages")
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{whatsapp_config['access_token']}"
      request['Content-Type'] = 'application/json'
      
      request.body = {
        messaging_product: 'whatsapp',
        to: normalize_phone_number(recipient_phone),
        type: content[:type],
        **content[:payload]
      }.to_json
      
      response = http.request(request)
      
      if response.code == '200'
        data = JSON.parse(response.body)
        { success: true, message_id: data['messages'].first['id'] }
      else
        { success: false, error: "WhatsApp API error: #{response.code} - #{response.body}" }
      end
    end
    
    def format_text_content
      insights = generate_insights_text
      
      {
        type: 'text',
        payload: {
          text: {
            body: insights
          }
        }
      }
    end
    
    def format_pdf_content
      # First, generate and upload PDF
      pdf_url = generate_and_upload_pdf
      
      {
        type: 'document',
        payload: {
          document: {
            link: pdf_url,
            caption: "#{report[:type].humanize} - #{Date.current}",
            filename: "#{report[:type]}_#{Date.current}.pdf"
          }
        }
      }
    end
    
    def format_image_content
      # Generate chart image
      image_url = generate_chart_image
      
      {
        type: 'image',
        payload: {
          image: {
            link: image_url,
            caption: generate_chart_caption
          }
        }
      }
    end
    
    def generate_insights_text
      data = report[:data]
      
      case report[:type]
      when 'daily_summary'
        generate_daily_summary_text(data)
      when 'sales_report'
        generate_sales_report_text(data)
      when 'inventory_report'
        generate_inventory_report_text(data)
      when 'real_time_alert'
        generate_alert_text(data)
      else
        generate_generic_report_text(data)
      end
    end
    
    def generate_daily_summary_text(data)
      text = "📊 *Daily Business Summary*\n"
      text += "📅 #{Date.current.strftime('%B %d, %Y')}\n\n"
      
      if data[:revenue]
        text += "💰 *Revenue*: #{format_currency(data[:revenue])}\n"
        text += "📈 #{data[:revenue_change]}% vs yesterday\n\n"
      end
      
      if data[:orders]
        text += "🛒 *Orders*: #{data[:orders][:count]}\n"
        text += "💵 *Avg Order*: #{format_currency(data[:orders][:average])}\n\n"
      end
      
      if data[:top_products]
        text += "🏆 *Top Products*:\n"
        data[:top_products].first(3).each_with_index do |product, i|
          text += "#{i + 1}. #{product[:name]} (#{product[:units]} sold)\n"
        end
        text += "\n"
      end
      
      if data[:alerts]
        text += "⚠️ *Alerts*:\n"
        data[:alerts].each do |alert|
          text += "• #{alert[:message]}\n"
        end
      end
      
      text += "\n💬 Reply with:\n"
      text += "• 'DETAILS' for full report\n"
      text += "• 'HELP' for commands"
      
      text
    end
    
    def generate_sales_report_text(data)
      "💼 *Sales Report*\n\n" +
      "📊 Total Sales: #{format_currency(data[:total_sales])}\n" +
      "📈 Growth: #{data[:growth_percentage]}%\n" +
      "🛍️ Transactions: #{data[:transaction_count]}\n" +
      "💳 Avg Transaction: #{format_currency(data[:average_sale])}\n\n" +
      "📱 Reply 'SALES DETAILS' for breakdown"
    end
    
    def generate_inventory_report_text(data)
      text = "📦 *Inventory Alert*\n\n"
      
      if data[:low_stock_items].any?
        text += "🔴 *Low Stock Items*:\n"
        data[:low_stock_items].each do |item|
          text += "• #{item[:name]}: #{item[:quantity]} left\n"
        end
      end
      
      text += "\n💬 Reply 'ORDER' to create purchase order"
      text
    end
    
    def generate_alert_text(data)
      "🚨 *#{data[:alert_type].humanize}*\n\n" +
      "#{data[:message]}\n\n" +
      "Time: #{Time.current.strftime('%I:%M %p')}\n" +
      "Impact: #{data[:impact]}\n\n" +
      "Reply 'ACK' to acknowledge"
    end
    
    def generate_generic_report_text(data)
      text = "📊 *#{report[:type].humanize}*\n\n"
      
      data.each do |key, value|
        next if value.is_a?(Hash) || value.is_a?(Array)
        text += "• #{key.to_s.humanize}: #{format_value(value)}\n"
      end
      
      text
    end
    
    def format_currency(amount)
      "$#{number_with_delimiter(amount.round(2))}"
    end
    
    def format_value(value)
      case value
      when Numeric
        number_with_delimiter(value.round(2))
      when Date, Time
        value.strftime('%B %d, %Y')
      else
        value.to_s
      end
    end
    
    def number_with_delimiter(number)
      number.to_s.gsub(/(\d)(?=(\d\d\d)+(?!\d))/, '\\1,')
    end
    
    def normalize_phone_number(phone)
      # Remove all non-numeric characters
      cleaned = phone.gsub(/\D/, '')
      
      # Add country code if not present (assuming US)
      cleaned = "1#{cleaned}" if cleaned.length == 10
      
      cleaned
    end
    
    def generate_and_upload_pdf
      # This would integrate with PDF generation service
      pdf_service = PdfReportGenerator.new(report: report, organization: organization)
      pdf_path = pdf_service.generate
      
      # Upload to cloud storage and return URL
      CloudStorageService.new.upload(pdf_path, public: true)
    end
    
    def generate_chart_image
      # This would integrate with chart generation service
      ChartGenerator.new(data: report[:data], type: options[:chart_type]).generate_url
    end
    
    def generate_chart_caption
      "#{report[:type].humanize} - #{Date.current.strftime('%B %d, %Y')}"
    end
  end
end