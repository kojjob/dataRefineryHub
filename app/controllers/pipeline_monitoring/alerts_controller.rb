# frozen_string_literal: true

module PipelineMonitoring
  class AlertsController < ApplicationController
    before_action :authenticate_user!
    before_action :find_alert, only: [:acknowledge, :resolve, :dismiss]

    # PATCH /pipeline_monitoring/alerts/:id/acknowledge
    def acknowledge
      if @alert.acknowledge!(current_user.full_name)
        render json: { 
          success: true, 
          message: "Alert acknowledged successfully",
          alert: alert_json(@alert)
        }
      else
        render json: { 
          success: false, 
          error: "Failed to acknowledge alert",
          errors: @alert.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "Error acknowledging alert #{params[:id]}: #{e.message}"
      render json: { 
        success: false, 
        error: "An unexpected error occurred while acknowledging the alert" 
      }, status: :internal_server_error
    end

    # PATCH /pipeline_monitoring/alerts/:id/resolve
    def resolve
      if @alert.resolve!(current_user.full_name)
        render json: { 
          success: true, 
          message: "Alert resolved successfully",
          alert: alert_json(@alert)
        }
      else
        render json: { 
          success: false, 
          error: "Failed to resolve alert",
          errors: @alert.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "Error resolving alert #{params[:id]}: #{e.message}"
      render json: { 
        success: false, 
        error: "An unexpected error occurred while resolving the alert" 
      }, status: :internal_server_error
    end

    # PATCH /pipeline_monitoring/alerts/:id/dismiss
    def dismiss
      if @alert.dismiss!(current_user.full_name)
        render json: { 
          success: true, 
          message: "Alert dismissed successfully",
          alert: alert_json(@alert)
        }
      else
        render json: { 
          success: false, 
          error: "Failed to dismiss alert",
          errors: @alert.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "Error dismissing alert #{params[:id]}: #{e.message}"
      render json: { 
        success: false, 
        error: "An unexpected error occurred while dismissing the alert" 
      }, status: :internal_server_error
    end

    private

    def find_alert
      @alert = current_organization.alerts
                                  .where(alert_type: "pipeline")
                                  .find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { 
        success: false, 
        error: "Alert not found or you don't have permission to access it" 
      }, status: :not_found
    end

    def alert_json(alert)
      {
        id: alert.id,
        title: alert.title,
        message: alert.message,
        severity: alert.severity,
        status: alert.status,
        alert_type: alert.alert_type,
        created_at: alert.created_at.iso8601,
        updated_at: alert.updated_at.iso8601,
        resolved_at: alert.resolved_at&.iso8601,
        acknowledged_at: alert.acknowledged_at&.iso8601,
        dismissed_at: alert.dismissed_at&.iso8601,
        resolved_by: alert.resolved_by,
        acknowledged_by: alert.acknowledged_by,
        dismissed_by: alert.dismissed_by,
        data_source: alert.data_source ? {
          id: alert.data_source.id,
          name: alert.data_source.name,
          source_type: alert.data_source.source_type
        } : nil,
        user: alert.user ? {
          id: alert.user.id,
          name: alert.user.full_name,
          email: alert.user.email
        } : nil,
        pipeline_execution: alert.pipeline_execution ? {
          id: alert.pipeline_execution.id,
          status: alert.pipeline_execution.status,
          started_at: alert.pipeline_execution.started_at&.iso8601
        } : nil
      }
    end

    def current_organization
      current_user.organization
    end
  end
end
