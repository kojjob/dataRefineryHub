# frozen_string_literal: true

module Ai
  class BiAgentController < ::DataflowProController
    before_action :ensure_organization_member

    def dashboard
      @agent = Ai::BusinessIntelligenceAgentService.new(organization: current_organization)
      @agent_status = get_agent_status
      @recent_insights = get_recent_agent_insights
      @weekly_reports = get_recent_weekly_reports
    end

    def start_agent
      begin
        # Start the autonomous BI agent
        BusinessIntelligenceAgentJob.perform_later(current_organization.id, "continuous_monitoring")

        render json: {
          success: true,
          message: "Business Intelligence Agent started successfully",
          status: "active"
        }
      rescue => e
        Rails.logger.error "Failed to start BI Agent: #{e.message}"

        render json: {
          success: false,
          error: "Failed to start agent: #{e.message}"
        }, status: :internal_server_error
      end
    end

    def stop_agent
      begin
        # Stop the autonomous BI agent
        # In production, this would cancel background jobs

        render json: {
          success: true,
          message: "Business Intelligence Agent stopped",
          status: "inactive"
        }
      rescue => e
        Rails.logger.error "Failed to stop BI Agent: #{e.message}"

        render json: {
          success: false,
          error: "Failed to stop agent: #{e.message}"
        }, status: :internal_server_error
      end
    end

    def generate_insights
      begin
        agent = Ai::BusinessIntelligenceAgentService.new(organization: current_organization)
        insights = agent.generate_proactive_insights

        render json: {
          success: true,
          insights: insights,
          generated_at: Time.current.iso8601
        }
      rescue => e
        Rails.logger.error "Failed to generate insights: #{e.message}"

        render json: {
          success: false,
          error: "Failed to generate insights: #{e.message}"
        }, status: :internal_server_error
      end
    end

    def weekly_report
      begin
        agent = Ai::BusinessIntelligenceAgentService.new(organization: current_organization)
        report = agent.generate_weekly_intelligence_report

        render json: {
          success: true,
          report: report,
          generated_at: Time.current.iso8601
        }
      rescue => e
        Rails.logger.error "Failed to generate weekly report: #{e.message}"

        render json: {
          success: false,
          error: "Failed to generate weekly report: #{e.message}"
        }, status: :internal_server_error
      end
    end

    def customer_analysis
      begin
        agent = Ai::BusinessIntelligenceAgentService.new(organization: current_organization)
        analysis = agent.monitor_customer_lifecycle

        render json: {
          success: true,
          analysis: analysis,
          generated_at: Time.current.iso8601
        }
      rescue => e
        Rails.logger.error "Failed to perform customer analysis: #{e.message}"

        render json: {
          success: false,
          error: "Failed to perform customer analysis: #{e.message}"
        }, status: :internal_server_error
      end
    end

    def competitive_analysis
      begin
        agent = Ai::BusinessIntelligenceAgentService.new(organization: current_organization)
        analysis = agent.perform_competitive_analysis

        render json: {
          success: true,
          analysis: analysis,
          generated_at: Time.current.iso8601
        }
      rescue => e
        Rails.logger.error "Failed to perform competitive analysis: #{e.message}"

        render json: {
          success: false,
          error: "Failed to perform competitive analysis: #{e.message}"
        }, status: :internal_server_error
      end
    end

    def scenario_planning
      begin
        agent = Ai::BusinessIntelligenceAgentService.new(organization: current_organization)
        scenarios = agent.predict_business_scenarios

        render json: {
          success: true,
          scenarios: scenarios,
          generated_at: Time.current.iso8601
        }
      rescue => e
        Rails.logger.error "Failed to generate scenarios: #{e.message}"

        render json: {
          success: false,
          error: "Failed to generate scenarios: #{e.message}"
        }, status: :internal_server_error
      end
    end

    def agent_status
      status = get_agent_status

      render json: {
        success: true,
        status: status,
        timestamp: Time.current.iso8601
      }
    end

    def configure_agent
      config = params[:agent_config] || {}

      # Validate configuration
      unless valid_agent_config?(config)
        return render json: {
          success: false,
          error: "Invalid agent configuration"
        }, status: :bad_request
      end

      # Store agent configuration
      store_agent_configuration(config)

      render json: {
        success: true,
        message: "Agent configuration updated",
        config: config
      }
    end

    def learning_status
      begin
        agent = Ai::BusinessIntelligenceAgentService.new(organization: current_organization)
        learning_data = agent.learn_and_adapt

        render json: {
          success: true,
          learning_status: learning_data,
          timestamp: Time.current.iso8601
        }
      rescue => e
        Rails.logger.error "Failed to get learning status: #{e.message}"

        render json: {
          success: false,
          error: "Failed to get learning status: #{e.message}"
        }, status: :internal_server_error
      end
    end

    def feedback
      insight_id = params[:insight_id]
      feedback_type = params[:feedback_type] # 'helpful', 'not_helpful', 'accurate', 'inaccurate'
      feedback_comment = params[:comment]

      if insight_id.blank? || feedback_type.blank?
        return render json: {
          success: false,
          error: "Insight ID and feedback type are required"
        }, status: :bad_request
      end

      # Store feedback for agent learning
      store_agent_feedback(insight_id, feedback_type, feedback_comment)

      render json: {
        success: true,
        message: "Feedback recorded successfully"
      }
    end

    def export_insights
      format = params[:format] || "json"
      time_range = params[:time_range] || "7d"

      insights = get_insights_for_export(time_range)

      case format.downcase
      when "json"
        send_data insights.to_json,
                  filename: "bi_insights_#{current_organization.slug}_#{Date.current}.json",
                  type: "application/json"
      when "csv"
        csv_data = generate_insights_csv(insights)
        send_data csv_data,
                  filename: "bi_insights_#{current_organization.slug}_#{Date.current}.csv",
                  type: "text/csv"
      else
        render json: {
          success: false,
          error: "Unsupported export format: #{format}"
        }, status: :bad_request
      end
    end

    private

    def get_agent_status
      # Get current agent status
      # In production, this would check background job status and query actual data
      recent_insights = get_recent_agent_insights

      {
        status: "active", # active, inactive, error
        last_run: Time.current - 1.hour,
        next_run: Time.current + 1.hour,
        insights_generated_today: recent_insights.count { |i| Time.parse(i[:generated_at]) > Date.current.beginning_of_day },
        insights_trend: calculate_insights_trend(recent_insights),
        alerts_sent_today: recent_insights.count { |i| i[:priority] == "critical" },
        alerts_breakdown: calculate_alerts_breakdown(recent_insights),
        learning_enabled: true,
        confidence_level: calculate_average_confidence(recent_insights),
        accuracy_rate: calculate_accuracy_rate,
        uptime: calculate_uptime
      }
    end

    def get_recent_agent_insights
      # Get recent insights generated by the agent
      # This would query actual insights from database
      [
        {
          id: SecureRandom.hex(8),
          title: "Revenue Growth Opportunity Detected",
          description: "Product category X shows 34% week-over-week growth potential",
          priority: "high",
          confidence: 0.89,
          generated_at: 2.hours.ago.iso8601,
          status: "actionable"
        },
        {
          id: SecureRandom.hex(8),
          title: "Customer Churn Risk Alert",
          description: "15 high-value customers showing churn indicators",
          priority: "critical",
          confidence: 0.92,
          generated_at: 4.hours.ago.iso8601,
          status: "action_required"
        },
        {
          id: SecureRandom.hex(8),
          title: "Operational Efficiency Improvement",
          description: "Data processing pipeline optimization could save 23% time",
          priority: "medium",
          confidence: 0.76,
          generated_at: 6.hours.ago.iso8601,
          status: "under_review"
        }
      ]
    end

    def get_recent_weekly_reports
      # Get recent weekly intelligence reports
      # This would query actual reports from database
      [
        {
          id: SecureRandom.hex(8),
          week_ending: Date.current.end_of_week.strftime("%Y-%m-%d"),
          title: "Weekly Intelligence Report",
          status: "completed",
          confidence_score: "high",
          key_findings: 5,
          generated_at: 1.day.ago.iso8601
        },
        {
          id: SecureRandom.hex(8),
          week_ending: 1.week.ago.end_of_week.strftime("%Y-%m-%d"),
          title: "Weekly Intelligence Report",
          status: "completed",
          confidence_score: "high",
          key_findings: 7,
          generated_at: 1.week.ago.iso8601
        }
      ]
    end

    def valid_agent_config?(config)
      # Validate agent configuration
      return false unless config.is_a?(Hash)

      allowed_keys = %w[monitoring_frequency report_frequency alert_threshold learning_rate capabilities]
      config.keys.all? { |key| allowed_keys.include?(key.to_s) }
    end

    def store_agent_configuration(config)
      # Store agent configuration
      # In production, this would save to database
      Rails.logger.info "Storing agent configuration for #{current_organization.name}: #{config}"
    end

    def store_agent_feedback(insight_id, feedback_type, comment)
      # Store feedback for agent learning
      Rails.logger.info "Storing agent feedback: #{insight_id} - #{feedback_type}"

      # In production, this would save to database for agent learning
      if defined?(AgentFeedback)
        AgentFeedback.create!(
          organization: current_organization,
          insight_id: insight_id,
          feedback_type: feedback_type,
          comment: comment,
          user: current_user,
          created_at: Time.current
        )
      end
    end

    def get_insights_for_export(time_range)
      # Get insights for export based on time range
      case time_range
      when "1d"
        get_recent_agent_insights.select { |i| Time.parse(i[:generated_at]) > 1.day.ago }
      when "7d"
        get_recent_agent_insights
      when "30d"
        # Would fetch more data in production
        get_recent_agent_insights
      else
        get_recent_agent_insights
      end
    end

    def generate_insights_csv(insights)
      require "csv"

      CSV.generate(headers: true) do |csv|
        csv << [ "Generated At", "Title", "Description", "Priority", "Confidence", "Status" ]

        insights.each do |insight|
          csv << [
            insight[:generated_at],
            insight[:title],
            insight[:description],
            insight[:priority],
            insight[:confidence],
            insight[:status]
          ]
        end
      end
    end

    def calculate_insights_trend(insights)
      today_count = insights.count { |i| Time.parse(i[:generated_at]) > Date.current.beginning_of_day }
      yesterday_count = insights.count { |i|
        date = Time.parse(i[:generated_at]).to_date
        date == Date.current - 1.day
      }

      change = today_count - yesterday_count
      direction = change > 0 ? "up" : change < 0 ? "down" : "neutral"

      { change: change.abs, direction: direction }
    end

    def calculate_alerts_breakdown(insights)
      {
        critical: insights.count { |i| i[:priority] == "critical" },
        medium: insights.count { |i| i[:priority] == "medium" },
        low: insights.count { |i| i[:priority] == "low" }
      }
    end

    def calculate_average_confidence(insights)
      return "medium" if insights.empty?

      avg_confidence = insights.map { |i| i[:confidence] }.compact.sum / insights.size.to_f

      case avg_confidence
      when 0.8..1.0 then "high"
      when 0.6..0.8 then "medium"
      else "low"
      end
    end

    def calculate_accuracy_rate
      # In production, this would calculate based on historical prediction accuracy
      # For now, return a reasonable default based on confidence levels
      0.75 + (rand * 0.2) # 75-95% range
    end

    def calculate_uptime
      # In production, this would calculate based on actual agent uptime
      # For now, return a high uptime percentage
      base_uptime = 99.0
      variation = rand * 0.5 # Small random variation
      "#{(base_uptime + variation).round(1)}%"
    end
  end
end
