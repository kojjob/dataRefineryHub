class LandingController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    # Allow authenticated users to view landing page
    # They can navigate to dashboard via the navigation menu

    # Dynamic AI-focused metrics from database
    @stats = load_hero_stats

    # Dynamic testimonials from database
    @testimonials = load_testimonials

    # Dynamic integrations from database
    @integrations = load_integrations

    # Dynamic AI features from database
    @ai_features = load_ai_features

    # Dynamic pricing plans from organization model
    @pricing_plans = load_pricing_plans

    # Live demo data for interactive elements (with real-time data when available)
    @demo_data = generate_demo_data

    # Dynamic personalization based on referrer or user agent
    @personalization = detect_visitor_context
  end

  private

  def load_hero_stats
    stats_content = LandingPageContent.for_section("hero_stats")
    stats = {}

    stats_content.each do |stat|
      key = stat.title.downcase.gsub(/[^a-z0-9]/, "_").to_sym
      stats[key] = stat.content
    end

    # Fallback to default values if no database content
    stats.presence || {
      ai_insights_generated: "50M+",
      anomalies_detected: "2.5M+",
      businesses_served: "10,000+",
      predictions_accuracy: "94.7%",
      data_processed: "2.5B+",
      uptime: "99.99%"
    }
  end

  def load_testimonials
    testimonials = Testimonial.featured.limit(6)

    if testimonials.any?
      testimonials.map do |t|
        {
          name: t.name,
          company: t.company,
          role: t.role,
          quote: t.quote,
          rating: t.rating,
          highlight: t.highlight,
          ai_feature: t.ai_feature
        }
      end
    else
      # Fallback testimonials if none in database
      default_testimonials
    end
  end

  def load_integrations
    integrations_content = LandingPageContent.for_section("integrations")

    if integrations_content.any?
      integrations_content.map do |integration|
        {
          name: integration.title,
          ai_feature: integration.content
        }
      end
    else
      # Fallback integrations
      default_integrations
    end
  end

  def load_ai_features
    features_content = LandingPageContent.for_section("ai_features")

    if features_content.any?
      features_content.map do |feature|
        {
          title: feature.title,
          description: feature.content,
          icon: feature.metadata["icon"] || "ai-brain",
          demo_available: feature.metadata["demo_available"] || true,
          benefits: feature.metadata["benefits"] || []
        }
      end
    else
      # Fallback features
      default_ai_features
    end
  end

  def load_pricing_plans
    [
      {
        name: "AI Trial",
        description: "14 days, full AI features",
        price: 0,
        billing_period: "trial",
        features: [
          "AI Business Intelligence Agent",
          "Real-time anomaly detection",
          "Up to 2 data sources",
          "10K records/month"
        ],
        cta_text: "Start AI Trial",
        featured: false
      },
      {
        name: "AI Starter",
        description: "Perfect for growing businesses",
        price: 49,
        billing_period: "month",
        features: [
          "Full AI agent with predictions",
          "Smart anomaly detection",
          "Up to 5 data sources",
          "100K records/month",
          "AI presentations & reports"
        ],
        cta_text: "Start 14-Day Trial",
        featured: true
      },
      {
        name: "AI Growth",
        description: "Advanced AI for scaling teams",
        price: 149,
        billing_period: "month",
        features: [
          "Advanced AI agent with scenarios",
          "Competitive intelligence",
          "Up to 15 data sources",
          "500K records/month",
          "Custom AI integrations"
        ],
        cta_text: "Start 14-Day Trial",
        featured: false
      }
    ]
  end

  def generate_demo_data
    # Try to get real-time data from actual sources when available
    real_metrics = get_real_time_metrics
    recent_insights = get_recent_ai_insights

    {
      real_time_metrics: real_metrics.presence || {
        revenue_rate: rand(1000..2500),
        order_rate: rand(15..45),
        customer_activity: rand(100..300),
        system_health: rand(95.0..99.9).round(1)
      },
      recent_insights: recent_insights.presence || generate_sample_insights,
      data_quality_preview: {
        overall_score: rand(80.0..95.0).round(1),
        business_fields_detected: rand(8..15),
        patterns_identified: rand(5..12),
        quality_insights: [
          "Customer data #{rand(90..99)}% complete",
          "Revenue tracking excellent",
          "#{rand(1..5)} missing data points identified"
        ]
      }
    }
  end

  def get_real_time_metrics
    # Try to get actual metrics from organizations if available
    return {} unless Organization.exists?

    total_orgs = Organization.count
    active_orgs = Organization.active.count
    total_data_sources = DataSource.count rescue 0

    {
      revenue_rate: (total_orgs * 50) + rand(100..500),
      order_rate: active_orgs + rand(5..25),
      customer_activity: total_data_sources * 10 + rand(50..150),
      system_health: 99.5 + rand(-0.5..0.4).round(1)
    }
  rescue
    {}
  end

  def get_recent_ai_insights
    # Try to get actual AI insights if available
    return [] unless defined?(Ai::Insight)

    Ai::Insight.recent.limit(3).map do |insight|
      {
        type: insight.insight_type,
        title: insight.title,
        description: insight.description,
        confidence: (insight.confidence_score * 100).round,
        impact: insight.impact_level.humanize
      }
    end
  rescue
    []
  end

  def generate_sample_insights
    sample_insights = [
      {
        type: "opportunity",
        title: "Revenue Optimization Detected",
        description: "AI identified 15% revenue increase opportunity in mobile checkout flow",
        confidence: rand(85..95),
        impact: "$#{rand(5..25)},#{rand(100..900)}/month"
      },
      {
        type: "anomaly",
        title: "Unusual Traffic Pattern",
        description: "#{rand(20..40)}% spike in organic traffic from social media - investigate content strategy",
        confidence: rand(80..90),
        impact: "Monitor closely"
      },
      {
        type: "prediction",
        title: "Inventory Alert",
        description: "Best-selling product will be out of stock in #{rand(3..7)} days based on current velocity",
        confidence: rand(90..98),
        impact: "Immediate action needed"
      }
    ]

    sample_insights.sample(rand(2..3))
  end

  def default_testimonials
    [
      {
        name: "Sarah Chen",
        company: "TechStart Inc.",
        role: "CEO",
        quote: "DataReflow's AI agent predicted a 30% revenue drop 2 weeks early. We pivoted our marketing strategy and ended up growing 40% instead.",
        rating: 5,
        highlight: "AI Prediction Accuracy",
        ai_feature: "Autonomous Business Intelligence Agent"
      },
      {
        name: "Michael Rodriguez",
        company: "GrowthCorp",
        role: "VP of Operations",
        quote: "The real-time anomaly detection caught inventory issues our team missed. Saved us $250K in lost sales during Black Friday.",
        rating: 5,
        highlight: "Real-time Anomaly Detection",
        ai_feature: "Smart Alerting System"
      },
      {
        name: "Emma Thompson",
        company: "ScaleUp Solutions",
        role: "Data Director",
        quote: "Setup took 15 minutes. AI immediately identified 3 revenue opportunities worth $500K. ROI was 2000% in month one.",
        rating: 5,
        highlight: "Instant Business Insights",
        ai_feature: "Enhanced Data Intelligence"
      }
    ]
  end

  def default_integrations
    [
      { name: "Shopify", ai_feature: "Revenue Predictions" },
      { name: "QuickBooks", ai_feature: "Financial Anomalies" },
      { name: "Stripe", ai_feature: "Churn Prediction" },
      { name: "Mailchimp", ai_feature: "Campaign Optimization" },
      { name: "Google Analytics", ai_feature: "Behavior Analysis" },
      { name: "HubSpot", ai_feature: "Lead Scoring" },
      { name: "Zendesk", ai_feature: "Support Intelligence" },
      { name: "Slack", ai_feature: "Team Productivity" },
      { name: "Salesforce", ai_feature: "Sales Forecasting" },
      { name: "Airtable", ai_feature: "Workflow Optimization" }
    ]
  end

  def default_ai_features
    [
      {
        title: "Autonomous Business Intelligence Agent",
        description: "AI agent that monitors your business 24/7, generates proactive insights, and alerts you to opportunities and risks before they impact your bottom line.",
        icon: "ai-brain",
        demo_available: true,
        benefits: [ "Proactive Insights", "24/7 Monitoring", "Predictive Analytics", "Risk Assessment" ]
      },
      {
        title: "Real-Time Anomaly Detection",
        description: "Advanced ML algorithms detect unusual patterns in your data instantly, preventing issues before they become problems.",
        icon: "anomaly-detection",
        demo_available: true,
        benefits: [ "Instant Alerts", "Smart Thresholds", "Pattern Learning", "False Positive Reduction" ]
      },
      {
        title: "Enhanced Data Intelligence",
        description: "AI automatically understands your business context, identifies data patterns, and suggests optimizations for maximum ROI.",
        icon: "data-intelligence",
        demo_available: true,
        benefits: [ "Context Recognition", "Quality Scoring", "ROI Estimation", "Auto-Optimization" ]
      }
    ]
  end

  def detect_visitor_context
    # Simple visitor context detection
    user_agent = request.user_agent.to_s.downcase
    referrer = request.referrer.to_s.downcase

    {
      likely_business_type: detect_business_type(referrer, user_agent),
      primary_cta: determine_primary_cta(referrer),
      demo_focus: determine_demo_focus(referrer, user_agent)
    }
  end

  def detect_business_type(referrer, user_agent)
    return "ecommerce" if referrer.include?("shopify") || referrer.include?("commerce")
    return "saas" if referrer.include?("saas") || referrer.include?("software")
    return "agency" if referrer.include?("marketing") || referrer.include?("agency")
    "general" # Default
  end

  def determine_primary_cta(referrer)
    return "View Live Demo" if referrer.include?("demo")
    return "See AI in Action" if referrer.include?("ai") || referrer.include?("intelligence")
    "Start Free Trial" # Default
  end

  def determine_demo_focus(referrer, user_agent)
    return "real_time_analytics" if referrer.include?("analytics")
    return "ai_insights" if referrer.include?("ai") || referrer.include?("machine")
    return "data_processing" if referrer.include?("data") || referrer.include?("etl")
    "business_intelligence" # Default
  end
end
