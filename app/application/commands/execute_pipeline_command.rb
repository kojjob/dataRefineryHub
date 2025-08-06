# frozen_string_literal: true

module Application
  module Commands
    # Command to execute a pipeline
    class ExecutePipelineCommand
      include ActiveModel::Model

      attr_accessor :pipeline_id, :user
      attr_accessor :triggered_by # 'manual', 'scheduled', 'webhook', 'api'
      attr_accessor :parameters
      attr_accessor :async

      validates :pipeline_id, presence: true
      validates :user, presence: true
      validates :triggered_by, inclusion: { in: %w[manual scheduled webhook api] }

      def initialize(attributes = {})
        super
        @triggered_by ||= "manual"
        @parameters ||= {}
        @async = true if @async.nil?
      end

      def execute
        validate!

        ApplicationRecord.transaction do
          # Load the pipeline
          pipeline = repository.find(pipeline_id)
          unless pipeline
            return Failure.new(errors: { base: [ "Pipeline not found" ] })
          end

          # Check if pipeline can be executed
          unless pipeline.can_execute?
            return Failure.new(
              errors: { base: [ "Pipeline cannot be executed in current state" ] }
            )
          end

          # Start execution in the aggregate
          execution_id = pipeline.start_execution(
            triggered_by: triggered_by,
            executor: user,
            parameters: parameters
          )

          # Save the aggregate with the new event
          repository.save(pipeline)

          # Queue the actual execution job if async
          if async
            PipelineExecutionJob.perform_later(
              pipeline_id: pipeline_id,
              execution_id: execution_id,
              user_id: user.id,
              parameters: parameters
            )
          else
            # Execute synchronously (for testing or small pipelines)
            execute_pipeline_sync(pipeline, execution_id)
          end

          Success.new(
            pipeline_id: pipeline.id,
            execution_id: execution_id,
            async: async
          )
        end
      rescue StandardError => e
        Rails.logger.error "Error executing pipeline: #{e.message}"
        Failure.new(errors: { base: [ e.message ] })
      end

      private

      def repository
        @repository ||= Infrastructure::Persistence::Repositories::ActiveRecordPipelineRepository.new
      end

      def execute_pipeline_sync(pipeline, execution_id)
        # This would be implemented by the execution engine
        # For now, just mark as completed after a mock execution
        start_time = Time.current

        begin
          # Mock execution logic
          rows_processed = rand(100..10000)

          duration = Time.current - start_time

          pipeline.complete_execution(
            execution_id: execution_id,
            status: "success",
            duration_seconds: duration.to_i,
            rows_processed: rows_processed
          )

          repository.save(pipeline)
        rescue StandardError => e
          pipeline.complete_execution(
            execution_id: execution_id,
            status: "failed",
            duration_seconds: (Time.current - start_time).to_i,
            error_message: e.message
          )

          repository.save(pipeline)
          raise
        end
      end

      # Result objects
      Success = Struct.new(:pipeline_id, :execution_id, :async, keyword_init: true) do
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
