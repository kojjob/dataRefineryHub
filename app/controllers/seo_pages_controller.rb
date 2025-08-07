# frozen_string_literal: true

class SeoPagesController < ApplicationController
  before_action :set_seo_data
  
  # High-traffic landing pages for SEO
  
  def business_intelligence_platform
    @seo_data = {
      title: "Business Intelligence Platform | DataReflow - Transform Raw Data into Insights",
      description: "Powerful business intelligence platform for SMBs. Connect 100+ data sources, create real-time dashboards, and automate insights. Start your 14-day free trial today.",
      keywords: "business intelligence platform, BI software, data analytics platform, business analytics, dashboard software, data visualization tool",
      canonical_url: business_intelligence_platform_url,
      og_type: "product"
    }

    @hero_data = {
      headline: "The Business Intelligence Platform Built for Growing SMBs",
      subheadline: "Transform scattered business data into unified insights that drive growth. Connect all your tools, visualize trends, and make data-driven decisions in minutes.",
      cta_text: "Start Free 14-Day Trial",
      features: [
        "Connect 100+ data sources instantly",
        "Real-time automated dashboards",
        "AI-powered insights and alerts", 
        "Custom report builder",
        "Team collaboration tools",
        "Enterprise-grade security"
      ]
    }

    @testimonials = load_testimonials
    @case_studies = load_case_studies("business_intelligence")
    @faqs = load_bi_faqs
    
    render template: "seo_pages/business_intelligence_platform"
  end

  def etl_pipeline_tool
    @seo_data = {
      title: "ETL Pipeline Tool | DataReflow - No-Code Data Integration Platform",
      description: "Build robust ETL pipelines without coding. Extract, transform, and load data from any source to any destination. Visual pipeline builder with 100+ pre-built connectors.",
      keywords: "ETL tool, ETL pipeline, data integration platform, no-code ETL, data pipeline builder, extract transform load",
      canonical_url: etl_pipeline_tool_url,
      og_type: "product"
    }

    @hero_data = {
      headline: "Build Powerful ETL Pipelines Without Code",
      subheadline: "Visual drag-and-drop interface to extract, transform, and load data from any source. Pre-built connectors for 100+ popular tools and databases.",
      cta_text: "Build Your First Pipeline",
      features: [
        "Visual pipeline designer",
        "100+ pre-built connectors",
        "Real-time data validation",
        "Error handling & monitoring",
        "Scalable cloud infrastructure",
        "Version control & rollback"
      ]
    }

    @integrations = load_integrations
    @case_studies = load_case_studies("etl")
    @faqs = load_etl_faqs
    
    render template: "seo_pages/etl_pipeline_tool"
  end

  def data_analytics_dashboard
    @seo_data = {
      title: "Data Analytics Dashboard | DataReflow - Real-Time Business Insights",
      description: "Create stunning analytics dashboards in minutes. Real-time data visualization, custom KPIs, automated alerts. Perfect for SMBs seeking data-driven growth.",
      keywords: "analytics dashboard, data visualization, business dashboard, KPI dashboard, real-time analytics, data dashboard software",
      canonical_url: data_analytics_dashboard_url,
      og_type: "product"
    }

    @hero_data = {
      headline: "Beautiful Analytics Dashboards That Tell Your Data Story",
      subheadline: "Create professional dashboards in minutes, not weeks. Combine data from multiple sources into unified views that drive better decisions.",
      cta_text: "Create Your Dashboard",
      features: [
        "Drag-and-drop dashboard builder",
        "Real-time data updates",
        "Mobile-responsive design",
        "Custom KPI tracking",
        "Automated alert system",
        "White-label options"
      ]
    }

    @dashboard_examples = load_dashboard_examples
    @case_studies = load_case_studies("dashboards")
    @faqs = load_dashboard_faqs
    
    render template: "seo_pages/data_analytics_dashboard"
  end

  def small_business_analytics
    @seo_data = {
      title: "Small Business Analytics Software | DataReflow - Affordable BI Solution",
      description: "Analytics software designed for small businesses. Affordable, easy-to-use, and powerful. Connect your tools, track KPIs, and grow with confidence. Start free today.",
      keywords: "small business analytics, SMB analytics software, affordable business intelligence, small business BI, startup analytics platform",
      canonical_url: small_business_analytics_url,
      og_type: "product"
    }

    @hero_data = {
      headline: "Analytics Software Built for Small Business Success",
      subheadline: "Get enterprise-grade analytics at small business prices. Easy setup, powerful insights, and the support you need to grow your business with data.",
      cta_text: "Start Free Trial",
      features: [
        "Setup in under 15 minutes",
        "Affordable pricing from $29/month",
        "No technical skills required",
        "24/7 customer support",
        "Growth-focused KPIs",
        "Cancel anytime"
      ]
    }

    @pricing_comparison = load_pricing_comparison
    @success_stories = load_success_stories
    @faqs = load_smb_faqs
    
    render template: "seo_pages/small_business_analytics"
  end

  def data_integration_platform
    @seo_data = {
      title: "Data Integration Platform | DataReflow - Connect All Your Business Tools",
      description: "Unified data integration platform. Connect 100+ tools, sync data in real-time, and eliminate data silos. API-first architecture with robust security.",
      keywords: "data integration platform, data integration software, API integration, data connector, data synchronization, unified data platform",
      canonical_url: data_integration_platform_url,
      og_type: "product"
    }

    @hero_data = {
      headline: "One Platform to Connect All Your Business Data",
      subheadline: "Eliminate data silos with our comprehensive integration platform. Real-time sync, robust transformations, and enterprise security.",
      cta_text: "Explore Integrations",
      features: [
        "100+ native integrations",
        "Real-time data synchronization",
        "API-first architecture",
        "Custom connector builder",
        "Enterprise security & compliance",
        "Scalable cloud infrastructure"
      ]
    }

    @popular_integrations = load_popular_integrations
    @integration_categories = load_integration_categories
    @case_studies = load_case_studies("integration")
    @faqs = load_integration_faqs
    
    render template: "seo_pages/data_integration_platform"
  end

  private

  def set_seo_data
    @breadcrumbs = [
      { name: "Home", url: root_url },
      { name: "Solutions", url: "#" }
    ]
  end

  def load_testimonials
    [
      {
        text: "DataReflow transformed how we analyze customer data. ROI increased 40% in just 3 months.",
        author: "Sarah Chen",
        title: "VP of Analytics, TechStart Inc.",
        rating: 5
      },
      {
        text: "The ETL pipelines saved us 20 hours per week. Our team can focus on insights, not data prep.",
        author: "Michael Rodriguez",
        title: "Data Manager, GrowthCorp",
        rating: 5
      },
      {
        text: "Best business intelligence investment we've made. Easy to use, powerful insights.",
        author: "Jennifer Park",
        title: "CEO, MarketingPro",
        rating: 5
      }
    ]
  end

  def load_case_studies(category)
    case category
    when "business_intelligence"
      [
        {
          title: "How TechStart Increased Revenue 40% with Data-Driven Decisions",
          description: "Learn how TechStart used DataReflow's BI platform to identify growth opportunities and optimize their sales funnel.",
          image: "case-study-techstart.jpg",
          url: "/case-studies/techstart-revenue-growth",
          metrics: ["40% revenue increase", "60% faster reporting", "15 data sources unified"]
        }
      ]
    when "etl"
      [
        {
          title: "GrowthCorp Automated Data Processing with No-Code ETL",
          description: "Discover how GrowthCorp built robust data pipelines without a technical team.",
          image: "case-study-growthcorp.jpg", 
          url: "/case-studies/growthcorp-etl-automation",
          metrics: ["20 hours saved weekly", "99.9% pipeline uptime", "5 systems integrated"]
        }
      ]
    else
      []
    end
  end

  def load_bi_faqs
    [
      {
        question: "What is a business intelligence platform?",
        answer: "A business intelligence (BI) platform is software that helps organizations analyze data and make informed decisions. It connects to various data sources, processes the information, and presents insights through dashboards, reports, and visualizations."
      },
      {
        question: "How long does it take to set up DataReflow?",
        answer: "Most customers are up and running with their first dashboard in under 15 minutes. Our onboarding process guides you through connecting your data sources and creating your first visualizations step by step."
      },
      {
        question: "Can I connect my existing tools to DataReflow?",
        answer: "Yes! DataReflow supports 100+ integrations including popular tools like Shopify, Salesforce, Google Analytics, QuickBooks, HubSpot, and many more. We also provide APIs for custom integrations."
      },
      {
        question: "Is DataReflow suitable for small businesses?",
        answer: "Absolutely! DataReflow is designed with SMBs in mind. Our pricing starts at $29/month, and we provide the support and guidance small teams need to succeed with data analytics."
      },
      {
        question: "What kind of support do you offer?",
        answer: "We offer 24/7 customer support via email and chat, comprehensive documentation, video tutorials, and optional onboarding calls to help you get the most out of DataReflow."
      }
    ]
  end

  def load_etl_faqs
    [
      {
        question: "What does ETL stand for?",
        answer: "ETL stands for Extract, Transform, Load. It's a process of extracting data from source systems, transforming it into the desired format, and loading it into a destination system like a data warehouse or analytics platform."
      },
      {
        question: "Do I need coding skills to use DataReflow's ETL tool?",
        answer: "No coding required! DataReflow features a visual, drag-and-drop interface that makes building data pipelines as easy as connecting building blocks. Technical and non-technical users can both create powerful pipelines."
      }
    ]
  end

  def load_dashboard_faqs
    [
      {
        question: "Can I customize the dashboard design?",
        answer: "Yes! DataReflow offers extensive customization options including colors, fonts, layouts, and branding. You can create dashboards that match your company's style and requirements."
      }
    ]
  end

  def load_smb_faqs
    [
      {
        question: "What makes DataReflow different from other analytics platforms?",
        answer: "DataReflow is specifically designed for SMBs with affordable pricing, easy setup, and dedicated small business support. Unlike enterprise tools that are complex and expensive, we focus on what small businesses actually need."
      }
    ]
  end

  def load_integration_faqs
    [
      {
        question: "How secure are DataReflow's integrations?",
        answer: "Security is our top priority. All integrations use encrypted connections, OAuth authentication where available, and we're SOC 2 compliant. Your data is encrypted both in transit and at rest."
      }
    ]
  end

  # Additional helper methods for loading data...
  def load_integrations
    # Return array of integration categories and tools
    []
  end

  def load_dashboard_examples
    # Return array of dashboard examples with screenshots
    []
  end

  def load_pricing_comparison
    # Return pricing comparison with competitors
    {}
  end

  def load_success_stories
    # Return customer success stories
    []
  end

  def load_popular_integrations
    # Return most popular integrations
    []
  end

  def load_integration_categories
    # Return integration categories
    []
  end
end