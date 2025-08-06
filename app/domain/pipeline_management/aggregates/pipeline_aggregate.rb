# frozen_string_literal: true

module Domain
  module PipelineManagement
    module Aggregates
      # Pipeline Aggregate Root - manages pipeline lifecycle and ensures consistency
      class PipelineAggregate < ::Domain::Shared::AggregateRoot
        include Events

        attr_reader :name, :description, :organization_id, :created_by_id
        attr_reader :source_configuration, :destination_configuration
        attr_reader :transformation_rules, :schedule, :retry_policy
        attr_reader :status, :tags

        # Factory method to create a new pipeline
        def self.create(name:, organization_id:, created_by:, description: nil)
          new.tap do |pipeline|
            pipeline.create_pipeline(
              name: name,
              organization_id: organization_id,
              created_by: created_by,
              description: description
            )
          end
        end

        # Rebuild aggregate from events (Event Sourcing)
        def self.build_from_events(events)
          new.tap { |pipeline| pipeline.replay_events(events) }
        end

        def initialize
          super
          @transformation_rules = []
          @tags = []
        end

        # Commands - These methods modify state and emit events

        def create_pipeline(name:, organization_id:, created_by:, description: nil)
          apply_event(
            PipelineCreated.new(
              aggregate_id: id,
              name: name,
              description: description,
              organization_id: organization_id,
              created_by_id: created_by.id,
              user_id: created_by.id
            )
          )
        end

        def configure_source(source_type:, configuration:, configured_by:)
          raise_if_archived!

          apply_event(
            SourceConfigured.new(
              aggregate_id: id,
              source_type: source_type,
              configuration: configuration,
              configured_by_id: configured_by.id,
              user_id: configured_by.id
            )
          )
        end

        def configure_destination(destination_type:, configuration:, configured_by:)
          raise_if_archived!

          apply_event(
            DestinationConfigured.new(
              aggregate_id: id,
              destination_type: destination_type,
              configuration: configuration,
              configured_by_id: configured_by.id,
              user_id: configured_by.id
            )
          )
        end

        def add_transformation_rule(rule_params, added_by:)
          raise_if_archived!

          rule = ValueObjects::TransformationRule.new(
            **rule_params.merge(position: transformation_rules.size + 1)
          )

          apply_event(
            TransformationRuleAdded.new(
              aggregate_id: id,
              rule: rule.to_h,
              position: rule.position,
              added_by_id: added_by.id,
              user_id: added_by.id
            )
          )
        end

        def remove_transformation_rule(position:, removed_by:)
          raise_if_archived!

          unless transformation_rules[position - 1]
            raise ArgumentError, "No transformation rule at position #{position}"
          end

          apply_event(
            TransformationRuleRemoved.new(
              aggregate_id: id,
              position: position,
              removed_by_id: removed_by.id,
              user_id: removed_by.id
            )
          )
        end

        def schedule_pipeline(schedule_params, scheduled_by:)
          raise_if_not_active!

          schedule = ValueObjects::Schedule.new(**schedule_params)

          apply_event(
            PipelineScheduled.new(
              aggregate_id: id,
              schedule: schedule.to_h,
              next_run_at: schedule.next_run_time,
              scheduled_by_id: scheduled_by.id,
              user_id: scheduled_by.id
            )
          )
        end

        def unschedule_pipeline(unscheduled_by:)
          raise_if_archived!

          unless scheduled?
            raise InvalidStateError, "Pipeline is not scheduled"
          end

          apply_event(
            PipelineUnscheduled.new(
              aggregate_id: id,
              unscheduled_by_id: unscheduled_by.id,
              user_id: unscheduled_by.id
            )
          )
        end

        def configure_retry_policy(policy_params, configured_by:)
          raise_if_archived!

          retry_policy = ValueObjects::RetryPolicy.new(**policy_params)

          apply_event(
            RetryPolicyConfigured.new(
              aggregate_id: id,
              retry_policy: retry_policy.to_h,
              configured_by_id: configured_by.id,
              user_id: configured_by.id
            )
          )
        end

        def activate(activated_by:)
          unless can_activate?
            raise InvalidStateError, "Pipeline cannot be activated: missing required configuration"
          end

          unless status.can_transition_to?("active")
            raise InvalidStateError, "Cannot activate pipeline in #{status.value} status"
          end

          apply_event(
            PipelineActivated.new(
              aggregate_id: id,
              activated_by_id: activated_by.id,
              user_id: activated_by.id
            )
          )
        end

        def pause(reason: nil, paused_by:)
          unless status.can_transition_to?("paused")
            raise InvalidStateError, "Cannot pause pipeline in #{status.value} status"
          end

          apply_event(
            PipelinePaused.new(
              aggregate_id: id,
              reason: reason,
              paused_by_id: paused_by.id,
              user_id: paused_by.id
            )
          )
        end

        def archive(reason: nil, archived_by:)
          if status.archived?
            raise InvalidStateError, "Pipeline is already archived"
          end

          apply_event(
            PipelineArchived.new(
              aggregate_id: id,
              reason: reason,
              archived_by_id: archived_by.id,
              user_id: archived_by.id
            )
          )
        end

        def start_execution(triggered_by: "manual", executor:, parameters: {})
          raise_if_not_active!

          execution_id = SecureRandom.uuid

          apply_event(
            PipelineExecutionStarted.new(
              aggregate_id: id,
              execution_id: execution_id,
              triggered_by: triggered_by,
              executor_id: executor.id,
              parameters: parameters,
              user_id: executor.id
            )
          )

          execution_id
        end

        def complete_execution(execution_id:, status:, duration_seconds:, rows_processed: 0, error_message: nil)
          apply_event(
            PipelineExecutionCompleted.new(
              aggregate_id: id,
              execution_id: execution_id,
              status: status,
              duration_seconds: duration_seconds,
              rows_processed: rows_processed,
              error_message: error_message
            )
          )
        end

        # Queries

        def can_execute?
          status.active? && configuration_complete?
        end

        def can_activate?
          status.draft? && configuration_complete?
        end

        def configuration_complete?
          source_configuration.present? && destination_configuration.present?
        end

        def scheduled?
          schedule.present?
        end

        def operational?
          status.operational?
        end

        def next_scheduled_run
          return nil unless scheduled? && operational?

          schedule.next_run_time
        end

        # Event handlers - These update internal state based on events

        private

        def on_pipeline_created(event)
          @name = event.name
          @description = event.description
          @organization_id = event.organization_id
          @created_by_id = event.created_by_id
          @status = ValueObjects::PipelineStatus.new(value: "draft")
        end

        def on_source_configured(event)
          @source_configuration = event.configuration
          touch
        end

        def on_destination_configured(event)
          @destination_configuration = event.configuration
          touch
        end

        def on_transformation_rule_added(event)
          rule = ValueObjects::TransformationRule.new(**event.rule.symbolize_keys)
          @transformation_rules << rule
          touch
        end

        def on_transformation_rule_removed(event)
          @transformation_rules.delete_at(event.position - 1)
          reorder_transformation_rules
          touch
        end

        def on_pipeline_scheduled(event)
          @schedule = ValueObjects::Schedule.new(**event.schedule.symbolize_keys)
          touch
        end

        def on_pipeline_unscheduled(_event)
          @schedule = nil
          touch
        end

        def on_retry_policy_configured(event)
          @retry_policy = ValueObjects::RetryPolicy.new(**event.retry_policy.symbolize_keys)
          touch
        end

        def on_pipeline_activated(event)
          @status = @status.transition_to("active", changed_by: event.activated_by_id)
          touch
        end

        def on_pipeline_paused(event)
          @status = @status.transition_to("paused",
                                         changed_by: event.paused_by_id,
                                         reason: event.reason)
          touch
        end

        def on_pipeline_archived(event)
          @status = @status.transition_to("archived",
                                         changed_by: event.archived_by_id,
                                         reason: event.reason)
          @schedule = nil # Remove schedule when archived
          touch
        end

        def on_pipeline_execution_started(_event)
          # Could track last execution time, etc.
          touch
        end

        def on_pipeline_execution_completed(_event)
          # Could update statistics, etc.
          touch
        end

        # Helper methods

        def reorder_transformation_rules
          @transformation_rules.each_with_index do |rule, index|
            @transformation_rules[index] = ValueObjects::TransformationRule.new(
              **rule.to_h.merge(position: index + 1)
            )
          end
        end

        def raise_if_archived!
          if status.archived?
            raise InvalidStateError, "Cannot modify archived pipeline"
          end
        end

        def raise_if_not_active!
          unless status.active?
            raise InvalidStateError, "Pipeline must be active to perform this operation"
          end
        end

        class InvalidStateError < StandardError; end
      end
    end
  end
end
