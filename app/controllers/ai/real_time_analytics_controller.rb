# frozen_string_literal: true

module Ai
  class RealTimeAnalyticsController < ApplicationController
    before_action :ensure_organization_member

    def dashboard
      @analytics_service = Ai::RealTimeAnalyticsService.new(organization: current_organization)
      @dashboard_data = @analytics_service.get_real_time_dashboard_data
      @performance_data = @analytics_service.get_performance_dashboard_data
    end

    def live_data
      analytics_service = Ai::RealTimeAnalyticsService.new(organization: current_organization)
      dashboard_data = analytics_service.get_real_time_dashboard_data

      render json: {
        success: true,
        data: dashboard_data,
        timestamp: Time.current.iso8601
      }
    end

    def anomalies
      analytics_service = Ai::RealTimeAnalyticsService.new(organization: current_organization)
      anomalies = analytics_service.detect_real_time_anomalies

      render json: {
        success: true,
        anomalies: anomalies,
        count: anomalies.count,
        timestamp: Time.current.iso8601
      }
    end

    def alerts
      # Get active alerts for the organization
      analytics_service = Ai::RealTimeAnalyticsService.new(organization: current_organization)
      dashboard_data = analytics_service.get_real_time_dashboard_data

      render json: {
        success: true,
        alerts: dashboard_data[:alerts],
        count: dashboard_data[:alerts].count,
        timestamp: Time.current.iso8601
      }
    end

    def insights
      analytics_service = Ai::RealTimeAnalyticsService.new(organization: current_organization)
      insights = analytics_service.generate_real_time_insights

      render json: {
        success: true,
        insights: insights,
        timestamp: Time.current.iso8601
      }
    end

    def predictions
      analytics_service = Ai::RealTimeAnalyticsService.new(organization: current_organization)
      predictions = analytics_service.predict_next_hour_metrics

      render json: {
        success: true,
        predictions: predictions,
        timestamp: Time.current.iso8601
      }
    end

    def performance_metrics
      analytics_service = Ai::RealTimeAnalyticsService.new(organization: current_organization)
      performance = analytics_service.get_performance_dashboard_data

      render json: {
        success: true,
        performance: performance,
        timestamp: Time.current.iso8601
      }
    end

    def start_monitoring
      # Start real-time monitoring for the organization
      # In production, this would enqueue a background job

      begin
        RealTimeAnalyticsJob.perform_later(current_organization.id)

        render json: {
          success: true,
          message: "Real-time monitoring started",
          monitoring_interval: "5 minutes"
        }
      rescue => e
        Rails.logger.error "Failed to start monitoring: #{e.message}"

        render json: {
          success: false,
          error: "Failed to start monitoring: #{e.message}"
        }, status: :internal_server_error
      end
    end

    def stop_monitoring
      # Stop real-time monitoring for the organization
      # In production, this would cancel background jobs

      render json: {
        success: true,
        message: "Real-time monitoring stopped"
      }
    end

    def configure_alerts
      alert_config = params[:alert_config] || {}

      # Store alert configuration for the organization
      # This would be saved to the database in production

      Rails.logger.info "Alert configuration updated for #{current_organization.name}: #{alert_config}"

      render json: {
        success: true,
        message: "Alert configuration updated",
        config: alert_config
      }
    end

    def dismiss_alert
      alert_id = params[:alert_id]

      if alert_id.blank?
        return render json: {
          success: false,
          error: "Alert ID is required"
        }, status: :bad_request
      end

      # In production, this would update the alert status in the database
      Rails.logger.info "Alert dismissed: #{alert_id}"

      render json: {
        success: true,
        message: "Alert dismissed",
        alert_id: alert_id
      }
    end

    def snooze_alert
      alert_id = params[:alert_id]
      snooze_duration = params[:duration]&.to_i || 3600 # Default 1 hour

      if alert_id.blank?
        return render json: {
          success: false,
          error: "Alert ID is required"
        }, status: :bad_request
      end

      # In production, this would update the alert to snooze until later
      snooze_until = snooze_duration.seconds.from_now
      Rails.logger.info "Alert snoozed until #{snooze_until}: #{alert_id}"

      render json: {
        success: true,
        message: "Alert snoozed",
        alert_id: alert_id,
        snooze_until: snooze_until.iso8601
      }
    end

    def export_analytics
      format = params[:format] || "csv"
      time_range = params[:time_range] || "24h"

      # Generate export data
      analytics_service = Ai::RealTimeAnalyticsService.new(organization: current_organization)
      dashboard_data = analytics_service.get_real_time_dashboard_data

      case format.downcase
      when "csv"
        export_data = generate_csv_export(dashboard_data, time_range)
        send_data export_data,
                  filename: "analytics_#{current_organization.slug}_#{Date.current}.csv",
                  type: "text/csv"
      when "json"
        export_data = generate_json_export(dashboard_data, time_range)
        send_data export_data.to_json,
                  filename: "analytics_#{current_organization.slug}_#{Date.current}.json",
                  type: "application/json"
      else
        render json: {
          success: false,
          error: "Unsupported export format: #{format}"
        }, status: :bad_request
      end
    end

    def health_check
      analytics_service = Ai::RealTimeAnalyticsService.new(organization: current_organization)
      dashboard_data = analytics_service.get_real_time_dashboard_data

      render json: {
        success: true,
        system_health: dashboard_data[:system_health],
        monitoring_status: dashboard_data[:monitoring_status],
        timestamp: Time.current.iso8601
      }
    end

    private

    def generate_csv_export(data, time_range)
      require "csv"

      CSV.generate(headers: true) do |csv|
        csv << [ "Timestamp", "Metric", "Value", "Status" ]

        # Add current metrics
        data[:metrics].each do |metric, value|
          csv << [ data[:timestamp], metric.to_s.humanize, value, "Current" ]
        end

        # Add anomalies
        data[:anomalies].each do |anomaly|
          csv << [ anomaly[:detected_at], anomaly[:metric], anomaly[:current_value], "Anomaly" ]
        end

        # Add alerts
        data[:alerts].each do |alert|
          csv << [ alert[:created_at], alert[:type], alert[:current_value], "Alert (#{alert[:severity]})" ]
        end
      end
    end

    def generate_json_export(data, time_range)
      {
        export_info: {
          organization: current_organization.name,
          time_range: time_range,
          exported_at: Time.current.iso8601,
          format: "json"
        },
        data: data
      }
    end
  end
end
