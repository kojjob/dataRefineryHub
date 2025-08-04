# frozen_string_literal: true

module Domain
  module PipelineManagement
    module DomainEvents
      # Event raised when a pipeline's status changes
      class PipelineStatusChanged < ::Domain::Shared::DomainEvents::DomainEvent
        attr_reader :pipeline_id, :pipeline_name, :from_status, :to_status, 
                    :changed_by, :reason, :organization_id

        validates :pipeline_id, presence: true
        validates :pipeline_name, presence: true
        validates :from_status, presence: true
        validates :to_status, presence: true
        validates :organization_id, presence: true
        validate :validate_status_transition

        def initialize(attributes = {})
          @pipeline_id = attributes[:pipeline_id]
          @pipeline_name = attributes[:pipeline_name]
          @from_status = attributes[:from_status]
          @to_status = attributes[:to_status]
          @changed_by = attributes[:changed_by]
          @reason = attributes[:reason]
          @organization_id = attributes[:organization_id]
          
          super(attributes.merge(aggregate_id: pipeline_id))
        end

        def significant?
          # Transitions to/from certain states are more significant
          %w[active archived].include?(to_status) || 
          %w[active].include?(from_status)
        end

        def requires_notification?
          # Determine if this change should trigger notifications
          to_status == 'archived' || 
          (from_status == 'active' && to_status == 'paused')
        end

        def to_h
          super.merge(
            pipeline_id: pipeline_id,
            pipeline_name: pipeline_name,
            from_status: from_status,
            to_status: to_status,
            changed_by: changed_by,
            reason: reason,
            organization_id: organization_id
          ).compact
        end

        private

        def validate_status_transition
          valid_statuses = %w[draft active paused archived]
          
          unless valid_statuses.include?(from_status)
            errors.add(:from_status, "is not a valid status")
          end
          
          unless valid_statuses.include?(to_status)
            errors.add(:to_status, "is not a valid status")
          end
          
          if from_status == to_status
            errors.add(:base, "from_status and to_status cannot be the same")
          end
        end
      end
    end
  end
end