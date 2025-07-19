# frozen_string_literal: true

require 'fugit'

module Domain
  module PipelineManagement
    module ValueObjects
      # Represents a schedule configuration for pipeline execution
      class Schedule
        include ActiveModel::Model
        include ActiveModel::Validations

        attr_reader :type, :expression, :timezone

        TYPES = %w[cron interval daily hourly].freeze
        DEFAULT_TIMEZONE = 'UTC'

        validates :type, inclusion: { in: TYPES }
        validates :expression, presence: true
        validates :timezone, presence: true
        validate :validate_expression_format

        def initialize(type:, expression:, timezone: DEFAULT_TIMEZONE)
          @type = type
          @expression = expression
          @timezone = timezone
          
          unless valid?
            raise ActiveModel::ValidationError.new(self)
          end
        end

        def next_run_time(from: Time.current)
          case type
          when 'cron'
            calculate_cron_next_time(from)
          when 'interval'
            calculate_interval_next_time(from)
          when 'daily'
            calculate_daily_next_time(from)
          when 'hourly'
            from.beginning_of_hour + 1.hour
          end
        end

        def valid_for_scheduling?
          valid?
        end

        def to_h
          {
            type: type,
            expression: expression,
            timezone: timezone
          }
        end

        def ==(other)
          return false unless other.is_a?(self.class)

          type == other.type &&
            expression == other.expression &&
            timezone == other.timezone
        end

        private

        def validate_expression_format
          case type
          when 'cron'
            validate_cron_expression
          when 'interval'
            validate_interval_expression
          when 'daily'
            validate_daily_expression
          end
        end

        def validate_cron_expression
          result = Fugit::Cron.parse(expression)
          if result.nil?
            errors.add(:expression, 'is not a valid cron expression')
          end
        rescue StandardError
          errors.add(:expression, 'is not a valid cron expression')
        end

        def validate_interval_expression
          Integer(expression)
        rescue StandardError
          errors.add(:expression, 'must be a number of minutes')
        end

        def validate_daily_expression
          Time.parse(expression)
        rescue StandardError
          errors.add(:expression, 'must be in HH:MM format')
        end

        def calculate_cron_next_time(from)
          cron = Fugit::Cron.parse(expression)
          cron.next_time(from.in_time_zone(timezone)).in_time_zone('UTC')
        end

        def calculate_interval_next_time(from)
          from + expression.to_i.minutes
        end

        def calculate_daily_next_time(from)
          time_parts = expression.split(':')
          hour = time_parts[0].to_i
          minute = time_parts[1].to_i

          from_in_tz = from.in_time_zone(timezone)
          scheduled_time = from_in_tz.change(hour: hour, min: minute)

          # If the scheduled time has passed today, schedule for tomorrow
          if scheduled_time <= from_in_tz
            scheduled_time += 1.day
          end

          scheduled_time.in_time_zone('UTC')
        end
      end
    end
  end
end
