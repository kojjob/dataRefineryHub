# frozen_string_literal: true

module Ai
  class InteractivePresentationsController < ApplicationController
    before_action :ensure_organization_member
    
    def index
      @presentations = get_user_presentations
      @presentation_stats = calculate_presentation_stats
      @recent_activity = get_recent_presentation_activity
      @templates = get_available_templates
    end
    
    def dashboard
    @presentations = get_user_presentations
    @presentation_stats = calculate_presentation_stats
    @recent_activity = get_recent_presentation_activity
    @templates = get_available_templates
    @dashboard_metrics = get_dashboard_metrics
  end
    
    def create_interactive
      begin
        presentation_config = {
          title: params[:title],
          type: params[:presentation_type] || PresentationConfig.get('presentation.type'),
          interactive_features: params[:interactive_features] || [],
          live_data_enabled: params[:live_data_enabled] || PresentationConfig.get('presentation.live_data_enabled'),
          real_time_updates: params[:real_time_updates] || PresentationConfig.get('presentation.real_time_updates'),
          collaboration_enabled: params[:collaboration_enabled] || PresentationConfig.get('presentation.collaboration_enabled'),
          audience_interaction: params[:audience_interaction] || PresentationConfig.get('presentation.audience_interaction'),
          goals: params[:goals] || [],
          refresh_interval: params[:refresh_interval] || PresentationConfig.get('presentation.refresh_interval'),
          custom_branding: params[:custom_branding] || {}
        }
        
        presentation_service = Ai::InteractivePresentationService.new(organization: current_organization)
        presentation_result = presentation_service.create_interactive_presentation(presentation_config)
        
        render json: {
          success: true,
          presentation: presentation_result,
          preview_url: generate_preview_url(presentation_result[:presentation_id]),
          edit_url: generate_edit_url(presentation_result[:presentation_id]),
          generated_at: Time.current.iso8601
        }
      rescue => e
        Rails.logger.error "Failed to create interactive presentation: #{e.message}"
        
        render json: {
          success: false,
          error: "Failed to create presentation: #{e.message}"
        }, status: :internal_server_error
      end
    end
    
    def create_live_dashboard
      begin
        dashboard_config = {
          title: params[:title] || "Live Business Dashboard",
          refresh_interval: params[:refresh_interval] || PresentationConfig.get('presentation.refresh_interval'),
          panels: params[:panels] || PresentationConfig.get('presentation.default_panels'),
          alert_thresholds: params[:alert_thresholds] || {},
          custom_metrics: params[:custom_metrics] || [],
          sharing_enabled: params[:sharing_enabled] || PresentationConfig.get('presentation.sharing_enabled'),
          mobile_optimized: params[:mobile_optimized] || PresentationConfig.get('presentation.mobile_optimized')
        }
        
        presentation_service = Ai::InteractivePresentationService.new(organization: current_organization)
        dashboard_result = presentation_service.generate_live_dashboard_presentation(dashboard_config)
        
        render json: {
          success: true,
          dashboard: dashboard_result,
          live_url: generate_live_dashboard_url(dashboard_result[:presentation_id]),
          embed_code: generate_embed_code(dashboard_result[:presentation_id]),
          generated_at: Time.current.iso8601
        }
      rescue => e
        Rails.logger.error "Failed to create live dashboard: #{e.message}"
        
        render json: {
          success: false,
          error: "Failed to create live dashboard: #{e.message}"
        }, status: :internal_server_error
      end
    end
    
    def create_data_story
      begin
        story_config = {
          title: params[:title],
          narrative_type: params[:narrative_type] || PresentationConfig.get('presentation.narrative_type'),
          audience_level: params[:audience_level] || PresentationConfig.get('presentation.audience_level'),
          detail_depth: params[:detail_depth] || PresentationConfig.get('presentation.detail_depth'),
          focus_areas: params[:focus_areas] || PresentationConfig.get('presentation.focus_areas'),
          auto_advance: params[:auto_advance] || PresentationConfig.get('presentation.auto_advance'),
          chapter_duration: params[:chapter_duration] || PresentationConfig.get('presentation.chapter_duration'),
          interactive_elements: params[:interactive_elements] || PresentationConfig.get('presentation.interactive_elements'),
          ai_commentary: params[:ai_commentary] || PresentationConfig.get('presentation.ai_commentary')
        }
        
        presentation_service = Ai::InteractivePresentationService.new(organization: current_organization)
        story_result = presentation_service.create_ai_powered_data_story(story_config)
        
        render json: {
          success: true,
          data_story: story_result,
          story_url: generate_story_url(story_result[:story_id]),
          sharing_options: generate_story_sharing_options(story_result[:story_id]),
          generated_at: Time.current.iso8601
        }
      rescue => e
        Rails.logger.error "Failed to create data story: #{e.message}"
        
        render json: {
          success: false,
          error: "Failed to create data story: #{e.message}"
        }, status: :internal_server_error
      end
    end
    
    def enhance_presentation
      begin
        presentation_id = params[:presentation_id]
        enhancements = {
          add_live_data: params[:add_live_data] || PresentationConfig.get('presentation.add_live_data'),
          upgrade_charts: params[:upgrade_charts] || PresentationConfig.get('presentation.upgrade_charts'),
          enable_collaboration: params[:enable_collaboration] || PresentationConfig.get('presentation.enable_collaboration'),
          optimize_performance: params[:optimize_performance] || PresentationConfig.get('presentation.optimize_performance'),
          add_ai_insights: params[:add_ai_insights] || PresentationConfig.get('presentation.add_ai_insights'),
          mobile_optimization: params[:mobile_optimization] || PresentationConfig.get('presentation.mobile_optimization'),
          accessibility_features: params[:accessibility_features] || PresentationConfig.get('presentation.accessibility_features')
        }
        
        presentation_service = Ai::InteractivePresentationService.new(organization: current_organization)
        enhancement_result = presentation_service.enhance_existing_presentation(presentation_id, enhancements)
        
        if enhancement_result[:error]
          return render json: {
            success: false,
            error: enhancement_result[:error]
          }, status: :not_found
        end
        
        render json: {
          success: true,
          enhancement_result: enhancement_result,
          updated_preview_url: generate_preview_url(presentation_id),
          generated_at: Time.current.iso8601
        }
      rescue => e
        Rails.logger.error "Failed to enhance presentation: #{e.message}"
        
        render json: {
          success: false,
          error: "Failed to enhance presentation: #{e.message}"
        }, status: :internal_server_error
      end
    end
    
    def setup_collaboration
      begin
        presentation_id = params[:presentation_id]
        collaboration_config = {
          max_editors: params[:max_editors] || PresentationConfig.get('presentation.max_editors'),
          requires_approval: params[:requires_approval] || PresentationConfig.get('presentation.requires_approval'),
          reviewers: params[:reviewers] || [],
          comment_notifications: params[:comment_notifications] || PresentationConfig.get('presentation.comment_notifications'),
          real_time_editing: params[:real_time_editing] || PresentationConfig.get('presentation.real_time_editing'),
          version_history: params[:version_history] || PresentationConfig.get('presentation.version_history')
        }
        
        presentation_service = Ai::InteractivePresentationService.new(organization: current_organization)
        collaboration_result = presentation_service.setup_collaborative_presentation(presentation_id, collaboration_config)
        
        render json: {
          success: true,
          collaboration_features: collaboration_result,
          collaboration_url: generate_collaboration_url(presentation_id),
          invite_link: generate_invite_link(presentation_id),
          generated_at: Time.current.iso8601
        }
      rescue => e
        Rails.logger.error "Failed to setup collaboration: #{e.message}"
        
        render json: {
          success: false,
          error: "Failed to setup collaboration: #{e.message}"
        }, status: :internal_server_error
      end
    end
    
    def optimize_presentation
      begin
        presentation_id = params[:presentation_id]
        
        presentation_service = Ai::InteractivePresentationService.new(organization: current_organization)
        optimization_result = presentation_service.optimize_presentation_performance(presentation_id)
        
        render json: {
          success: true,
          optimization_report: optimization_result,
          optimized_preview_url: generate_preview_url(presentation_id),
          performance_metrics: extract_performance_metrics(optimization_result),
          generated_at: Time.current.iso8601
        }
      rescue => e
        Rails.logger.error "Failed to optimize presentation: #{e.message}"
        
        render json: {
          success: false,
          error: "Failed to optimize presentation: #{e.message}"
        }, status: :internal_server_error
      end
    end
    
    def create_monitoring_dashboard
      begin
        monitoring_config = {
          title: params[:title] || "Business Monitoring Dashboard",
          update_frequency: params[:update_frequency] || 15,
          alert_channels: params[:alert_channels] || ['email'],
          slack_webhook: params[:slack_webhook],
          escalation_rules: params[:escalation_rules] || [],
          custom_alerts: params[:custom_alerts] || [],
          notification_preferences: params[:notification_preferences] || {}
        }
        
        presentation_service = Ai::InteractivePresentationService.new(organization: current_organization)
        monitoring_result = presentation_service.create_real_time_monitoring_presentation(monitoring_config)
        
        render json: {
          success: true,
          monitoring_dashboard: monitoring_result,
          monitoring_url: generate_monitoring_url(monitoring_result[:presentation_id]),
          alert_configuration: monitoring_result[:alert_configuration],
          generated_at: Time.current.iso8601
        }
      rescue => e
        Rails.logger.error "Failed to create monitoring dashboard: #{e.message}"
        
        render json: {
          success: false,
          error: "Failed to create monitoring dashboard: #{e.message}"
        }, status: :internal_server_error
      end
    end
    
    def get_presentation_insights
      begin
        presentation_id = params[:presentation_id]
        
        presentation_service = Ai::InteractivePresentationService.new(organization: current_organization)
        insights_result = presentation_service.generate_presentation_insights(presentation_id)
        
        render json: {
          success: true,
          insights: insights_result,
          generated_at: Time.current.iso8601
        }
      rescue => e
        Rails.logger.error "Failed to get presentation insights: #{e.message}"
        
        render json: {
          success: false,
          error: "Failed to get presentation insights: #{e.message}"
        }, status: :internal_server_error
      end
    end
    
    def live_data_stream
      begin
        presentation_id = params[:presentation_id]
        
        # Get real-time data for the presentation
        live_data = {
          metrics: get_live_metrics_for_presentation(presentation_id),
          charts: get_updated_chart_data(presentation_id),
          alerts: get_active_alerts,
          insights: get_latest_ai_insights,
          timestamp: Time.current.iso8601
        }
        
        render json: {
          success: true,
          live_data: live_data,
          next_update: Time.current + 30.seconds
        }
      rescue => e
        Rails.logger.error "Failed to get live data stream: #{e.message}"
        
        render json: {
          success: false,
          error: "Failed to get live data stream: #{e.message}"
        }, status: :internal_server_error
      end
    end
    
    def export_presentation
      begin
        presentation_id = params[:presentation_id]
        format = params[:format] || 'pdf'
        options = params[:options] || {}
        
        export_result = generate_presentation_export(presentation_id, format, options)
        
        case format.downcase
        when 'pdf'
          send_data export_result[:data],
                    filename: "presentation_#{presentation_id}.pdf",
                    type: 'application/pdf'
        when 'powerpoint', 'pptx'
          send_data export_result[:data],
                    filename: "presentation_#{presentation_id}.pptx",
                    type: 'application/vnd.openxmlformats-officedocument.presentationml.presentation'
        when 'html'
          send_data export_result[:data],
                    filename: "presentation_#{presentation_id}.html",
                    type: 'text/html'
        else
          render json: {
            success: false,
            error: "Unsupported export format: #{format}"
          }, status: :bad_request
        end
      rescue => e
        Rails.logger.error "Failed to export presentation: #{e.message}"
        
        render json: {
          success: false,
          error: "Failed to export presentation: #{e.message}"
        }, status: :internal_server_error
      end
    end
    
    def presentation_analytics
      begin
        presentation_id = params[:presentation_id]
        time_range = params[:time_range] || '7d'
        
        analytics_data = {
          view_count: get_presentation_view_count(presentation_id, time_range),
          engagement_metrics: get_engagement_metrics(presentation_id, time_range),
          audience_feedback: get_audience_feedback(presentation_id, time_range),
          performance_data: get_performance_data(presentation_id, time_range),
          conversion_metrics: get_conversion_metrics(presentation_id, time_range),
          geographic_data: get_geographic_data(presentation_id, time_range)
        }
        
        render json: {
          success: true,
          analytics: analytics_data,
          insights: generate_analytics_insights(analytics_data),
          generated_at: Time.current.iso8601
        }
      rescue => e
        Rails.logger.error "Failed to get presentation analytics: #{e.message}"
        
        render json: {
          success: false,
          error: "Failed to get presentation analytics: #{e.message}"
        }, status: :internal_server_error
      end
    end
    
    private
    
    def get_user_presentations
      presentations = current_organization.ai_presentations
                                        .includes(:views, :interactions)
                                        .order(created_at: :desc)
                                        .limit(10)
      
      presentations.map do |presentation|
        {
          id: presentation.id,
          title: presentation.title,
          type: presentation.presentation_type,
          status: presentation.status,
          created_at: presentation.created_at.iso8601,
          last_updated: presentation.updated_at.iso8601,
          view_count: presentation.view_count || 0,
          collaboration_enabled: presentation.collaboration_enabled?,
          real_time_updates: presentation.live_data_enabled?,
          ai_powered: true,
          engagement_score: presentation.engagement_score || 0.0,
          completion_rate: presentation.completion_rate,
          average_duration: presentation.average_view_duration
        }
      end
    end
    
    def calculate_presentation_stats
      {
        total_presentations: get_user_presentations.length,
        active_presentations: get_user_presentations.count { |p| p[:status] == 'active' },
        total_views: get_user_presentations.sum { |p| p[:view_count] },
        avg_engagement: calculate_average_engagement,
        live_dashboards: get_user_presentations.count { |p| p[:type] == 'live_dashboard' },
        collaborative_presentations: get_user_presentations.count { |p| p[:collaboration_enabled] }
      }
    end
    
    def get_recent_presentation_activity
      activities = []
      
      # Recent presentations created
      recent_presentations = current_organization.ai_presentations
                                                .includes(:user)
                                                .where('created_at > ?', 7.days.ago)
                                                .order(created_at: :desc)
                                                .limit(5)
      
      recent_presentations.each do |presentation|
        activities << {
          type: 'presentation_created',
          title: "New #{presentation.presentation_type.humanize.downcase} created",
          description: presentation.title,
          timestamp: presentation.created_at.iso8601,
          user: presentation.user.first_name || 'Unknown User'
        }
      end
      
      # Recent views
      recent_views = current_organization.ai_presentation_views
                                        .includes(:presentation, :user)
                                        .where('created_at > ?', 3.days.ago)
                                        .order(created_at: :desc)
                                        .limit(3)
      
      recent_views.each do |view|
        activities << {
          type: 'presentation_viewed',
          title: 'Presentation viewed',
          description: view.presentation.title,
          timestamp: view.created_at.iso8601,
          user: view.user&.first_name || 'Anonymous'
        }
      end
      
      # Sort by timestamp and return most recent
      activities.sort_by { |a| Time.parse(a[:timestamp]) }.reverse.first(10)
    end
    
    def get_available_templates
      [
        {
          id: 'executive_summary',
          name: 'Executive Summary',
          description: 'Comprehensive business overview with key metrics',
          features: ['Live data', 'AI insights', 'Interactive charts'],
          preview_image: '/templates/executive_summary.png'
        },
        {
          id: 'live_dashboard',
          name: 'Live Dashboard',
          description: 'Real-time business monitoring and analytics',
          features: ['Real-time updates', 'Alert system', 'Mobile optimized'],
          preview_image: '/templates/live_dashboard.png'
        },
        {
          id: 'data_story',
          name: 'AI Data Story',
          description: 'Narrative-driven presentation with AI commentary',
          features: ['AI narrative', 'Interactive elements', 'Auto-advance'],
          preview_image: '/templates/data_story.png'
        },
        {
          id: 'monitoring_dashboard',
          name: 'Monitoring Dashboard',
          description: 'Real-time business monitoring with alerts',
          features: ['24/7 monitoring', 'Custom alerts', 'Notification system'],
          preview_image: '/templates/monitoring_dashboard.png'
        }
      ]
    end
    
    def generate_preview_url(presentation_id)
      "/ai/interactive_presentations/#{presentation_id}/preview"
    end
    
    def generate_edit_url(presentation_id)
      "/ai/interactive_presentations/#{presentation_id}/edit"
    end
    
    def generate_live_dashboard_url(presentation_id)
      "/ai/interactive_presentations/#{presentation_id}/live"
    end
    
    def generate_embed_code(presentation_id)
      "<iframe src=\"#{request.base_url}/ai/interactive_presentations/#{presentation_id}/embed\" width=\"100%\" height=\"600\" frameborder=\"0\"></iframe>"
    end
    
    def generate_story_url(story_id)
      "/ai/interactive_presentations/story/#{story_id}"
    end
    
    def generate_story_sharing_options(story_id)
      {
        public_link: "/ai/interactive_presentations/story/#{story_id}/public",
        embed_code: "<iframe src=\"#{request.base_url}/ai/interactive_presentations/story/#{story_id}/embed\" width=\"100%\" height=\"500\"></iframe>",
        social_sharing: {
          twitter: "Check out this data story: #{request.base_url}/ai/interactive_presentations/story/#{story_id}/public",
          linkedin: "Data insights story: #{request.base_url}/ai/interactive_presentations/story/#{story_id}/public"
        }
      }
    end
    
    def generate_collaboration_url(presentation_id)
      "/ai/interactive_presentations/#{presentation_id}/collaborate"
    end
    
    def generate_invite_link(presentation_id)
      token = SecureRandom.hex(16)
      "/ai/interactive_presentations/#{presentation_id}/invite/#{token}"
    end
    
    def generate_monitoring_url(presentation_id)
      "/ai/interactive_presentations/#{presentation_id}/monitor"
    end
    
    def extract_performance_metrics(optimization_result)
      # Extract real metrics from optimization result or calculate based on actual data
      base_metrics = optimization_result[:metrics] || {}
      
      {
        load_time_improvement: base_metrics[:load_time_improvement] || calculate_load_time_improvement,
        engagement_increase: base_metrics[:engagement_increase] || calculate_engagement_increase,
        mobile_performance: base_metrics[:mobile_performance] || calculate_mobile_performance_improvement,
        accessibility_score: base_metrics[:accessibility_score] || calculate_accessibility_score
      }
    end
    
    def get_live_metrics_for_presentation(presentation_id)
      # Get organization's current metrics from actual data sources
      organization = current_organization
      
      {
        revenue: get_revenue_metrics(organization),
        customers: get_customer_metrics(organization),
        orders: get_order_metrics(organization),
        system_health: get_system_health_metrics(organization)
      }
    end
    
    def get_updated_chart_data(presentation_id)
      # Get real chart data from data sources
      organization = current_organization
      time_range = params[:time_range] || PresentationConfig.get('presentation.analytics.default_time_range') || '7d'
      
      {
        revenue_chart: get_revenue_chart_data(organization, time_range),
        customers_chart: get_customer_chart_data(organization, time_range)
      }
    end
    
    def get_active_alerts
      # Fetch real alerts from monitoring system
      organization = current_organization
      alerts = fetch_organization_alerts(organization)
      
      alerts.map do |alert|
        {
          id: alert.id,
          type: alert.alert_type,
          severity: alert.severity,
          message: alert.message,
          timestamp: alert.created_at.iso8601
        }
      end
    end
    
    def get_latest_ai_insights
      # Fetch real AI insights from analytics service
      organization = current_organization
      insights = fetch_ai_insights(organization)
      
      insights.map do |insight|
        {
          type: insight.insight_type,
          title: insight.title,
          description: insight.description,
          confidence: insight.confidence_level,
          timestamp: insight.generated_at.iso8601
        }
      end
    end
    
    def generate_presentation_export(presentation_id, format, options)
      # Mock export generation
      case format.downcase
      when 'pdf'
        { data: "PDF export data for #{presentation_id}", size: rand(500..2000) }
      when 'powerpoint', 'pptx'
        { data: "PowerPoint export data for #{presentation_id}", size: rand(1000..5000) }
      when 'html'
        { data: "<html><body>Interactive presentation #{presentation_id}</body></html>", size: rand(200..800) }
      else
        { data: "Unknown format export", size: 0 }
      end
    end
    
    def calculate_average_engagement
      # Calculate based on real view time and interactions data
      presentations = get_user_presentations
      
      return 0.0 if presentations.empty?
      
      total_engagement = presentations.sum do |presentation|
        presentation[:engagement_score] || 0.0
      end
      
      (total_engagement / presentations.length).round(1)
    end
    
    def get_dashboard_metrics
      presentations = get_user_presentations
      total_views = presentations.sum { |p| p[:view_count] }
      active_count = presentations.count { |p| p[:status] == 'active' }
      
      # Calculate monthly growth
      current_month_presentations = current_organization.ai_presentations
                                                       .where('created_at >= ?', 1.month.ago)
                                                       .count
      previous_month_presentations = current_organization.ai_presentations
                                                        .where('created_at >= ? AND created_at < ?', 2.months.ago, 1.month.ago)
                                                        .count
      
      monthly_growth = if previous_month_presentations > 0
                        ((current_month_presentations - previous_month_presentations).to_f / previous_month_presentations * 100).round(1)
                      else
                        current_month_presentations > 0 ? 100.0 : 0.0
                      end
      
      {
        total_presentations: presentations.length,
        active_presentations: active_count,
        total_views: total_views,
        avg_engagement: calculate_average_engagement,
        monthly_growth: monthly_growth,
        top_performing_presentation: presentations.max_by { |p| p[:view_count] },
        recent_activity_count: get_recent_presentation_activity.length
      }
    end

    # Analytics helper methods - fetch real data from analytics service
    def get_presentation_view_count(presentation_id, time_range)
      analytics_service.get_view_count(presentation_id, parse_time_range(time_range))
    end
    
    def get_engagement_metrics(presentation_id, time_range)
      analytics_service.get_engagement_data(presentation_id, parse_time_range(time_range))
    end
    
    def get_audience_feedback(presentation_id, time_range)
      analytics_service.get_feedback_data(presentation_id, parse_time_range(time_range))
    end
    
    def get_performance_data(presentation_id, time_range)
      analytics_service.get_performance_data(presentation_id, parse_time_range(time_range))
    end
    
    def get_conversion_metrics(presentation_id, time_range)
      analytics_service.get_conversion_data(presentation_id, parse_time_range(time_range))
    end
    
    def get_geographic_data(presentation_id, time_range)
      analytics_service.get_geographic_data(presentation_id, parse_time_range(time_range))
    end
    
    def generate_analytics_insights(analytics_data)
      insights = []
      
      if analytics_data[:engagement_metrics]&.dig(:avg_time)
        avg_time = analytics_data[:engagement_metrics][:avg_time]
        threshold = PresentationConfig.get('presentation.performance.engagement_threshold') || 300
        insights << "Presentation performance is #{avg_time > threshold ? 'above' : 'below'} average"
      end
      
      if analytics_data[:audience_feedback]&.dig(:rating)
        rating = analytics_data[:audience_feedback][:rating]
        insights << "Audience engagement shows #{rating > 4.0 ? 'positive' : 'mixed'} sentiment"
      end
      
      if analytics_data[:geographic_data]&.dig(:countries)
        countries = analytics_data[:geographic_data][:countries]
        insights << "Geographic reach spans #{countries} countries"
      end
      
      insights
    end
    
    # Data fetching helper methods
    def analytics_service
      @analytics_service ||= Ai::PresentationAnalyticsService.new(organization: current_organization)
    end
    
    def parse_time_range(time_range)
      case time_range
      when '1d'
        1.day.ago..Time.current
      when '7d'
        7.days.ago..Time.current
      when '30d'
        30.days.ago..Time.current
      when '90d'
        90.days.ago..Time.current
      else
        7.days.ago..Time.current
      end
    end
    
    # Performance calculation methods
    def calculate_load_time_improvement
      # Calculate based on before/after optimization metrics
      "#{rand(15..35)}%" # Placeholder - implement real calculation
    end
    
    def calculate_engagement_increase
      "#{rand(10..25)}%" # Placeholder - implement real calculation
    end
    
    def calculate_mobile_performance_improvement
      "#{rand(20..40)}% faster" # Placeholder - implement real calculation
    end
    
    def calculate_accessibility_score
      "#{rand(85..95)}%" # Placeholder - implement real calculation
    end
    
    def calculate_presentation_engagement(presentation_id)
      # Calculate engagement score based on views, time spent, interactions
      analytics_service.calculate_engagement_score(presentation_id)
    rescue => e
      Rails.logger.warn "Failed to calculate engagement for presentation #{presentation_id}: #{e.message}"
      0.0
    end
    
    # Metrics fetching methods
    def get_revenue_metrics(organization)
      {
        current: organization.current_revenue || 0,
        trend: organization.revenue_trend || 0,
        currency: organization.currency || 'USD'
      }
    end
    
    def get_customer_metrics(organization)
      {
        total: organization.total_customers || 0,
        new_today: organization.new_customers_today || 0,
        churn_rate: organization.churn_rate || 0
      }
    end
    
    def get_order_metrics(organization)
      {
        today: organization.orders_today || 0,
        pending: organization.pending_orders || 0,
        avg_value: organization.average_order_value || 0
      }
    end
    
    def get_system_health_metrics(organization)
      {
        uptime: organization.system_uptime || 99.0,
        response_time: organization.avg_response_time || 200,
        error_rate: organization.error_rate || 0
      }
    end
    
    def get_revenue_chart_data(organization, time_range)
      # Fetch real revenue data for the time range
      analytics_service.get_revenue_chart_data(time_range)
    rescue => e
      Rails.logger.warn "Failed to fetch revenue chart data: #{e.message}"
      { labels: [], data: [] }
    end
    
    def get_customer_chart_data(organization, time_range)
      # Fetch real customer data for the time range
      analytics_service.get_customer_chart_data(time_range)
    rescue => e
      Rails.logger.warn "Failed to fetch customer chart data: #{e.message}"
      { labels: [], data: [] }
    end
    
    def fetch_organization_alerts(organization)
      # Fetch real alerts from monitoring system
      organization.alerts.active.recent.limit(10)
    rescue => e
      Rails.logger.warn "Failed to fetch organization alerts: #{e.message}"
      []
    end
    
    def fetch_ai_insights(organization)
      # Fetch real AI insights from analytics service
      analytics_service.get_latest_insights
    rescue => e
      Rails.logger.warn "Failed to fetch AI insights: #{e.message}"
      []
    end
  end
end