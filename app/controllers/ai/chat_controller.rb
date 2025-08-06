# frozen_string_literal: true

module Ai
  class ChatController < ApplicationController
    before_action :authenticate_user!
    before_action :ensure_organization_member

    def create
      @nl_service = NaturalLanguageService.new(
        organization: current_organization,
        user: current_user
      )

      response = @nl_service.process_query(
        params[:query],
        context: build_context
      )

      # Broadcast response for real-time updates
      broadcast_response(response)

      render json: {
        success: true,
        response: response,
        query_id: response[:query_id]
      }
    rescue StandardError => e
      Rails.logger.error "Chat query failed: #{e.message}"
      render json: {
        success: false,
        error: "I couldn't process your request. Please try rephrasing.",
        details: Rails.env.development? ? e.message : nil
      }, status: :unprocessable_entity
    end

    def voice
      @nl_service = NaturalLanguageService.new(
        organization: current_organization,
        user: current_user
      )

      response = @nl_service.process_voice_command(params[:audio_data])

      render json: {
        success: true,
        response: response,
        transcript: response[:transcript]
      }
    rescue StandardError => e
      Rails.logger.error "Voice command failed: #{e.message}"
      render json: {
        success: false,
        error: "I couldn't process your voice command. Please try again."
      }, status: :unprocessable_entity
    end

    def suggestions
      @nl_service = NaturalLanguageService.new(
        organization: current_organization,
        user: current_user
      )

      suggestions = @nl_service.get_suggestions(params[:query])

      render json: {
        success: true,
        suggestions: suggestions
      }
    end

    def history
      @queries = Ai::Query.where(organization: current_organization, user: current_user)
                          .recent
                          .limit(20)
                          .includes(:user)

      render json: {
        success: true,
        queries: @queries.map { |q| serialize_query(q) }
      }
    end

    def feedback
      query = Ai::Query.find(params[:query_id])

      if query.organization == current_organization
        if params[:helpful]
          query.mark_as_helpful
        else
          query.mark_as_not_helpful(params[:reason])
        end

        render json: { success: true, message: "Thank you for your feedback!" }
      else
        render json: { success: false, error: "Query not found" }, status: :not_found
      end
    end

    def execute_action
      action = Ai::AutomatedAction.find(params[:action_id])

      if action.organization == current_organization && can?(:execute, action)
        action.approved_by = current_user
        action.approved!

        # Execute action in background
        Ai::ActionExecutorJob.perform_later(action)

        render json: {
          success: true,
          message: "Action approved and queued for execution.",
          action_id: action.id
        }
      else
        render json: {
          success: false,
          error: "You don't have permission to execute this action."
        }, status: :forbidden
      end
    end

    private

    def build_context
      {
        current_page: params[:current_page],
        dashboard_metrics: params[:dashboard_metrics],
        active_filters: params[:filters],
        user_role: current_user.role_in(current_organization),
        timestamp: Time.current
      }
    end

    def broadcast_response(response)
      ActionCable.server.broadcast(
        "ai_chat_#{current_organization.id}_#{current_user.id}",
        {
          type: "chat_response",
          response: response,
          timestamp: Time.current
        }
      )
    end

    def serialize_query(query)
      {
        id: query.id,
        query: query.query,
        response: query.response,
        intent: query.intent,
        created_at: query.created_at,
        execution_time: query.execution_time,
        has_visualizations: query.has_visualizations?,
        has_actions: query.has_actions?
      }
    end
  end
end
