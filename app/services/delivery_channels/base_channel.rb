# frozen_string_literal: true

module DeliveryChannels
  # Base class for all delivery channels (WhatsApp, Email, PDF, etc.)
  class BaseChannel
    include ActiveModel::Model
    
    attr_accessor :organization, :user, :report, :options
    
    def initialize(organization:, user:, report:, options: {})
      @organization = organization
      @user = user
      @report = report
      @options = options
    end
    
    # Main delivery method - must be implemented by subclasses
    def deliver
      raise NotImplementedError, "#{self.class.name} must implement #deliver"
    end
    
    # Check if the channel is properly configured
    def configured?
      raise NotImplementedError, "#{self.class.name} must implement #configured?"
    end
    
    # Validate delivery parameters
    def valid_delivery?
      validate_report_data && validate_recipient && validate_channel_config
    end
    
    # Format report data for this channel
    def format_content
      raise NotImplementedError, "#{self.class.name} must implement #format_content"
    end
    
    # Get delivery status
    def delivery_status(delivery_id)
      DeliveryLog.find_by(id: delivery_id)
    end
    
    protected
    
    # Log delivery attempt
    def log_delivery(status:, metadata: {})
      DeliveryLog.create!(
        user: user,
        organization: organization,
        channel: channel_name,
        status: status,
        report_type: report[:type],
        metadata: metadata.merge(
          report_id: report[:id],
          delivery_options: options
        ),
        delivered_at: status == 'delivered' ? Time.current : nil
      )
    end
    
    # Channel identifier
    def channel_name
      self.class.name.demodulize.underscore.gsub('_channel', '')
    end
    
    private
    
    def validate_report_data
      report.present? && report[:data].present?
    end
    
    def validate_recipient
      user.present? && user.active?
    end
    
    def validate_channel_config
      configured?
    end
    
    # Common error handling
    def handle_delivery_error(error)
      Rails.logger.error "#{channel_name.capitalize} delivery failed: #{error.message}"
      log_delivery(
        status: 'failed',
        metadata: {
          error_class: error.class.name,
          error_message: error.message,
          backtrace: error.backtrace&.first(5)
        }
      )
      raise DeliveryError, "Failed to deliver via #{channel_name}: #{error.message}"
    end
  end
  
  # Custom error class for delivery failures
  class DeliveryError < StandardError; end
end