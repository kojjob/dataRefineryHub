class LandingController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    # Allow authenticated users to view landing page
    # They can navigate to dashboard via the navigation menu

    # Enhanced AI-focused metrics
    @stats = {
      ai_insights_generated: "50M+",
      anomalies_detected: "2.5M+",
      businesses_served: "10,000+",
      predictions_accuracy: "94.7%",
      data_processed: "2.5B+",
      uptime: "99.99%"
    }

    # AI-focused testimonials with specific technical benefits
    @testimonials = [
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

    # Enhanced integrations with AI capabilities
    @integrations = [
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

    # Live demo data for interactive elements
    @demo_data = generate_demo_data
    
    # AI features showcase
    @ai_features = [
      {
        title: "Autonomous Business Intelligence Agent",
        description: "AI agent that monitors your business 24/7, generates proactive insights, and alerts you to opportunities and risks before they impact your bottom line.",
        icon: "ai-brain",
        demo_available: true,
        benefits: ["Proactive Insights", "24/7 Monitoring", "Predictive Analytics", "Risk Assessment"]
      },
      {
        title: "Real-Time Anomaly Detection",
        description: "Advanced ML algorithms detect unusual patterns in your data instantly, preventing issues before they become problems.",
        icon: "anomaly-detection",
        demo_available: true,
        benefits: ["Instant Alerts", "Smart Thresholds", "Pattern Learning", "False Positive Reduction"]
      },
      {
        title: "Enhanced Data Intelligence",
        description: "AI automatically understands your business context, identifies data patterns, and suggests optimizations for maximum ROI.",
        icon: "data-intelligence",
        demo_available: true,
        benefits: ["Context Recognition", "Quality Scoring", "ROI Estimation", "Auto-Optimization"]
      }
    ]

    # Dynamic personalization based on referrer or user agent
    @personalization = detect_visitor_context
  end

  private

  def generate_demo_data
    {
      real_time_metrics: {
        revenue_rate: 1247,
        order_rate: 23,
        customer_activity: 156,
        system_health: 97.3
      },
      recent_insights: [
        {
          type: "opportunity",
          title: "Revenue Optimization Detected",
          description: "AI identified 15% revenue increase opportunity in mobile checkout flow",
          confidence: 92,
          impact: "$12,500/month"
        },
        {
          type: "anomaly",
          title: "Unusual Traffic Pattern",
          description: "30% spike in organic traffic from social media - investigate content strategy",
          confidence: 87,
          impact: "Monitor closely"
        },
        {
          type: "prediction",
          title: "Inventory Alert",
          description: "Best-selling product will be out of stock in 4 days based on current velocity",
          confidence: 94,
          impact: "Immediate action needed"
        }
      ],
      data_quality_preview: {
        overall_score: 87.4,
        business_fields_detected: 12,
        patterns_identified: 8,
        quality_insights: [
          "Customer data 98% complete",
          "Revenue tracking excellent",
          "3 missing data points identified"
        ]
      }
    }
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
