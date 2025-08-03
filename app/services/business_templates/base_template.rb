# frozen_string_literal: true

module BusinessTemplates
  class BaseTemplate
    include ActiveModel::Model
    
    attr_accessor :organization, :user, :options
    
    def initialize(organization:, user:, options: {})
      @organization = organization
      @user = user
      @options = options
    end
    
    # Apply template to organization
    def apply!
      ActiveRecord::Base.transaction do
        # Create data sources
        create_data_sources
        
        # Create ETL pipelines
        create_pipelines
        
        # Configure dashboards
        configure_dashboards
        
        # Set up automated reports
        setup_automated_reports
        
        # Configure AI insights
        configure_ai_insights
        
        # Create sample data if requested
        create_sample_data if options[:include_sample_data]
        
        # Mark template as applied
        organization.update!(
          applied_template: template_name,
          template_applied_at: Time.current
        )
        
        true
      end
    rescue => e
      Rails.logger.error "Failed to apply template: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      false
    end
    
    protected
    
    # Override in subclasses
    def template_name
      raise NotImplementedError
    end
    
    def create_data_sources
      raise NotImplementedError
    end
    
    def create_pipelines
      raise NotImplementedError
    end
    
    def configure_dashboards
      # Default dashboard configuration
      create_default_dashboards
    end
    
    def setup_automated_reports
      # Default report setup
      create_default_delivery_preferences
    end
    
    def configure_ai_insights
      # Default AI configuration
      enable_default_ai_features
    end
    
    def create_sample_data
      # Override in subclasses if sample data is needed
    end
    
    private
    
    def create_default_dashboards
      # Create revenue dashboard
      Dashboard.create!(
        organization: organization,
        name: "Revenue Overview",
        dashboard_type: "revenue",
        configuration: {
          widgets: [
            { type: "metric", title: "Today's Revenue", metric: "revenue_today" },
            { type: "metric", title: "Monthly Revenue", metric: "revenue_month" },
            { type: "chart", title: "Revenue Trend", chart_type: "line", metric: "revenue_daily" },
            { type: "table", title: "Top Products", data_source: "top_products" }
          ]
        }
      )
      
      # Create customer dashboard
      Dashboard.create!(
        organization: organization,
        name: "Customer Analytics",
        dashboard_type: "customers",
        configuration: {
          widgets: [
            { type: "metric", title: "Total Customers", metric: "total_customers" },
            { type: "metric", title: "New This Month", metric: "new_customers_month" },
            { type: "chart", title: "Customer Growth", chart_type: "area", metric: "customer_growth" },
            { type: "table", title: "Top Customers", data_source: "top_customers" }
          ]
        }
      )
    end
    
    def create_default_delivery_preferences
      # Daily summary via email
      DeliveryPreference.create!(
        user: user,
        organization: organization,
        report_type: "daily_summary",
        channel: "email",
        format: "html",
        schedule: "daily",
        delivery_time: "09:00",
        timezone: user.timezone || "Eastern Time (US & Canada)",
        active: true
      )
      
      # Weekly report via email with PDF
      DeliveryPreference.create!(
        user: user,
        organization: organization,
        report_type: "weekly_report",
        channel: "email",
        format: "pdf",
        schedule: "weekly",
        delivery_time: "09:00",
        timezone: user.timezone || "Eastern Time (US & Canada)",
        active: true
      )
      
      # Real-time alerts via WhatsApp (if configured)
      if organization.settings.dig('whatsapp', 'business_id').present?
        DeliveryPreference.create!(
          user: user,
          organization: organization,
          report_type: "real_time_alert",
          channel: "whatsapp",
          format: "text",
          schedule: "", # On-demand
          active: true
        )
      end
    end
    
    def enable_default_ai_features
      # Enable AI features
      organization.settings.merge!(
        ai_features: {
          predictive_analytics: true,
          automated_insights: true,
          anomaly_detection: true,
          natural_language_queries: true,
          smart_recommendations: true
        }
      )
      organization.save!
    end
    
    # Helper method to create a configured data source
    def create_configured_data_source(name:, source_type:, configuration:)
      DataSource.create!(
        organization: organization,
        name: name,
        source_type: source_type,
        configuration: configuration,
        sync_schedule: "0 */6 * * *", # Every 6 hours
        active: true
      )
    end
    
    # Helper method to create ETL pipeline
    def create_etl_pipeline(name:, description:, steps:)
      pipeline = organization.pipelines.create!(
        name: name,
        description: description,
        status: 'active',
        metadata: {
          created_by_template: template_name,
          created_at: Time.current
        }
      )
      
      # Create pipeline steps
      steps.each_with_index do |step_config, index|
        pipeline.pipeline_steps.create!(
          name: step_config[:name],
          step_type: step_config[:type],
          configuration: step_config[:configuration],
          position: index + 1
        )
      end
      
      pipeline
    end
  end
end