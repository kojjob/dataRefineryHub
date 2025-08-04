# frozen_string_literal: true

module BusinessTemplates
  class ServiceBusinessTemplate < BaseTemplate
    protected
    
    def template_name
      'service_business'
    end
    
    def create_data_sources
      # CRM System
      create_configured_data_source(
        name: "CRM System",
        source_type: "hubspot",
        configuration: {
          sync_type: "all",
          include_contacts: true,
          include_deals: true,
          include_tickets: true,
          include_activities: true
        }
      )
      
      # Project Management
      create_configured_data_source(
        name: "Project Management",
        source_type: "asana",
        configuration: {
          sync_type: "projects",
          include_tasks: true,
          include_time_tracking: true,
          include_milestones: true
        }
      )
      
      # Accounting
      create_configured_data_source(
        name: "Accounting",
        source_type: "quickbooks",
        configuration: {
          sync_type: "all",
          include_invoices: true,
          include_time_activities: true,
          include_expenses: true,
          include_payments: true
        }
      )
      
      # Calendar/Scheduling
      create_configured_data_source(
        name: "Scheduling",
        source_type: "calendly",
        configuration: {
          sync_type: "appointments",
          include_availability: true,
          include_cancellations: true,
          include_no_shows: true
        }
      )
      
      # Support Tickets
      create_configured_data_source(
        name: "Support System",
        source_type: "zendesk",
        configuration: {
          sync_type: "tickets",
          include_satisfaction: true,
          include_response_times: true,
          include_agent_performance: true
        }
      )
    end
    
    def create_pipelines
      # Service Delivery Pipeline
      create_etl_pipeline(
        name: "Service Delivery Analytics",
        description: "Track service delivery efficiency and quality",
        steps: [
          {
            name: "Extract Service Data",
            type: "extract",
            configuration: {
              sources: ["Project Management", "Scheduling", "Support System"],
              fields: ["project_id", "service_type", "start_time", "completion_time", "satisfaction_score"]
            }
          },
          {
            name: "Calculate Service Metrics",
            type: "transform",
            configuration: {
              calculations: {
                delivery_time: "completion_time - start_time",
                on_time_delivery: "completion_time <= deadline",
                utilization_rate: "billable_hours / available_hours",
                satisfaction_average: "avg(satisfaction_score)"
              },
              aggregations: {
                by_service_type: ["delivery_time", "satisfaction_average"],
                by_team_member: ["utilization_rate", "projects_completed"]
              }
            }
          },
          {
            name: "Identify Bottlenecks",
            type: "analyze",
            configuration: {
              bottleneck_detection: {
                overdue_projects: "completion_time > deadline",
                underutilized_resources: "utilization_rate < 0.6",
                quality_issues: "satisfaction_score < 4.0"
              }
            }
          }
        ]
      )
      
      # Revenue Recognition Pipeline
      create_etl_pipeline(
        name: "Revenue & Profitability",
        description: "Track revenue, costs, and profitability by project and client",
        steps: [
          {
            name: "Extract Financial Data",
            type: "extract",
            configuration: {
              sources: ["Accounting", "Project Management"],
              fields: ["invoice_amount", "hours_worked", "expenses", "project_id", "client_id"]
            }
          },
          {
            name: "Calculate Profitability",
            type: "transform",
            configuration: {
              calculations: {
                labor_cost: "hours_worked * hourly_rate",
                total_cost: "labor_cost + expenses",
                gross_profit: "invoice_amount - total_cost",
                profit_margin: "gross_profit / invoice_amount",
                effective_hourly_rate: "gross_profit / hours_worked"
              },
              segments: {
                high_value: "invoice_amount > 10000",
                profitable: "profit_margin > 0.4",
                at_risk: "profit_margin < 0.2"
              }
            }
          },
          {
            name: "Revenue Recognition",
            type: "accounting",
            configuration: {
              recognition_method: "percentage_of_completion",
              revenue_categories: ["consulting", "implementation", "support", "training"]
            }
          }
        ]
      )
      
      # Client Health Pipeline
      create_etl_pipeline(
        name: "Client Health Monitoring",
        description: "Monitor client engagement and satisfaction",
        steps: [
          {
            name: "Extract Client Data",
            type: "extract",
            configuration: {
              sources: ["CRM System", "Support System", "Accounting"],
              fields: ["client_id", "last_contact", "support_tickets", "payment_history", "nps_score"]
            }
          },
          {
            name: "Calculate Health Score",
            type: "transform",
            configuration: {
              health_factors: {
                engagement_score: "based_on(last_contact, meeting_frequency)",
                support_score: "based_on(ticket_volume, resolution_time)",
                payment_score: "based_on(on_time_payments, payment_delays)",
                satisfaction_score: "based_on(nps_score, support_ratings)"
              },
              overall_health: "weighted_average(all_scores)",
              risk_indicators: {
                churn_risk: "health_score < 0.6",
                expansion_opportunity: "health_score > 0.8 AND utilization < 0.5"
              }
            }
          },
          {
            name: "Generate Actions",
            type: "recommendations",
            configuration: {
              action_triggers: {
                schedule_check_in: "last_contact > 30 days",
                offer_training: "support_tickets > 5 per month",
                payment_follow_up: "overdue_payment > 0"
              }
            }
          }
        ]
      )
    end
    
    def configure_dashboards
      super
      
      # Service Operations Dashboard
      Dashboard.create!(
        organization: organization,
        name: "Service Operations",
        dashboard_type: "operations",
        configuration: {
          widgets: [
            {
              type: "metric",
              title: "Active Projects",
              metric: "active_project_count",
              format: "number",
              color_coding: {
                on_track: "green",
                at_risk: "yellow",
                overdue: "red"
              }
            },
            {
              type: "metric",
              title: "Team Utilization",
              metric: "team_utilization_rate",
              format: "percentage",
              target: 75,
              comparison: "last_week"
            },
            {
              type: "metric",
              title: "Client Satisfaction",
              metric: "average_csat",
              format: "decimal",
              target: 4.5,
              max: 5.0
            },
            {
              type: "metric",
              title: "Monthly Revenue",
              metric: "mrr",
              format: "currency",
              comparison: "last_month",
              trend: "sparkline"
            },
            {
              type: "gantt",
              title: "Project Timeline",
              data_source: "active_projects",
              group_by: "team_member"
            },
            {
              type: "chart",
              title: "Revenue by Service",
              chart_type: "donut",
              metric: "revenue_by_service_type"
            },
            {
              type: "table",
              title: "Client Health",
              data_source: "client_health_scores",
              columns: ["client", "health_score", "mrr", "last_contact", "action"],
              sortable: true,
              row_colors: {
                healthy: "green",
                warning: "yellow",
                at_risk: "red"
              }
            }
          ]
        }
      )
      
      # Resource Management Dashboard
      Dashboard.create!(
        organization: organization,
        name: "Resource Management",
        dashboard_type: "resources",
        configuration: {
          widgets: [
            {
              type: "heatmap",
              title: "Team Availability",
              x_axis: "team_member",
              y_axis: "week",
              metric: "utilization_percentage"
            },
            {
              type: "chart",
              title: "Billable vs Non-Billable",
              chart_type: "stacked_bar",
              metrics: ["billable_hours", "non_billable_hours"],
              group_by: "team_member"
            },
            {
              type: "table",
              title: "Project Profitability",
              data_source: "project_profitability",
              columns: ["project", "revenue", "cost", "margin", "hours"],
              highlight_negative: true
            }
          ]
        }
      )
    end
    
    def setup_automated_reports
      super
      
      # Daily team update via Slack/WhatsApp
      DeliveryPreference.create!(
        user: user,
        organization: organization,
        report_type: "daily_summary",
        channel: "whatsapp",
        format: "text",
        schedule: "daily",
        delivery_time: "08:30",
        timezone: user.timezone || "Eastern Time (US & Canada)",
        active: true,
        options: {
          content: [
            "projects_due_today",
            "team_availability",
            "pending_invoices",
            "support_ticket_summary",
            "client_meetings_today"
          ]
        }
      )
      
      # Weekly client report
      DeliveryPreference.create!(
        user: user,
        organization: organization,
        report_type: "weekly_report",
        channel: "email",
        format: "pdf",
        schedule: "weekly",
        delivery_time: "09:00",
        timezone: user.timezone || "Eastern Time (US & Canada)",
        active: true,
        options: {
          sections: [
            "project_status",
            "team_utilization",
            "financial_summary",
            "client_health",
            "upcoming_milestones"
          ],
          recipients: ["management", "project_managers"]
        }
      )
      
      # Monthly executive presentation
      DeliveryPreference.create!(
        user: user,
        organization: organization,
        report_type: "monthly_analysis",
        channel: "slides",
        format: "pptx",
        schedule: "monthly",
        delivery_time: "10:00",
        timezone: user.timezone || "Eastern Time (US & Canada)",
        active: true,
        options: {
          delivery_method: "email",
          template: "executive_summary",
          include_charts: true,
          sections: [
            "revenue_analysis",
            "profitability_trends",
            "client_portfolio",
            "team_performance",
            "growth_opportunities"
          ]
        }
      )
    end
    
    def create_sample_data
      # Sample clients
      clients = [
        { name: "Tech Innovators Inc", industry: "Technology", value: "high" },
        { name: "Green Energy Solutions", industry: "Energy", value: "medium" },
        { name: "Healthcare Partners", industry: "Healthcare", value: "high" },
        { name: "Retail Dynamics", industry: "Retail", value: "medium" },
        { name: "Financial Advisors LLC", industry: "Finance", value: "low" }
      ]
      
      # Sample team members
      team_members = ["Sarah Chen", "Mike Johnson", "Emily Davis", "Carlos Rodriguez"]
      
      # Sample services
      services = [
        { name: "Consulting", hourly_rate: 200, typical_hours: 40 },
        { name: "Implementation", hourly_rate: 150, typical_hours: 80 },
        { name: "Training", hourly_rate: 175, typical_hours: 16 },
        { name: "Support", hourly_rate: 125, typical_hours: 10 }
      ]
      
      # Generate 90 days of service business data
      90.days.ago.to_date.upto(Date.current) do |date|
        # Create 2-5 time entries per day
        rand(2..5).times do
          client = clients.sample
          team_member = team_members.sample
          service = services.sample
          hours = rand(1.0..8.0).round(1)
          
          # Time entry
          organization.raw_data_records.create!(
            source_type: "quickbooks",
            record_type: "time_activity",
            external_id: SecureRandom.uuid,
            data: {
              date: date,
              client_name: client[:name],
              team_member: team_member,
              service_type: service[:name],
              hours: hours,
              hourly_rate: service[:hourly_rate],
              billable: rand > 0.2, # 80% billable
              description: "#{service[:name]} services for #{client[:name]}",
              project_phase: ["Discovery", "Design", "Implementation", "Testing", "Deployment"].sample
            },
            recorded_at: date.to_time
          )
        end
        
        # Create project milestones (weekly)
        if date.wday == 1
          project = {
            client: clients.sample,
            name: ["Website Redesign", "System Integration", "Process Automation", "Data Migration"].sample,
            value: rand(15000..75000),
            duration_weeks: rand(4..16),
            team_lead: team_members.sample
          }
          
          organization.raw_data_records.create!(
            source_type: "asana",
            record_type: "project",
            external_id: SecureRandom.uuid,
            data: {
              project_name: "#{project[:name]} - #{project[:client][:name]}",
              client_name: project[:client][:name],
              project_value: project[:value],
              start_date: date,
              end_date: date + project[:duration_weeks].weeks,
              team_lead: project[:team_lead],
              status: ["Planning", "In Progress", "On Hold", "Completed"].sample,
              completion_percentage: rand(0..100),
              health_status: ["On Track", "At Risk", "Behind Schedule"].sample
            },
            recorded_at: date.to_time
          )
        end
        
        # Support tickets (0-3 per day)
        rand(0..3).times do
          ticket_client = clients.sample
          
          organization.raw_data_records.create!(
            source_type: "zendesk",
            record_type: "support_ticket",
            external_id: SecureRandom.uuid,
            data: {
              ticket_id: SecureRandom.hex(6),
              client_name: ticket_client[:name],
              subject: ["Login Issue", "Feature Request", "Bug Report", "Training Question", "Billing Inquiry"].sample,
              priority: ["Low", "Medium", "High", "Urgent"].sample,
              status: ["Open", "Pending", "Resolved", "Closed"].sample,
              created_at: date.to_time + rand(8..17).hours,
              response_time_hours: rand(0.5..4.0).round(1),
              resolution_time_hours: rand(2.0..24.0).round(1),
              satisfaction_rating: rand(3..5)
            },
            recorded_at: date.to_time
          )
        end
      end
      
      Rails.logger.info "Created sample service business data for #{organization.name}"
    end
  end
end