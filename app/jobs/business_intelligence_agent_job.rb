# frozen_string_literal: true

class BusinessIntelligenceAgentJob < ApplicationJob
  queue_as :ai_agents
  
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  
  def perform(organization_id, task_type = 'continuous_monitoring')
    @organization = Organization.find(organization_id)
    @agent = Ai::BusinessIntelligenceAgentService.new(organization: @organization)
    
    Rails.logger.info "Starting BI Agent task '#{task_type}' for #{@organization.name}"
    
    case task_type
    when 'continuous_monitoring'
      perform_continuous_monitoring
    when 'weekly_report'
      generate_weekly_report
    when 'proactive_insights'
      generate_proactive_insights
    when 'customer_lifecycle_monitoring'
      monitor_customer_lifecycle
    when 'competitive_analysis'
      perform_competitive_analysis
    when 'scenario_planning'
      perform_scenario_planning
    when 'learning_adaptation'
      perform_learning_adaptation
    else
      Rails.logger.error "Unknown BI Agent task type: #{task_type}"
    end
    
  rescue => e
    Rails.logger.error "BI Agent job failed for #{@organization.name}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    # Send error notification
    send_agent_error_notification(e, task_type)
    
    raise e
  end
  
  private
  
  def perform_continuous_monitoring
    # Continuous autonomous monitoring and insights generation
    monitoring_duration = 24.hours # Run for 24 hours then reschedule
    end_time = Time.current + monitoring_duration
    
    while Time.current < end_time
      begin
        # Generate proactive insights
        insights = @agent.generate_proactive_insights
        
        # Process high-priority insights
        process_high_priority_insights(insights)
        
        # Detect anomalies and opportunities
        anomalies_and_opportunities = @agent.detect_business_anomalies_and_opportunities
        
        # Process critical findings
        process_critical_findings(anomalies_and_opportunities)
        
        # Monitor customer lifecycle
        customer_insights = @agent.monitor_customer_lifecycle
        
        # Process customer-related actions
        process_customer_actions(customer_insights)
        
        # Learn and adapt
        @agent.learn_and_adapt if should_perform_learning_cycle?
        
        # Broadcast insights to dashboard
        broadcast_agent_insights(insights, anomalies_and_opportunities, customer_insights)
        
        # Store insights for future reference
        store_agent_insights(insights, anomalies_and_opportunities, customer_insights)
        
      rescue => e
        Rails.logger.error "Error in BI Agent monitoring cycle: #{e.message}"
        # Continue monitoring even if one cycle fails
      end
      
      # Wait before next cycle (default: 1 hour)
      sleep(1.hour)
    end
    
    # Schedule next monitoring period
    BusinessIntelligenceAgentJob.perform_later(@organization.id, 'continuous_monitoring')
  end
  
  def generate_weekly_report
    # Generate comprehensive weekly intelligence report
    Rails.logger.info "Generating weekly BI report for #{@organization.name}"
    
    report = @agent.generate_weekly_intelligence_report
    
    # Create and store the report
    create_weekly_report_record(report)
    
    # Generate presentation from report
    generate_report_presentation(report)
    
    # Send report to stakeholders
    send_weekly_report_to_stakeholders(report)
    
    # Schedule next weekly report
    BusinessIntelligenceAgentJob.perform_in(1.week, @organization.id, 'weekly_report')
  end
  
  def generate_proactive_insights
    # Generate and process proactive insights
    insights = @agent.generate_proactive_insights
    
    # Send immediate notifications for critical insights
    send_critical_insights_notifications(insights)
    
    # Update dashboard with new insights
    broadcast_insights_update(insights)
    
    # Store insights
    store_proactive_insights(insights)
  end
  
  def monitor_customer_lifecycle
    # Monitor customer lifecycle and trigger actions
    lifecycle_insights = @agent.monitor_customer_lifecycle
    
    # Process churn predictions
    process_churn_predictions(lifecycle_insights[:churn_predictions])
    
    # Process expansion opportunities
    process_expansion_opportunities(lifecycle_insights[:expansion_opportunities])
    
    # Process at-risk customers
    process_at_risk_customers(lifecycle_insights[:at_risk_customers])
    
    # Generate customer action recommendations
    generate_customer_action_recommendations(lifecycle_insights)
  end
  
  def perform_competitive_analysis
    # Perform competitive intelligence analysis
    competitive_analysis = @agent.perform_competitive_analysis
    
    # Process competitive threats
    process_competitive_threats(competitive_analysis[:threat_assessment])
    
    # Identify strategic opportunities
    identify_strategic_opportunities(competitive_analysis[:opportunity_gaps])
    
    # Send competitive intelligence update
    send_competitive_intelligence_update(competitive_analysis)
  end
  
  def perform_scenario_planning
    # Generate business scenario predictions
    scenarios = @agent.predict_business_scenarios
    
    # Process scenario recommendations
    process_scenario_recommendations(scenarios)
    
    # Update risk assessment
    update_risk_assessment(scenarios[:scenarios])
    
    # Send scenario planning update
    send_scenario_planning_update(scenarios)
  end
  
  def perform_learning_adaptation
    # Agent learning and adaptation cycle
    learning_results = @agent.learn_and_adapt
    
    # Update agent configuration based on learning
    update_agent_configuration(learning_results)
    
    # Log learning progress
    log_learning_progress(learning_results)
  end
  
  def process_high_priority_insights(insights)
    return unless insights[:proactive_insights]
    
    high_priority = insights[:proactive_insights].select do |insight|
      insight[:priority_score] && insight[:priority_score] > 8.0
    end
    
    high_priority.each do |insight|
      # Send immediate notification for high-priority insights
      send_high_priority_insight_notification(insight)
      
      # Create action items if needed
      create_action_items_for_insight(insight)
      
      # Update relevant dashboards
      update_dashboard_with_insight(insight)
    end
  end
  
  def process_critical_findings(findings)
    # Process critical anomalies
    critical_anomalies = findings[:anomalies][:severity_assessment] == 'critical'
    
    if critical_anomalies
      send_critical_anomaly_alert(findings[:anomalies])
      create_emergency_response_plan(findings[:anomalies])
    end
    
    # Process high-impact opportunities
    high_impact_opportunities = findings[:opportunities][:impact_assessment] == 'high'
    
    if high_impact_opportunities
      send_opportunity_alert(findings[:opportunities])
      create_opportunity_action_plan(findings[:opportunities])
    end
  end
  
  def process_customer_actions(customer_insights)
    # Process churn risk customers
    if customer_insights[:at_risk_customers]&.any?
      trigger_customer_retention_workflows(customer_insights[:at_risk_customers])
    end
    
    # Process expansion opportunities
    if customer_insights[:expansion_opportunities]&.any?
      trigger_expansion_workflows(customer_insights[:expansion_opportunities])
    end
    
    # Process upsell recommendations
    if customer_insights[:upsell_recommendations]&.any?
      trigger_upsell_workflows(customer_insights[:upsell_recommendations])
    end
  end
  
  def broadcast_agent_insights(insights, anomalies, customer_insights)
    # Broadcast insights via ActionCable
    ActionCable.server.broadcast(
      "bi_agent_#{@organization.id}",
      {
        type: 'agent_insights_update',
        insights: insights,
        anomalies: anomalies,
        customer_insights: customer_insights,
        timestamp: Time.current.iso8601
      }
    )
  end
  
  def store_agent_insights(insights, anomalies, customer_insights)
    # Store insights for historical analysis
    begin
      if defined?(AgentInsight)
        AgentInsight.create!(
          organization: @organization,
          insight_type: 'continuous_monitoring',
          insights_data: {
            insights: insights,
            anomalies: anomalies,
            customer_insights: customer_insights
          },
          confidence_score: insights[:agent_confidence],
          generated_at: Time.current
        )
      end
    rescue => e
      Rails.logger.warn "Failed to store agent insights: #{e.message}"
    end
  end
  
  def create_weekly_report_record(report)
    # Create weekly report record
    begin
      if defined?(WeeklyIntelligenceReport)
        WeeklyIntelligenceReport.create!(
          organization: @organization,
          week_ending: Date.parse(report[:week_ending]),
          report_data: report,
          confidence_score: report[:confidence_score],
          generated_at: Time.current
        )
      end
    rescue => e
      Rails.logger.warn "Failed to create weekly report record: #{e.message}"
    end
  end
  
  def generate_report_presentation(report)
    # Generate presentation from weekly report
    begin
      presentation_service = Ai::PresentationGeneratorService.new(
        organization: @organization,
        template_type: 'weekly_intelligence',
        insights_data: report
      )
      
      presentation_service.generate_presentation
    rescue => e
      Rails.logger.warn "Failed to generate report presentation: #{e.message}"
    end
  end
  
  def send_weekly_report_to_stakeholders(report)
    # Send weekly report to organization stakeholders
    Rails.logger.info "Sending weekly BI report to stakeholders for #{@organization.name}"
    
    if defined?(NotificationService)
      NotificationService.new.send_weekly_intelligence_report(
        organization: @organization,
        report: report
      )
    end
  end
  
  def send_critical_insights_notifications(insights)
    critical_insights = insights[:proactive_insights]&.select do |insight|
      insight[:urgency_level] == 'critical'
    end
    
    return unless critical_insights&.any?
    
    Rails.logger.warn "Sending critical insights notifications for #{@organization.name}"
    
    if defined?(NotificationService)
      NotificationService.new.send_critical_insights(
        organization: @organization,
        insights: critical_insights
      )
    end
  end
  
  def send_high_priority_insight_notification(insight)
    Rails.logger.info "Sending high-priority insight notification: #{insight[:title]}"
    
    if defined?(NotificationService)
      NotificationService.new.send_high_priority_insight(
        organization: @organization,
        insight: insight
      )
    end
  end
  
  def send_agent_error_notification(error, task_type)
    Rails.logger.error "Sending BI Agent error notification: #{error.message}"
    
    if defined?(NotificationService)
      NotificationService.new.send_agent_error(
        organization: @organization,
        error: error,
        task_type: task_type
      )
    end
  end
  
  def should_perform_learning_cycle?
    # Determine if agent should perform learning cycle
    # Learn every 6 hours during continuous monitoring
    last_learning = @organization.updated_at # Placeholder
    Time.current - last_learning > 6.hours
  end
  
  # Placeholder methods for complex workflows
  
  def create_action_items_for_insight(insight); Rails.logger.info "Creating action items for: #{insight[:title]}"; end
  def update_dashboard_with_insight(insight); Rails.logger.info "Updating dashboard with insight: #{insight[:title]}"; end
  def send_critical_anomaly_alert(anomalies); Rails.logger.warn "Critical anomaly alert sent"; end
  def create_emergency_response_plan(anomalies); Rails.logger.info "Emergency response plan created"; end
  def send_opportunity_alert(opportunities); Rails.logger.info "Opportunity alert sent"; end
  def create_opportunity_action_plan(opportunities); Rails.logger.info "Opportunity action plan created"; end
  def trigger_customer_retention_workflows(customers); Rails.logger.info "Customer retention workflows triggered"; end
  def trigger_expansion_workflows(opportunities); Rails.logger.info "Expansion workflows triggered"; end
  def trigger_upsell_workflows(recommendations); Rails.logger.info "Upsell workflows triggered"; end
  def broadcast_insights_update(insights); Rails.logger.info "Broadcasting insights update"; end
  def store_proactive_insights(insights); Rails.logger.info "Storing proactive insights"; end
  def process_churn_predictions(predictions); Rails.logger.info "Processing churn predictions"; end
  def process_expansion_opportunities(opportunities); Rails.logger.info "Processing expansion opportunities"; end
  def process_at_risk_customers(customers); Rails.logger.info "Processing at-risk customers"; end
  def generate_customer_action_recommendations(insights); Rails.logger.info "Generating customer action recommendations"; end
  def process_competitive_threats(threats); Rails.logger.info "Processing competitive threats"; end
  def identify_strategic_opportunities(gaps); Rails.logger.info "Identifying strategic opportunities"; end
  def send_competitive_intelligence_update(analysis); Rails.logger.info "Sending competitive intelligence update"; end
  def process_scenario_recommendations(scenarios); Rails.logger.info "Processing scenario recommendations"; end
  def update_risk_assessment(scenarios); Rails.logger.info "Updating risk assessment"; end
  def send_scenario_planning_update(scenarios); Rails.logger.info "Sending scenario planning update"; end
  def update_agent_configuration(learning); Rails.logger.info "Updating agent configuration"; end
  def log_learning_progress(learning); Rails.logger.info "Logging learning progress"; end
end