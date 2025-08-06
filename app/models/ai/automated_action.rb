# frozen_string_literal: true

module Ai
  class AutomatedAction < ApplicationRecord
    self.table_name = "ai_automated_actions"

    belongs_to :insight, optional: true
    belongs_to :organization
    belongs_to :approved_by, class_name: "User", optional: true

    validates :action_type, presence: true
    validates :parameters, presence: true

    # Action status workflow
    enum :status, {
      pending: 0,
      approved: 1,
      executing: 2,
      executed: 3,
      failed: 4,
      rejected: 5,
      cancelled: 6
    }, prefix: true

    # Action types with risk levels
    enum :action_type, {
      # Low risk - can auto-execute
      send_notification: 0,
      generate_report: 1,
      export_data: 2,
      create_dashboard: 3,

      # Medium risk - requires approval
      send_email: 10,
      create_campaign: 11,
      update_forecast: 12,
      schedule_meeting: 13,

      # High risk - requires explicit approval
      adjust_pricing: 20,
      reorder_inventory: 21,
      pause_campaign: 22,
      update_budget: 23,
      modify_targets: 24,

      # Critical - requires multi-level approval
      process_refund: 30,
      delete_data: 31,
      change_permissions: 32,
      modify_integration: 33
    }, prefix: true

    # Risk levels for approval routing
    RISK_LEVELS = {
      low: %w[send_notification generate_report export_data create_dashboard],
      medium: %w[send_email create_campaign update_forecast schedule_meeting],
      high: %w[adjust_pricing reorder_inventory pause_campaign update_budget modify_targets],
      critical: %w[process_refund delete_data change_permissions modify_integration]
    }.freeze

    scope :pending_approval, -> { status_pending.where("created_at > ?", 24.hours.ago) }
    scope :recently_executed, -> { status_executed.order(executed_at: :desc) }
    scope :failed_recently, -> { status_failed.where("updated_at > ?", 1.hour.ago) }

    before_validation :set_default_parameters
    after_create :check_auto_approval

    def risk_level
      RISK_LEVELS.each do |level, types|
        return level if types.include?(action_type)
      end
      :unknown
    end

    def requires_approval?
      !%i[low].include?(risk_level)
    end

    def requires_multi_approval?
      risk_level == :critical
    end

    def can_auto_execute?
      risk_level == :low && organization.settings&.dig("ai", "auto_execute_low_risk")
    end

    def estimated_impact
      case action_type
      when "adjust_pricing"
        calculate_pricing_impact
      when "reorder_inventory"
        calculate_inventory_impact
      when "send_email"
        calculate_email_impact
      when "create_campaign"
        calculate_campaign_impact
      else
        { description: "Minimal impact expected", risk: risk_level }
      end
    end

    def execute!
      return false unless can_execute?

      update!(status: :executing, executed_at: Time.current)

      begin
        result = case action_type
        when "send_notification"
          ActionExecutors::NotificationExecutor.new(self).execute
        when "send_email"
          ActionExecutors::EmailExecutor.new(self).execute
        when "generate_report"
          ActionExecutors::ReportExecutor.new(self).execute
        when "adjust_pricing"
          ActionExecutors::PricingExecutor.new(self).execute
        when "reorder_inventory"
          ActionExecutors::InventoryExecutor.new(self).execute
        when "create_campaign"
          ActionExecutors::CampaignExecutor.new(self).execute
        else
          raise "Unknown action type: #{action_type}"
        end

        update!(
          status: :executed,
          result: result,
          completed_at: Time.current
        )

        # Track success metrics
        track_execution_success

        true
      rescue StandardError => e
        update!(
          status: :failed,
          result: { error: e.message, backtrace: e.backtrace.first(5) }
        )

        # Notify on failure
        notify_failure(e)

        false
      end
    end

    def can_execute?
      return false unless status_approved? || (status_pending? && can_auto_execute?)
      return false if requires_multi_approval? && !has_required_approvals?

      true
    end

    def approve!(user)
      transaction do
        update!(
          status: :approved,
          approved_by: user,
          approved_at: Time.current
        )

        # Auto-execute if configured
        if organization.settings&.dig("ai", "auto_execute_approved")
          Ai::ActionExecutorJob.perform_later(self)
        end
      end
    end

    def reject!(user, reason = nil)
      update!(
        status: :rejected,
        approved_by: user,
        result: { rejection_reason: reason }
      )
    end

    def description
      case action_type
      when "send_email"
        "Send email to #{parameters['recipient_count']} recipients about #{parameters['subject']}"
      when "adjust_pricing"
        "Adjust pricing by #{parameters['adjustment_percent']}% for #{parameters['product_name']}"
      when "reorder_inventory"
        "Reorder #{parameters['quantity']} units of #{parameters['product_name']}"
      when "create_campaign"
        "Create #{parameters['campaign_type']} campaign: #{parameters['campaign_name']}"
      when "generate_report"
        "Generate #{parameters['report_type']} report for #{parameters['time_period']}"
      else
        "Execute #{action_type.humanize.downcase}"
      end
    end

    def preview_changes
      case action_type
      when "adjust_pricing"
        preview_pricing_changes
      when "send_email"
        preview_email_recipients
      when "create_campaign"
        preview_campaign_details
      else
        { message: "Preview not available for #{action_type}" }
      end
    end

    private

    def set_default_parameters
      self.parameters ||= {}
      self.suggested_by ||= "bi_agent"
    end

    def check_auto_approval
      if can_auto_execute?
        approve!(User.system_user)
        Ai::ActionExecutorJob.perform_later(self)
      elsif requires_approval?
        notify_pending_approval
      end
    end

    def calculate_pricing_impact
      current_price = parameters["current_price"] || 0
      adjustment = parameters["adjustment_percent"] || 0
      new_price = current_price * (1 + adjustment / 100.0)

      {
        current_price: current_price,
        new_price: new_price,
        estimated_revenue_impact: estimate_revenue_impact(adjustment),
        affected_customers: count_affected_customers,
        risk: risk_level
      }
    end

    def calculate_inventory_impact
      quantity = parameters["quantity"] || 0
      unit_cost = parameters["unit_cost"] || 0
      total_cost = quantity * unit_cost

      {
        quantity: quantity,
        total_cost: total_cost,
        estimated_delivery: estimate_delivery_date,
        storage_impact: calculate_storage_needs(quantity),
        risk: risk_level
      }
    end

    def calculate_email_impact
      recipient_count = parameters["recipient_count"] || 0

      {
        recipients: recipient_count,
        estimated_open_rate: "#{(recipient_count * 0.22).round}",
        estimated_click_rate: "#{(recipient_count * 0.028).round}",
        cost: calculate_email_cost(recipient_count),
        risk: risk_level
      }
    end

    def calculate_campaign_impact
      budget = parameters["budget"] || 0
      duration = parameters["duration_days"] || 30

      {
        budget: budget,
        daily_spend: budget / duration,
        estimated_reach: estimate_campaign_reach(budget),
        estimated_conversions: estimate_conversions(budget),
        risk: risk_level
      }
    end

    def preview_pricing_changes
      {
        current_state: {
          price: parameters["current_price"],
          revenue_last_30_days: calculate_recent_revenue
        },
        proposed_state: {
          price: parameters["current_price"] * (1 + parameters["adjustment_percent"] / 100.0),
          estimated_revenue_change: "#{parameters['adjustment_percent']}%"
        },
        affected_items: parameters["affected_products"] || []
      }
    end

    def preview_email_recipients
      {
        recipient_segments: parameters["segments"] || [],
        total_recipients: parameters["recipient_count"],
        excluded_count: parameters["excluded_count"] || 0,
        preview_content: parameters["email_preview"]
      }
    end

    def preview_campaign_details
      {
        campaign_type: parameters["campaign_type"],
        target_audience: parameters["audience"],
        channels: parameters["channels"] || [],
        schedule: parameters["schedule"],
        success_metrics: parameters["kpis"] || []
      }
    end

    def notify_pending_approval
      # Send notification to approvers
      NotificationService.new.notify_approvers(self)
    end

    def notify_failure(error)
      # Send failure notification
      NotificationService.new.notify_action_failure(self, error)
    end

    def track_execution_success
      # Track metrics for learning
      organization.increment!(:ai_actions_executed)
    end

    def has_required_approvals?
      # For critical actions, check if we have all required approvals
      # This could be extended to check multiple approval levels
      approved_by.present?
    end

    # Estimation helpers (would use historical data in production)
    def estimate_revenue_impact(adjustment_percent)
      base_revenue = 10000 # Would calculate from actual data
      (base_revenue * adjustment_percent / 100.0).round(2)
    end

    def count_affected_customers
      100 # Would count from actual data
    end

    def estimate_delivery_date
      5.business_days.from_now
    end

    def calculate_storage_needs(quantity)
      "#{quantity / 10} pallets"
    end

    def calculate_email_cost(recipient_count)
      (recipient_count * 0.001).round(2) # $0.001 per email
    end

    def estimate_campaign_reach(budget)
      (budget * 100).round # Simplified: $1 = 100 impressions
    end

    def estimate_conversions(budget)
      (budget * 0.5).round # Simplified: $1 = 0.5 conversions
    end

    def calculate_recent_revenue
      # Would query actual revenue data
      25000
    end
  end
end
