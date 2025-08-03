# frozen_string_literal: true

require 'twilio-ruby'

module DeliveryChannels
  # SMS delivery channel using Twilio
  class SmsChannel < BaseChannel
    MAX_SMS_LENGTH = 160
    
    def deliver
      return handle_delivery_error(StandardError.new('Channel not configured')) unless configured?
      return handle_delivery_error(StandardError.new('Invalid delivery parameters')) unless valid_delivery?
      
      begin
        message_content = format_content
        
        # Split long messages if needed
        messages = split_message(message_content)
        message_sids = []
        
        messages.each_with_index do |msg, index|
          response = send_sms(msg, index + 1, messages.length)
          message_sids << response.sid if response
        end
        
        log_delivery(
          status: 'delivered',
          metadata: {
            phone_number: recipient_phone,
            message_count: messages.length,
            message_sids: message_sids,
            total_length: message_content.length
          }
        )
        
        { success: true, message_sids: message_sids }
      rescue Twilio::REST::RestError => e
        handle_delivery_error(StandardError.new("Twilio error: #{e.message}"))
      rescue => e
        handle_delivery_error(e)
      end
    end
    
    def configured?
      twilio_config.present? &&
        twilio_config['account_sid'].present? &&
        twilio_config['auth_token'].present? &&
        twilio_config['phone_number'].present?
    end
    
    def format_content
      data = report[:data]
      
      case report[:type]
      when 'real_time_alert'
        format_alert_sms(data)
      when 'daily_summary'
        format_daily_summary_sms(data)
      when 'inventory_alert'
        format_inventory_alert_sms(data)
      else
        format_generic_sms(data)
      end
    end
    
    private
    
    def twilio_config
      @twilio_config ||= organization.settings['twilio'] || {}
    end
    
    def twilio_client
      @twilio_client ||= Twilio::REST::Client.new(
        twilio_config['account_sid'],
        twilio_config['auth_token']
      )
    end
    
    def recipient_phone
      # Try multiple fields for phone number
      phone = user.phone_number || user.mobile_number || user.phone || options[:phone_number]
      normalize_phone_number(phone)
    end
    
    def send_sms(message, part_number = 1, total_parts = 1)
      message_body = if total_parts > 1
        "(#{part_number}/#{total_parts}) #{message}"
      else
        message
      end
      
      twilio_client.messages.create(
        from: twilio_config['phone_number'],
        to: recipient_phone,
        body: message_body
      )
    end
    
    def split_message(content)
      return [content] if content.length <= MAX_SMS_LENGTH
      
      # Account for part indicators (e.g., "(1/3) ")
      effective_length = MAX_SMS_LENGTH - 7
      
      # Split by sentences first
      sentences = content.split(/(?<=[.!?])\s+/)
      messages = []
      current_message = ""
      
      sentences.each do |sentence|
        if (current_message + sentence).length <= effective_length
          current_message += sentence + " "
        else
          messages << current_message.strip unless current_message.empty?
          current_message = sentence + " "
        end
      end
      
      messages << current_message.strip unless current_message.empty?
      
      # If any message is still too long, split by words
      final_messages = []
      messages.each do |msg|
        if msg.length <= effective_length
          final_messages << msg
        else
          # Split by words
          words = msg.split(' ')
          current = ""
          
          words.each do |word|
            if (current + word).length <= effective_length
              current += word + " "
            else
              final_messages << current.strip
              current = word + " "
            end
          end
          
          final_messages << current.strip unless current.empty?
        end
      end
      
      final_messages
    end
    
    def format_alert_sms(data)
      "🚨 #{data[:alert_type].upcase}: #{data[:message]} " +
      "@ #{Time.current.strftime('%H:%M')}. " +
      "Reply STOP to unsubscribe."
    end
    
    def format_daily_summary_sms(data)
      summary = "📊 Daily Summary:\n"
      summary += "Revenue: #{format_currency_short(data[:revenue][:total])}"
      
      if data[:revenue][:change] > 0
        summary += " ↑#{data[:revenue][:change]}%"
      else
        summary += " ↓#{data[:revenue][:change].abs}%"
      end
      
      summary += "\nOrders: #{data[:orders][:count]}"
      
      if data[:top_product]
        summary += "\nTop: #{data[:top_product][:name]}"
      end
      
      summary += "\nReply FULL for details"
      
      summary
    end
    
    def format_inventory_alert_sms(data)
      alert = "📦 Low Stock Alert:\n"
      
      # List up to 3 items
      data[:low_stock_items].first(3).each do |item|
        alert += "• #{item[:name]}: #{item[:quantity]} left\n"
      end
      
      if data[:low_stock_items].length > 3
        alert += "...and #{data[:low_stock_items].length - 3} more\n"
      end
      
      alert += "Reply ORDER to restock"
      
      alert
    end
    
    def format_generic_sms(data)
      # Build a concise summary
      summary = "#{report[:type].humanize}:\n"
      
      # Add key metrics
      if data[:total]
        summary += "Total: #{format_value_short(data[:total])}\n"
      end
      
      if data[:count]
        summary += "Count: #{data[:count]}\n"
      end
      
      if data[:status]
        summary += "Status: #{data[:status]}\n"
      end
      
      # Add first insight if available
      if data[:insights] && data[:insights].first
        summary += "#{data[:insights].first[0..50]}..."
      end
      
      summary
    end
    
    def format_currency_short(amount)
      return "N/A" if amount.nil?
      
      if amount >= 1_000_000
        "$#{(amount / 1_000_000.0).round(1)}M"
      elsif amount >= 1_000
        "$#{(amount / 1_000.0).round(1)}K"
      else
        "$#{amount.round}"
      end
    end
    
    def format_value_short(value)
      case value
      when Numeric
        if value >= 1_000_000
          "#{(value / 1_000_000.0).round(1)}M"
        elsif value >= 1_000
          "#{(value / 1_000.0).round(1)}K"
        else
          value.round.to_s
        end
      else
        value.to_s[0..20]
      end
    end
    
    def normalize_phone_number(phone)
      return nil if phone.blank?
      
      # Remove all non-numeric characters
      cleaned = phone.gsub(/\D/, '')
      
      # Handle different formats
      if cleaned.length == 10
        # US number without country code
        "+1#{cleaned}"
      elsif cleaned.length == 11 && cleaned.start_with?('1')
        # US number with country code
        "+#{cleaned}"
      elsif cleaned.start_with?('00')
        # International format with 00
        "+#{cleaned[2..]}"
      elsif cleaned.length > 10
        # Assume international, add + if not present
        "+#{cleaned}"
      else
        # Invalid number
        nil
      end
    end
  end
end