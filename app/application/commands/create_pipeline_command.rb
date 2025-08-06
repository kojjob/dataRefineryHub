# frozen_string_literal: true

module Application
  module Commands
    # Command to create a new pipeline
    class CreatePipelineCommand
      include ActiveModel::Model

      attr_accessor :name, :description, :organization_id, :user
      attr_accessor :source_type, :source_configuration
      attr_accessor :destination_type, :destination_configuration
      attr_accessor :transformation_rules
      attr_accessor :tags

      validates :name, presence: true, length: { maximum: 255 }
      validates :organization_id, presence: true
      validates :user, presence: true

      def execute
        validate!

        ApplicationRecord.transaction do
          # Create the pipeline aggregate
          pipeline = Domain::PipelineManagement::Aggregates::PipelineAggregate.create(
            name: name,
            organization_id: organization_id,
            created_by: user,
            description: description
          )

          # Configure source if provided
          if source_type.present? && source_configuration.present?
            pipeline.configure_source(
              source_type: source_type,
              configuration: source_configuration,
              configured_by: user
            )
          end

          # Configure destination if provided
          if destination_type.present? && destination_configuration.present?
            pipeline.configure_destination(
              destination_type: destination_type,
              configuration: destination_configuration,
              configured_by: user
            )
          end

          # Add transformation rules if provided
          transformation_rules&.each do |rule|
            pipeline.add_transformation_rule(rule, added_by: user)
          end

          # Save via repository
          repository.save(pipeline)

          # Return the pipeline ID
          Success.new(pipeline_id: pipeline.id)
        end
      rescue ActiveRecord::RecordInvalid => e
        Failure.new(errors: e.record.errors)
      rescue StandardError => e
        Rails.logger.error "Error creating pipeline: #{e.message}"
        Failure.new(errors: { base: [ e.message ] })
      end

      private

      def repository
        @repository ||= Infrastructure::Persistence::Repositories::ActiveRecordPipelineRepository.new
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
