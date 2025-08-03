class DeliveryPreference < ApplicationRecord
  belongs_to :user
  belongs_to :organization
  
  # Available channels and formats
  CHANNELS = %w[whatsapp email sms pdf slides webhook api].freeze
  FORMATS = %w[text html pdf pptx json csv xlsx].freeze
  
  REPORT_TYPES = %w[
    daily_summary
    weekly_report
    monthly_analysis
    real_time_alert
    custom_report
    kpi_dashboard
    sales_report
    inventory_report
    financial_report
  ].freeze
  
  # Associations
  has_many :delivery_logs, dependent: :destroy
  
  # Validations
  validates :report_type, presence: true, inclusion: { in: REPORT_TYPES }
  validates :channel, presence: true, inclusion: { in: CHANNELS }
  validates :format, presence: true, inclusion: { in: FORMATS }
  validates :user, uniqueness: { scope: [:organization, :report_type, :channel] }
  validate :validate_channel_format_compatibility
  validate :validate_schedule_format
  
  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_channel, ->(channel) { where(channel: channel) }
  scope :by_report_type, ->(type) { where(report_type: type) }
  scope :scheduled, -> { where.not(schedule: [nil, {}]) }
  
  # Callbacks
  before_create :set_defaults
  after_save :update_scheduled_jobs, if: :saved_change_to_schedule?
  
  # Check if preference has a schedule
  def scheduled?
    schedule.present?
  end

  # Check if this preference should run now
  def should_deliver_now?
    return false unless active?
    return true if schedule.blank? # Immediate delivery
    
    # Check cron schedule
    cron_parser.next(Time.current) <= Time.current
  end
  
  # Get next scheduled delivery time
  def next_delivery_time
    return Time.current if schedule.blank?
    cron_parser.next(Time.current)
  end
  
  # Deliver report using this preference
  def deliver_report(report_data)
    channel_service.new(
      organization: organization,
      user: user,
      report: {
        type: report_type,
        data: report_data,
        format: format
      },
      options: delivery_options
    ).deliver
  end
  
  # Get human-readable schedule
  def schedule_description
    return "On-demand" if schedule.blank?
    
    # Handle both hash and string schedule formats
    if schedule.is_a?(String)
      case schedule
      when 'daily' then 'Daily'
      when 'weekly' then 'Weekly'
      when 'monthly' then 'Monthly'
      else schedule.humanize
      end
    else
      case schedule['frequency']
      when 'daily'
        "Daily at #{schedule['time'] || '9:00 AM'}"
      when 'weekly'
        "Weekly on #{schedule['day'] || 'Monday'} at #{schedule['time'] || '9:00 AM'}"
      when 'monthly'
        "Monthly on day #{schedule['day_of_month'] || '1'} at #{schedule['time'] || '9:00 AM'}"
      when 'custom'
        schedule['cron_expression'] || 'Custom schedule'
      else
        'On demand'
      end
    end
  end

  # Get delivery logs for this preference
  def delivery_logs
    DeliveryLog.where(
      user: user,
      organization: organization,
      channel: channel,
      report_type: report_type
    )
  end
  
  private
  
  def set_defaults
    self.active = true if active.nil?
    self.options ||= {}
    self.schedule ||= {}
  end
  
  def validate_channel_format_compatibility
    case channel
    when 'whatsapp'
      errors.add(:format, 'WhatsApp only supports text and pdf formats') unless %w[text pdf].include?(format)
    when 'sms'
      errors.add(:format, 'SMS only supports text format') unless format == 'text'
    when 'slides'
      errors.add(:format, 'Slides channel requires pptx format') unless format == 'pptx'
    when 'pdf'
      errors.add(:format, 'PDF channel requires pdf format') unless format == 'pdf'
    end
  end
  
  def validate_schedule_format
    return if schedule.blank?
    
    required_keys = case schedule['frequency']
    when 'daily' then ['time']
    when 'weekly' then ['day', 'time']
    when 'monthly' then ['day_of_month', 'time']
    when 'custom' then ['cron_expression']
    else []
    end
    
    required_keys.each do |key|
      errors.add(:schedule, "#{key} is required for #{schedule['frequency']} frequency") unless schedule[key].present?
    end
  end
  
  def channel_service
    "DeliveryChannels::#{channel.camelize}Channel".constantize
  end
  
  def delivery_options
    options.merge(
      'format' => format,
      'scheduled' => schedule.present?
    )
  end
  
  def cron_parser
    return @cron_parser if @cron_parser
    
    cron_expression = case schedule['frequency']
    when 'daily'
      "0 #{schedule['hour'] || 9} * * *"
    when 'weekly'
      day_number = Date::DAYNAMES.index(schedule['day'] || 'Monday')
      "0 #{schedule['hour'] || 9} * * #{day_number}"
    when 'monthly'
      "0 #{schedule['hour'] || 9} #{schedule['day_of_month'] || 1} * *"
    when 'custom'
      schedule['cron_expression']
    else
      '0 9 * * *' # Default to daily at 9 AM
    end
    
    @cron_parser = Fugit::Cron.parse(cron_expression)
  end
  
  def update_scheduled_jobs
    # Remove old scheduled job if exists
    if schedule_was.present?
      DeliverySchedulerJob.remove_scheduled_preference(self)
    end
    
    # Add new scheduled job if active and scheduled
    if active? && schedule.present?
      DeliverySchedulerJob.schedule_preference(self)
    end
  end
end
