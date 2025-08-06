# frozen_string_literal: true

module Domain
  module PipelineManagement
    module ValueObjects
      # Represents a retry policy for pipeline execution failures
      class RetryPolicy
        include ActiveModel::Model
        include ActiveModel::Validations

        attr_reader :max_attempts, :backoff_strategy, :backoff_seconds, :max_backoff_seconds

        STRATEGIES = %w[linear exponential constant].freeze
        DEFAULT_MAX_ATTEMPTS = 3
        DEFAULT_STRATEGY = "exponential"
        DEFAULT_BACKOFF_SECONDS = 60
        DEFAULT_MAX_BACKOFF_SECONDS = 3600

        validates :max_attempts, presence: true,
                  numericality: { greater_than: 0, less_than_or_equal_to: 10 }
        validates :backoff_strategy, inclusion: { in: STRATEGIES }
        validates :backoff_seconds, presence: true,
                  numericality: { greater_than: 0 }
        validates :max_backoff_seconds, presence: true,
                  numericality: { greater_than: 0 }

        def initialize(max_attempts: DEFAULT_MAX_ATTEMPTS,
                       backoff_strategy: DEFAULT_STRATEGY,
                       backoff_seconds: DEFAULT_BACKOFF_SECONDS,
                       max_backoff_seconds: DEFAULT_MAX_BACKOFF_SECONDS)
          @max_attempts = max_attempts
          @backoff_strategy = backoff_strategy
          @backoff_seconds = backoff_seconds
          @max_backoff_seconds = max_backoff_seconds

          unless valid?
            raise ActiveModel::ValidationError.new(self)
          end
        end

        def calculate_delay(attempt_number)
          return 0 if attempt_number <= 0

          delay = case backoff_strategy
          when "linear"
                    backoff_seconds * attempt_number
          when "exponential"
                    backoff_seconds * (2**(attempt_number - 1))
          when "constant"
                    backoff_seconds
          end

          [ delay, max_backoff_seconds ].min
        end

        def should_retry?(attempt_number)
          attempt_number < max_attempts
        end

        def to_h
          {
            max_attempts: max_attempts,
            backoff_strategy: backoff_strategy,
            backoff_seconds: backoff_seconds,
            max_backoff_seconds: max_backoff_seconds
          }
        end

        def ==(other)
          return false unless other.is_a?(self.class)

          max_attempts == other.max_attempts &&
            backoff_strategy == other.backoff_strategy &&
            backoff_seconds == other.backoff_seconds &&
            max_backoff_seconds == other.max_backoff_seconds
        end
      end
    end
  end
end
