# frozen_string_literal: true

module Api
  module V1
    # Updated Pipelines controller using DDD approach
    class PipelinesController < ApplicationController
      before_action :authenticate_user!
      before_action :load_pipeline, only: [ :show, :update, :destroy, :execute, :activate, :pause, :archive ]

      # GET /api/v1/pipelines
      def index
        pipelines = repository.find_by_organization(current_organization.id)

        render json: {
          pipelines: pipelines.map { |p| serialize_pipeline(p) },
          total: pipelines.count
        }
      end

      # GET /api/v1/pipelines/:id
      def show
        render json: { pipeline: serialize_pipeline(@pipeline) }
      end

      # POST /api/v1/pipelines
      def create
        command = Application::Commands::CreatePipelineCommand.new(
          pipeline_params.merge(
            organization_id: current_organization.id,
            user: current_user
          )
        )

        result = command.execute

        if result.success?
          pipeline = repository.find(result.pipeline_id)
          render json: {
            pipeline: serialize_pipeline(pipeline),
            message: "Pipeline created successfully"
          }, status: :created
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/pipelines/:id
      def update
        command = Application::Commands::UpdatePipelineCommand.new(
          update_pipeline_params.merge(
            pipeline_id: params[:id],
            user: current_user
          )
        )

        result = command.execute

        if result.success?
          pipeline = repository.find(result.pipeline_id)
          render json: {
            pipeline: serialize_pipeline(pipeline),
            message: "Pipeline updated successfully"
          }
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/pipelines/:id/execute
      def execute
        command = Application::Commands::ExecutePipelineCommand.new(
          pipeline_id: params[:id],
          user: current_user,
          triggered_by: "api",
          parameters: execution_params,
          async: params[:async] != "false"
        )

        result = command.execute

        if result.success?
          render json: {
            execution_id: result.execution_id,
            pipeline_id: result.pipeline_id,
            async: result.async,
            message: result.async ? "Pipeline execution queued" : "Pipeline executed successfully"
          }
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/pipelines/:id/activate
      def activate
        begin
          @pipeline.activate(activated_by: current_user)
          repository.save(@pipeline)

          render json: {
            pipeline: serialize_pipeline(@pipeline),
            message: "Pipeline activated successfully"
          }
        rescue Domain::PipelineManagement::Aggregates::PipelineAggregate::InvalidStateError => e
          render json: { error: e.message }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/pipelines/:id/pause
      def pause
        begin
          @pipeline.pause(
            reason: params[:reason],
            paused_by: current_user
          )
          repository.save(@pipeline)

          render json: {
            pipeline: serialize_pipeline(@pipeline),
            message: "Pipeline paused successfully"
          }
        rescue Domain::PipelineManagement::Aggregates::PipelineAggregate::InvalidStateError => e
          render json: { error: e.message }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/pipelines/:id/archive
      def archive
        begin
          @pipeline.archive(
            reason: params[:reason],
            archived_by: current_user
          )
          repository.save(@pipeline)

          render json: {
            pipeline: serialize_pipeline(@pipeline),
            message: "Pipeline archived successfully"
          }
        rescue Domain::PipelineManagement::Aggregates::PipelineAggregate::InvalidStateError => e
          render json: { error: e.message }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/pipelines/:id
      def destroy
        # Only allow deletion of draft pipelines
        unless @pipeline.status.draft?
          render json: {
            error: "Only draft pipelines can be deleted. Archive the pipeline instead."
          }, status: :unprocessable_entity
          return
        end

        if repository.delete(@pipeline.id)
          head :no_content
        else
          render json: { error: "Failed to delete pipeline" }, status: :unprocessable_entity
        end
      end

      private

      def repository
        @repository ||= Infrastructure::Persistence::Repositories::ActiveRecordPipelineRepository.new
      end

      def load_pipeline
        @pipeline = repository.find(params[:id])

        unless @pipeline
          render json: { error: "Pipeline not found" }, status: :not_found
        end

        # Ensure pipeline belongs to current organization
        if @pipeline && @pipeline.organization_id != current_organization.id
          render json: { error: "Unauthorized" }, status: :forbidden
        end
      end

      def pipeline_params
        params.require(:pipeline).permit(
          :name,
          :description,
          :source_type,
          source_configuration: {},
          destination_type: {},
          destination_configuration: {},
          transformation_rules: [ :type, :name, configuration: {} ],
          tags: []
        )
      end

      def update_pipeline_params
        params.require(:pipeline).permit(
          :name,
          :description,
          :source_type,
          source_configuration: {},
          destination_type: {},
          destination_configuration: {},
          transformation_rules_to_add: [ :type, :name, configuration: {} ],
          transformation_rules_to_remove: [],
          schedule_params: [ :type, :expression, :timezone ],
          retry_policy_params: [ :strategy, :max_attempts, :initial_delay, :max_delay, :multiplier ]
        )
      end

      def execution_params
        params.permit(:test_mode, :sample_size, parameters: {}).to_h
      end

      def serialize_pipeline(pipeline)
        {
          id: pipeline.id,
          name: pipeline.name,
          description: pipeline.description,
          status: pipeline.status.value,
          source_configuration: pipeline.source_configuration,
          destination_configuration: pipeline.destination_configuration,
          transformation_rules: pipeline.transformation_rules.map(&:to_h),
          schedule: pipeline.schedule&.to_h,
          retry_policy: pipeline.retry_policy&.to_h,
          tags: pipeline.tags,
          can_execute: pipeline.can_execute?,
          can_activate: pipeline.can_activate?,
          scheduled: pipeline.scheduled?,
          next_scheduled_run: pipeline.next_scheduled_run,
          created_at: pipeline.created_at,
          updated_at: pipeline.updated_at
        }
      end
    end
  end
end
