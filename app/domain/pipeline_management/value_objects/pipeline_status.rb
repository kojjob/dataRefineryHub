# frozen_string_literal: true

module Domain
  module PipelineManagement
    module ValueObjects
      # Pipeline status value object with state transitions
      class PipelineStatus
        include ActiveModel::Model

        STATUSES = %w[draft active paused failed archived].freeze

        # Define valid state transitions
        TRANSITIONS = {
          "draft" => %w[active archived],
          "active" => %w[paused failed archived],
          "paused" => %w[active archived],
          "failed" => %w[active paused archived],
          "archived" => [] # Terminal state
        }.freeze

        attr_reader :value, :changed_at, :changed_by, :reason

        validates :value, inclusion: { in: STATUSES }

        def initialize(value:, changed_at: Time.current, changed_by: nil, reason: nil)
          @value = value
          @changed_at = changed_at
          @changed_by = changed_by
          @reason = reason
          validate!
        end

        def can_transition_to?(new_status)
          return false if new_status == value

          TRANSITIONS[value].include?(new_status)
        end

        def transition_to(new_status, changed_by: nil, reason: nil)
          unless can_transition_to?(new_status)
            raise InvalidTransitionError,
                  "Cannot transition from #{value} to #{new_status}"
          end

          self.class.new(
            value: new_status,
            changed_at: Time.current,
            changed_by: changed_by,
            reason: reason
          )
        end

        def draft?
          value == "draft"
        end

        def active?
          value == "active"
        end

        def paused?
          value == "paused"
        end

        def failed?
          value == "failed"
        end

        def archived?
          value == "archived"
        end

        def operational?
          active? || paused?
        end

        def terminal?
          archived?
        end

        def to_s
          value
        end

        def to_h
          {
            value: value,
            changed_at: changed_at,
            changed_by: changed_by,
            reason: reason
          }.compact
        end

        def ==(other)
          other.is_a?(self.class) && value == other.value
        end

        class InvalidTransitionError < StandardError; end
      end
    end
  end
end
