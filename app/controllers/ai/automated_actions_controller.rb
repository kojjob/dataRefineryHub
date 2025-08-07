# frozen_string_literal: true

module Ai
  class AutomatedActionsController < ApplicationController
    before_action :authenticate_user!
    before_action :ensure_organization_member
    before_action :set_automated_action, only: [ :show ]

    def index
      @page_title = "AI Automated Actions"
      @page_subtitle = "Intelligent automation for your data workflows"

      # Sample automated actions for demonstration
      @automated_actions = [
        {
          id: 1,
          name: "Data Quality Alert",
          description: "Automatically detect and alert on data quality issues",
          status: "active",
          trigger: "Data quality score drops below 85%",
          action: "Send email notification to data team",
          last_executed: 2.hours.ago,
          execution_count: 47,
          success_rate: 98.5
        },
        {
          id: 2,
          name: "Revenue Anomaly Detection",
          description: "Monitor revenue patterns and flag unusual changes",
          status: "active",
          trigger: "Revenue deviation > 15% from forecast",
          action: "Create Slack alert and dashboard notification",
          last_executed: 1.day.ago,
          execution_count: 12,
          success_rate: 100.0
        },
        {
          id: 3,
          name: "Customer Churn Prevention",
          description: "Identify at-risk customers and trigger retention campaigns",
          status: "paused",
          trigger: "Customer engagement score drops below 30%",
          action: "Add to retention campaign list",
          last_executed: 3.days.ago,
          execution_count: 8,
          success_rate: 87.5
        },
        {
          id: 4,
          name: "Inventory Optimization",
          description: "Automatically adjust inventory levels based on demand forecasts",
          status: "active",
          trigger: "Predicted stockout within 7 days",
          action: "Generate purchase order recommendation",
          last_executed: 6.hours.ago,
          execution_count: 23,
          success_rate: 95.7
        }
      ]

      # Action categories for filtering
      @action_categories = [
        { name: "Data Quality", count: 5, icon: "🔍" },
        { name: "Revenue Monitoring", count: 3, icon: "💰" },
        { name: "Customer Analytics", count: 4, icon: "👥" },
        { name: "Inventory Management", count: 2, icon: "📦" },
        { name: "Marketing Automation", count: 6, icon: "📢" }
      ]

      # Performance metrics
      @performance_metrics = {
        total_actions: 20,
        active_actions: 15,
        total_executions: 1247,
        success_rate: 96.8,
        avg_response_time: "1.2s",
        cost_savings: "$45,000"
      }
    end

    def show
      # This would typically load a specific automated action
      # For now, we'll use sample data
      @automated_action = {
        id: params[:id],
        name: "Data Quality Alert",
        description: "Automatically detect and alert on data quality issues across all connected data sources",
        status: "active",
        created_at: 2.weeks.ago,
        updated_at: 1.day.ago,
        trigger: {
          type: "threshold",
          condition: "Data quality score drops below 85%",
          frequency: "real-time"
        },
        action: {
          type: "notification",
          details: "Send email notification to data team and create dashboard alert",
          recipients: [ "data-team@company.com" ]
        },
        execution_history: [
          { date: 2.hours.ago, status: "success", duration: "0.8s" },
          { date: 1.day.ago, status: "success", duration: "1.1s" },
          { date: 2.days.ago, status: "success", duration: "0.9s" },
          { date: 3.days.ago, status: "failed", duration: "2.3s", error: "SMTP timeout" },
          { date: 4.days.ago, status: "success", duration: "1.0s" }
        ],
        metrics: {
          total_executions: 47,
          success_rate: 98.5,
          avg_response_time: "1.0s",
          last_executed: 2.hours.ago
        }
      }
    end

    private

    def set_automated_action
      # In a real implementation, this would load from the database
      # @automated_action = current_organization.automated_actions.find(params[:id])
    end

    def ensure_organization_member
      redirect_to root_path unless current_user&.organization_id.present?
    end
  end
end
