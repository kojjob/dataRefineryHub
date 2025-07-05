# frozen_string_literal: true

module Ai
  class PresentationGeneratorService
    include ActiveModel::Model

    attr_accessor :organization, :insights_data, :template_type, :output_format

    SUPPORTED_FORMATS = %w[pdf powerpoint html].freeze
    TEMPLATE_TYPES = %w[executive_summary quarterly_review monthly_report custom].freeze

    def initialize(organization:, insights_data: nil, template_type: "executive_summary", output_format: "pdf")
      @organization = organization
      @insights_data = insights_data || generate_insights_data
      @template_type = template_type
      @output_format = output_format
      @slides = []
    end

    def generate_presentation
      validate_inputs!

      # Build slides based on template type
      build_slides

      # Generate presentation in requested format
      case @output_format
      when "pdf"
        generate_pdf_presentation
      when "powerpoint"
        generate_powerpoint_presentation
      when "html"
        generate_html_presentation
      else
        raise ArgumentError, "Unsupported output format: #{@output_format}"
      end
    end

    def generate_slides_data
      {
        presentation_metadata: build_presentation_metadata,
        slides: @slides,
        generated_at: Time.current.iso8601,
        organization: @organization.name,
        template_type: @template_type,
        total_slides: @slides.count
      }
    end

    private

    def validate_inputs!
      raise ArgumentError, "Organization is required" unless @organization
      raise ArgumentError, "Invalid template type" unless TEMPLATE_TYPES.include?(@template_type)
      raise ArgumentError, "Invalid output format" unless SUPPORTED_FORMATS.include?(@output_format)
    end

    def generate_insights_data
      insights_service = Ai::InsightsEngineService.new(organization: @organization)
      insights_service.generate_insights
    end

    def build_slides
      case @template_type
      when "executive_summary"
        build_executive_summary_slides
      when "quarterly_review"
        build_quarterly_review_slides
      when "monthly_report"
        build_monthly_report_slides
      when "custom"
        build_custom_slides
      end
    end

    def build_executive_summary_slides
      # Title slide
      @slides << create_title_slide

      # Executive summary slide
      @slides << create_executive_summary_slide

      # Key metrics slide
      @slides << create_key_metrics_slide

      # Key insights slide
      @slides << create_key_insights_slide

      # Performance trends slide
      @slides << create_trends_slide

      # Recommendations slide
      @slides << create_recommendations_slide

      # Next steps slide
      @slides << create_next_steps_slide

      # Thank you slide
      @slides << create_closing_slide
    end

    def build_quarterly_review_slides
      @slides << create_title_slide
      @slides << create_quarterly_overview_slide
      @slides << create_financial_performance_slide
      @slides << create_customer_analytics_slide
      @slides << create_operational_performance_slide
      @slides << create_market_insights_slide
      @slides << create_challenges_opportunities_slide
      @slides << create_strategic_recommendations_slide
      @slides << create_roadmap_slide
      @slides << create_closing_slide
    end

    def build_monthly_report_slides
      @slides << create_title_slide
      @slides << create_monthly_summary_slide
      @slides << create_key_metrics_slide
      @slides << create_data_quality_slide
      @slides << create_trends_slide
      @slides << create_alerts_issues_slide
      @slides << create_recommendations_slide
      @slides << create_closing_slide
    end

    def build_custom_slides
      # Allow custom slide building based on insights data
      @slides << create_title_slide

      if @insights_data[:key_insights]&.any?
        @slides << create_key_insights_slide
      end

      if @insights_data[:anomalies]&.any?
        @slides << create_anomalies_slide
      end

      if @insights_data[:recommendations]&.any?
        @slides << create_recommendations_slide
      end

      @slides << create_closing_slide
    end

    # Slide creation methods

    def create_title_slide
      {
        slide_number: 1,
        type: "title",
        title: build_presentation_title,
        subtitle: "Data Intelligence Report",
        organization: @organization.name,
        date: Date.current.strftime("%B %d, %Y"),
        branding: {
          logo_url: nil, # Could be configured per organization
          primary_color: "#4F46E5", # Indigo
          secondary_color: "#10B981" # Emerald
        }
      }
    end

    def create_executive_summary_slide
      summary = @insights_data[:executive_summary] || {}

      {
        slide_number: 2,
        type: "executive_summary",
        title: "Executive Summary",
        content: {
          overview: generate_executive_overview,
          key_highlights: extract_executive_highlights(summary),
          performance_indicators: extract_performance_indicators(summary)
        },
        visual_elements: {
          chart_type: "dashboard_summary",
          data: build_summary_chart_data
        }
      }
    end

    def create_key_metrics_slide
      {
        slide_number: @slides.count + 1,
        type: "metrics",
        title: "Key Performance Metrics",
        content: {
          primary_metrics: build_primary_metrics,
          secondary_metrics: build_secondary_metrics,
          metric_comparisons: build_metric_comparisons
        },
        visual_elements: {
          chart_type: "metrics_dashboard",
          layout: "grid_2x2",
          data: build_metrics_chart_data
        }
      }
    end

    def create_key_insights_slide
      insights = @insights_data[:key_insights] || []

      {
        slide_number: @slides.count + 1,
        type: "insights",
        title: "Key Business Insights",
        content: {
          insights: insights.first(5).map { |insight| format_insight_for_slide(insight) },
          insight_categories: group_insights_by_category(insights)
        },
        visual_elements: {
          chart_type: "insight_highlights",
          data: build_insights_visual_data(insights)
        }
      }
    end

    def create_trends_slide
      trends = @insights_data[:trends] || {}

      {
        slide_number: @slides.count + 1,
        type: "trends",
        title: "Performance Trends & Patterns",
        content: {
          revenue_trends: format_trend_data(trends[:revenue_trends]),
          customer_trends: format_trend_data(trends[:customer_trends]),
          operational_trends: format_trend_data(trends[:growth_trajectory])
        },
        visual_elements: {
          chart_type: "multi_line_chart",
          data: build_trends_chart_data(trends)
        }
      }
    end

    def create_recommendations_slide
      recommendations = @insights_data[:recommendations] || []

      {
        slide_number: @slides.count + 1,
        type: "recommendations",
        title: "Strategic Recommendations",
        content: {
          priority_actions: recommendations.first(3).map { |rec| format_recommendation_for_slide(rec) },
          implementation_roadmap: build_implementation_roadmap(recommendations),
          expected_impact: calculate_recommendation_impact(recommendations)
        },
        visual_elements: {
          chart_type: "action_priority_matrix",
          data: build_recommendations_visual_data(recommendations)
        }
      }
    end

    def create_next_steps_slide
      {
        slide_number: @slides.count + 1,
        type: "next_steps",
        title: "Next Steps & Action Items",
        content: {
          immediate_actions: build_immediate_actions,
          short_term_goals: build_short_term_goals,
          long_term_objectives: build_long_term_objectives,
          success_metrics: build_success_metrics
        }
      }
    end

    def create_closing_slide
      {
        slide_number: @slides.count + 1,
        type: "closing",
        title: "Thank You",
        subtitle: "Questions & Discussion",
        content: {
          contact_info: build_contact_info,
          next_report_date: (Date.current + 1.month).strftime("%B %Y"),
          additional_resources: build_additional_resources
        }
      }
    end

    # Quarterly-specific slides

    def create_quarterly_overview_slide
      {
        slide_number: @slides.count + 1,
        type: "quarterly_overview",
        title: "Quarterly Performance Overview",
        content: {
          quarter: "Q#{(Date.current.month - 1) / 3 + 1} #{Date.current.year}",
          headline_metrics: build_quarterly_headlines,
          achievement_highlights: build_quarterly_achievements,
          challenge_areas: build_quarterly_challenges
        },
        visual_elements: {
          chart_type: "quarterly_scorecard",
          data: build_quarterly_chart_data
        }
      }
    end

    def create_financial_performance_slide
      {
        slide_number: @slides.count + 1,
        type: "financial_performance",
        title: "Financial Performance Analysis",
        content: {
          revenue_analysis: build_revenue_analysis,
          profitability_metrics: build_profitability_metrics,
          cost_analysis: build_cost_analysis,
          financial_health: assess_financial_health
        },
        visual_elements: {
          chart_type: "financial_dashboard",
          data: build_financial_chart_data
        }
      }
    end

    def create_customer_analytics_slide
      {
        slide_number: @slides.count + 1,
        type: "customer_analytics",
        title: "Customer Analytics & Insights",
        content: {
          customer_growth: build_customer_growth_analysis,
          segmentation_insights: build_customer_segmentation,
          retention_analysis: build_retention_analysis,
          satisfaction_metrics: build_satisfaction_metrics
        },
        visual_elements: {
          chart_type: "customer_dashboard",
          data: build_customer_chart_data
        }
      }
    end

    # Presentation generation methods

    def generate_pdf_presentation
      {
        format: "pdf",
        file_path: generate_pdf_file,
        download_url: build_download_url,
        slides_data: generate_slides_data,
        metadata: build_presentation_metadata
      }
    end

    def generate_powerpoint_presentation
      {
        format: "powerpoint",
        file_path: generate_pptx_file,
        download_url: build_download_url,
        slides_data: generate_slides_data,
        metadata: build_presentation_metadata
      }
    end

    def generate_html_presentation
      {
        format: "html",
        file_path: generate_html_file,
        view_url: build_view_url,
        slides_data: generate_slides_data,
        metadata: build_presentation_metadata
      }
    end

    # Helper methods

    def build_presentation_title
      case @template_type
      when "executive_summary"
        "Executive Business Intelligence Report"
      when "quarterly_review"
        "Quarterly Business Review - Q#{(Date.current.month - 1) / 3 + 1} #{Date.current.year}"
      when "monthly_report"
        "Monthly Data Intelligence Report - #{Date.current.strftime('%B %Y')}"
      else
        "Business Intelligence Report"
      end
    end

    def build_presentation_metadata
      {
        title: build_presentation_title,
        organization: @organization.name,
        template_type: @template_type,
        output_format: @output_format,
        generated_at: Time.current.iso8601,
        generated_by: "DataReflow AI",
        data_period: {
          start_date: 30.days.ago.strftime("%Y-%m-%d"),
          end_date: Date.current.strftime("%Y-%m-%d")
        },
        slides_count: @slides.count,
        version: "1.0"
      }
    end

    def generate_executive_overview
      summary = @insights_data[:executive_summary] || {}

      "Based on comprehensive analysis of your business data, this report presents key insights " \
      "and strategic recommendations to drive growth and operational excellence. " \
      "The analysis covers performance metrics, trend analysis, and actionable intelligence " \
      "to support data-driven decision making."
    end

    def extract_executive_highlights(summary)
      highlights = []

      if summary[:revenue_trend]
        highlights << "Revenue performance showing #{summary[:revenue_trend][:direction] || 'stable'} trajectory"
      end

      if summary[:customer_growth]
        highlights << "Customer base demonstrating #{summary[:customer_growth][:pattern] || 'steady'} growth patterns"
      end

      if summary[:operational_health]
        highlights << "Operational systems maintaining #{summary[:operational_health][:status] || 'healthy'} performance"
      end

      highlights.first(3)
    end

    def format_insight_for_slide(insight)
      {
        title: insight[:title],
        description: insight[:description],
        impact: insight[:impact_score],
        category: insight[:category],
        trend: insight[:trend],
        action_required: insight[:impact_score] > 7
      }
    end

    def format_recommendation_for_slide(recommendation)
      {
        title: recommendation[:title],
        description: recommendation[:description],
        priority: recommendation[:priority_score],
        expected_impact: recommendation[:expected_impact] || "Medium",
        timeline: recommendation[:timeline] || "30 days",
        resources_required: recommendation[:resources] || "Standard"
      }
    end

    # File generation placeholder methods
    # These would integrate with actual PDF/PowerPoint generation libraries

    def generate_pdf_file
      # Integration with libraries like Prawn, WickedPDF, or similar
      # Would generate actual PDF file and return file path
      file_path = "tmp/presentations/#{@organization.id}_#{Time.current.to_i}.pdf"
      Rails.logger.info "PDF generation would create file at: #{file_path}"
      file_path
    end

    def generate_pptx_file
      # Integration with libraries like RubyXL, OfficeKit, or PowerPoint APIs
      # Would generate actual PowerPoint file and return file path
      file_path = "tmp/presentations/#{@organization.id}_#{Time.current.to_i}.pptx"
      Rails.logger.info "PowerPoint generation would create file at: #{file_path}"
      file_path
    end

    def generate_html_file
      # Generate HTML presentation using templates
      file_path = "tmp/presentations/#{@organization.id}_#{Time.current.to_i}.html"
      Rails.logger.info "HTML generation would create file at: #{file_path}"
      file_path
    end

    def build_download_url
      # Generate secure download URL for the presentation file
      "#{Rails.application.routes.url_helpers.root_url}presentations/download/#{SecureRandom.hex(16)}"
    end

    def build_view_url
      # Generate URL for viewing HTML presentations
      "#{Rails.application.routes.url_helpers.root_url}presentations/view/#{SecureRandom.hex(16)}"
    end

    # Placeholder methods for data building
    # These would be implemented with actual business logic

    def build_primary_metrics; []; end
    def build_secondary_metrics; []; end
    def build_metric_comparisons; []; end
    def build_summary_chart_data; {}; end
    def build_metrics_chart_data; {}; end
    def build_insights_visual_data(insights); {}; end
    def build_trends_chart_data(trends); {}; end
    def build_recommendations_visual_data(recommendations); {}; end
    def group_insights_by_category(insights); {}; end
    def format_trend_data(trend_data); {}; end
    def build_implementation_roadmap(recommendations); []; end
    def calculate_recommendation_impact(recommendations); "High"; end
    def build_immediate_actions; []; end
    def build_short_term_goals; []; end
    def build_long_term_objectives; []; end
    def build_success_metrics; []; end
    def build_contact_info; {}; end
    def build_additional_resources; []; end
    def extract_performance_indicators(summary); []; end
    def build_quarterly_headlines; []; end
    def build_quarterly_achievements; []; end
    def build_quarterly_challenges; []; end
    def build_quarterly_chart_data; {}; end
    def build_revenue_analysis; {}; end
    def build_profitability_metrics; {}; end
    def build_cost_analysis; {}; end
    def assess_financial_health; "Healthy"; end
    def build_financial_chart_data; {}; end
    def build_customer_growth_analysis; {}; end
    def build_customer_segmentation; {}; end
    def build_retention_analysis; {}; end
    def build_satisfaction_metrics; {}; end
    def build_customer_chart_data; {}; end

    # Additional slide creation methods for quarterly/monthly templates
    def create_monthly_summary_slide; {}; end
    def create_data_quality_slide; {}; end
    def create_alerts_issues_slide; {}; end
    def create_anomalies_slide; {}; end
    def create_operational_performance_slide; {}; end
    def create_market_insights_slide; {}; end
    def create_challenges_opportunities_slide; {}; end
    def create_strategic_recommendations_slide; {}; end
    def create_roadmap_slide; {}; end
  end
end
