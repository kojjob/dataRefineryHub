# frozen_string_literal: true

module Application
  module Commands
    # Command to update pipeline configuration
    class UpdatePipelineCommand
      include ActiveModel::Model

      attr_accessor :pipeline_id, :user
      attr_accessor :name, :description
      attr_accessor :source_type, :source_configuration
      attr_accessor :destination_type, :destination_configuration
      attr_accessor :transformation_rules_to_add
      attr_accessor :transformation_rules_to_remove
      attr_accessor :schedule_params
      attr_accessor :retry_policy_params

      validates :pipeline_id, presence: true
      validates :user, presence: true

      def execute
        validate!

        ApplicationRecord.transaction do
          # Load the pipeline
          pipeline = repository.find(pipeline_id)
          unless pipeline
            return Failure.new(errors: { base: [ "Pipeline not found" ] })
          end

          # Apply updates

          # Configure source if provided
          if source_type.present? || source_configuration.present?
            pipeline.configure_source(
              source_type: source_type || extract_source_type(pipeline),
              configuration: source_configuration || pipeline.source_configuration,
              configured_by: user
            )
          end

          # Configure destination if provided
          if destination_type.present? || destination_configuration.present?
            pipeline.configure_destination(
              destination_type: destination_type || extract_destination_type(pipeline),
              configuration: destination_configuration || pipeline.destination_configuration,
              configured_by: user
            )
          end

          # Remove transformation rules
          transformation_rules_to_remove&.each do |position|
            pipeline.remove_transformation_rule(position: position, removed_by: user)
          end

          # Add transformation rules
          transformation_rules_to_add&.each do |rule|
            pipeline.add_transformation_rule(rule, added_by: user)
          end

          # Set schedule if provided
          if schedule_params.present?
            if schedule_params == :remove
              pipeline.unschedule_pipeline(unscheduled_by: user)
            else
              pipeline.schedule_pipeline(schedule_params, scheduled_by: user)
            end
          end

          # Set retry policy if provided
          if retry_policy_params.present?
            pipeline.configure_retry_policy(retry_policy_params, configured_by: user)
          end

          # Save via repository
          repository.save(pipeline)

          Success.new(pipeline_id: pipeline.id)
        end
      rescue Domain::Shared::ValueObjects::PipelineStatus::InvalidTransitionError => e
        Failure.new(errors: { status: [ e.message ] })
      rescue ActiveModel::ValidationError => e
        Failure.new(errors: e.model.errors)
      rescue StandardError => e
        Rails.logger.error "Error updating pipeline: #{e.message}"
        Failure.new(errors: { base: [ e.message ] })
      end

      private

      def repository
        @repository ||= Infrastructure::Persistence::Repositories::ActiveRecordPipelineRepository.new
      end

      def extract_source_type(pipeline)
        pipeline.source_configuration&.dig("type")
      end

      def extract_destination_type(pipeline)
        pipeline.destination_configuration&.dig("type")
      end

      # Result objects
      Success = Struct.new(:pipeline_id, keyword_init: true) do
        def success?
          true
        end
      end

      Failure = Struct.new(:errors, keyword_init: true) do
        def success?
          false
        end
      end
    end
  end
end
