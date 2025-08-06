# frozen_string_literal: true

module Domain
  module PipelineManagement
    module Entities
      # Pipeline entity - core domain model
      class Pipeline < ::Domain::Shared::Entity
        attr_accessor :name, :description, :organization_id
        attr_accessor :source_configuration, :destination_configuration
        attr_accessor :transformation_rules, :schedule, :retry_policy
        attr_accessor :status, :created_by_id, :tags

        validates :name, presence: true, length: { maximum: 255 }
        validates :organization_id, presence: true
        validates :created_by_id, presence: true
        validate :validate_configurations

        def initialize(attributes = {})
          super
          @transformation_rules ||= []
          @tags ||= []
          @status ||= ValueObjects::PipelineStatus.new(value: "draft")
        end

        def add_transformation_rule(rule)
          unless rule.is_a?(ValueObjects::TransformationRule)
            rule = ValueObjects::TransformationRule.new(**rule)
          end

          # Ensure unique positions
          rule = ValueObjects::TransformationRule.new(
            **rule.to_h.merge(position: transformation_rules.size + 1)
          )

          @transformation_rules << rule
          touch
        end

        def remove_transformation_rule(position)
          @transformation_rules.delete_at(position - 1)
          reorder_transformation_rules
          touch
        end

        def reorder_transformation_rules
          @transformation_rules.each_with_index do |rule, index|
            @transformation_rules[index] = ValueObjects::TransformationRule.new(
              **rule.to_h.merge(position: index + 1)
            )
          end
        end

        def schedule_pipeline(schedule_params)
          @schedule = if schedule_params.is_a?(ValueObjects::Schedule)
                       schedule_params
          else
                       ValueObjects::Schedule.new(**schedule_params)
          end
          touch
        end

        def set_retry_policy(policy_params)
          @retry_policy = if policy_params.is_a?(ValueObjects::RetryPolicy)
                           policy_params
          else
                           ValueObjects::RetryPolicy.new(**policy_params)
          end
          touch
        end

        def update_status(new_status, changed_by: nil, reason: nil)
          @status = status.transition_to(new_status, changed_by: changed_by, reason: reason)
          touch
        end

        def scheduled?
          schedule.present?
        end

        def operational?
          status.operational?
        end

        def can_execute?
          status.active? && source_configuration.present? && destination_configuration.present?
        end

        def next_scheduled_run
          return nil unless scheduled? && operational?

          schedule.next_run_time
        end

        def configuration_complete?
          source_configuration.present? &&
            destination_configuration.present? &&
            valid?
        end

        def add_tag(tag)
          @tags << tag unless @tags.include?(tag)
          @tags = @tags.uniq
          touch
        end

        def remove_tag(tag)
          @tags.delete(tag)
          touch
        end

        def to_h
          {
            id: id,
            name: name,
            description: description,
            organization_id: organization_id,
            source_configuration: source_configuration,
            destination_configuration: destination_configuration,
            transformation_rules: transformation_rules.map(&:to_h),
            schedule: schedule&.to_h,
            retry_policy: retry_policy&.to_h,
            status: status.to_h,
            created_by_id: created_by_id,
            tags: tags,
            created_at: created_at,
            updated_at: updated_at
          }
        end

        private

        def validate_configurations
          validate_source_configuration if source_configuration.present?
          validate_destination_configuration if destination_configuration.present?
        end

        def validate_source_configuration
          required_keys = case source_configuration["type"]
          when "database"
                           %w[host port database username]
          when "api"
                           %w[base_url auth_type]
          when "file"
                           %w[path format]
          when "cloud_storage"
                           %w[provider bucket]
          else
                           []
          end

          missing_keys = required_keys - source_configuration.keys
          if missing_keys.any?
            errors.add(:source_configuration, "missing required fields: #{missing_keys.join(', ')}")
          end
        end

        def validate_destination_configuration
          required_keys = case destination_configuration["type"]
          when "database"
                           %w[host port database username]
          when "warehouse"
                           %w[type connection_string]
          when "api"
                           %w[endpoint method]
          when "cloud_storage"
                           %w[provider bucket path]
          else
                           []
          end

          missing_keys = required_keys - destination_configuration.keys
          if missing_keys.any?
            errors.add(:destination_configuration, "missing required fields: #{missing_keys.join(', ')}")
          end
        end
      end
    end
  end
end
