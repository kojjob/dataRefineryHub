class LandingController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    # Allow authenticated users to view landing page
    # They can navigate to dashboard via the navigation menu

    # Landing page metrics for display
    @stats = {
      businesses_served: "10,000+",
      data_processed: "2.5B+",
      integrations: "25+",
      uptime: "99.99%"
    }

    # Enhanced customer testimonials with AI focus
    @testimonials = [
      {
        name: "Sarah Miller",
        company: "GreenTech Solutions",
        role: "CEO",
        quote: "DataReflow's AI caught a 30% drop in repeat customers that our team missed completely. The automated alert helped us adjust our retention strategy and save $50K in revenue.",
        rating: 5,
        metrics: { saved_revenue: "$50K", time_to_insight: "2 hours", ai_accuracy: "94%" },
        category: "ai_insights",
        company_size: "50-200 employees",
        industry: "E-commerce"
      },
      {
        name: "Marcus Rodriguez",
        company: "FreshMart",
        role: "Operations Director",
        quote: "The real-time dashboard is a game-changer. I can see inventory levels, sales, and customer activity updating live. We prevented 3 stockouts last month alone.",
        rating: 5,
        metrics: { stockouts_prevented: "3", response_time: "< 5 minutes", efficiency_gain: "+35%" },
        category: "real_time",
        company_size: "200-500 employees",
        industry: "Retail"
      },
      {
        name: "David Kim",
        company: "DigitalCraft Agency",
        role: "Founder",
        quote: "Connected all 8 of our tools in under 10 minutes. No technical team needed. The natural language queries mean anyone on our team can get insights instantly.",
        rating: 5,
        metrics: { setup_time: "10 minutes", integrations: "8 tools", team_adoption: "100%" },
        category: "integrations",
        company_size: "10-50 employees",
        industry: "Marketing Agency"
      },
      {
        name: "Dr. Lisa Chen",
        company: "MedTech Innovations",
        role: "Chief Data Officer",
        quote: "The AI predictions helped us identify supply chain disruptions 2 weeks before they happened. We saved $200K in emergency procurement costs.",
        rating: 5,
        metrics: { prediction_accuracy: "96%", cost_savings: "$200K", early_warning: "14 days" },
        category: "ai_predictions",
        company_size: "500+ employees",
        industry: "Healthcare"
      },
      {
        name: "James Wilson",
        company: "TechFlow Dynamics",
        role: "VP of Analytics",
        quote: "From 25+ data sources to unified insights in real-time. Our decision-making speed increased by 60% and we're catching opportunities our competitors miss.",
        rating: 5,
        metrics: { data_sources: "25+", decision_speed: "+60%", revenue_impact: "+$1.2M" },
        category: "unified_analytics",
        company_size: "200-500 employees",
        industry: "SaaS"
      },
      {
        name: "Amanda Foster",
        company: "RetailMax",
        role: "Head of Business Intelligence",
        quote: "The automated reporting freed up 15 hours per week for my team. We now focus on strategy instead of data preparation. ROI was 400% in the first quarter.",
        rating: 5,
        metrics: { time_saved: "15 hrs/week", roi: "400%", automation_rate: "85%" },
        category: "automation",
        company_size: "1000+ employees",
        industry: "Retail"
      }
    ]

    # Trust indicators and social proof
    @trust_indicators = {
      customers_count: "10,000+",
      data_processed: "2.5B+",
      uptime: "99.99%",
      integrations_available: "25+",
      avg_setup_time: "< 15 minutes",
      customer_satisfaction: "4.9/5",
      enterprise_clients: "500+",
      countries: "45+"
    }

    # Expanded integration ecosystem - 25+ connectors
    @integrations = {
      ecommerce: [
        { name: "Shopify", status: "live", popular: true },
        { name: "WooCommerce", status: "live", popular: true },
        { name: "Magento", status: "live", popular: false },
        { name: "BigCommerce", status: "live", popular: false },
        { name: "Squarespace", status: "live", popular: false },
        { name: "Etsy", status: "beta", popular: false },
        { name: "Amazon Seller", status: "coming_soon", popular: true }
      ],
      accounting: [
        { name: "QuickBooks", status: "live", popular: true },
        { name: "Xero", status: "live", popular: true },
        { name: "Stripe", status: "live", popular: true },
        { name: "PayPal", status: "live", popular: false },
        { name: "Square", status: "live", popular: false },
        { name: "FreshBooks", status: "beta", popular: false }
      ],
      marketing: [
        { name: "HubSpot", status: "live", popular: true },
        { name: "Mailchimp", status: "live", popular: true },
        { name: "Salesforce", status: "live", popular: true },
        { name: "ActiveCampaign", status: "live", popular: false },
        { name: "Klaviyo", status: "live", popular: false },
        { name: "ConvertKit", status: "beta", popular: false },
        { name: "Pipedrive", status: "live", popular: false }
      ],
      analytics: [
        { name: "Google Analytics", status: "live", popular: true },
        { name: "Facebook Ads", status: "live", popular: true },
        { name: "Google Ads", status: "live", popular: true },
        { name: "LinkedIn Ads", status: "live", popular: false },
        { name: "TikTok Ads", status: "beta", popular: false },
        { name: "Mixpanel", status: "live", popular: false }
      ],
      productivity: [
        { name: "Slack", status: "live", popular: true },
        { name: "Microsoft Teams", status: "live", popular: true },
        { name: "Zendesk", status: "live", popular: false },
        { name: "Intercom", status: "live", popular: false },
        { name: "Notion", status: "beta", popular: false }
      ]
    }

    # Integration statistics
    @integration_stats = {
      total_count: @integrations.values.flatten.count,
      live_count: @integrations.values.flatten.count { |i| i[:status] == "live" },
      beta_count: @integrations.values.flatten.count { |i| i[:status] == "beta" },
      coming_soon_count: @integrations.values.flatten.count { |i| i[:status] == "coming_soon" }
    }

    # Modern pricing tiers with AI-powered features
    @pricing_tiers = [
      {
        name: "Starter",
        price: 79,
        billing_period: "per month",
        description: "Perfect for small teams getting started with AI-powered analytics",
        target_audience: "Small teams (1-10 users)",
        features: [
          "Up to 5 data sources",
          "AI-powered insights & alerts",
          "Real-time dashboard",
          "Natural language queries",
          "5GB data storage",
          "Email support",
          "Basic anomaly detection",
          "Standard integrations"
        ],
        limits: {
          data_sources: "5",
          users: "10",
          storage: "5GB",
          ai_queries: "1,000/month"
        },
        cta: "Start 14-Day Free Trial",
        popular: false,
        savings: nil
      },
      {
        name: "Professional",
        price: 199,
        billing_period: "per month",
        description: "Advanced AI analytics for growing businesses",
        target_audience: "Growing teams (10-50 users)",
        features: [
          "Up to 25 data sources",
          "Advanced AI predictions",
          "Custom dashboards & reports",
          "Real-time collaboration",
          "50GB data storage",
          "Priority support",
          "Advanced anomaly detection",
          "Predictive analytics",
          "Custom alerts & workflows",
          "API access",
          "Advanced integrations"
        ],
        limits: {
          data_sources: "25",
          users: "50",
          storage: "50GB",
          ai_queries: "10,000/month"
        },
        cta: "Start 14-Day Free Trial",
        popular: true,
        savings: "Save 20% vs Starter per user"
      },
      {
        name: "Enterprise",
        price: "Custom",
        billing_period: "contact for pricing",
        description: "Full-scale AI platform for large organizations",
        target_audience: "Large organizations (50+ users)",
        features: [
          "Unlimited data sources",
          "Custom AI models & training",
          "White-label solution",
          "Advanced security & compliance",
          "Unlimited storage",
          "Dedicated success manager",
          "24/7 phone support",
          "Custom integrations",
          "On-premise deployment",
          "Advanced user management",
          "SLA guarantees",
          "Custom reporting"
        ],
        limits: {
          data_sources: "Unlimited",
          users: "Unlimited",
          storage: "Unlimited",
          ai_queries: "Unlimited"
        },
        cta: "Contact Sales",
        popular: false,
        savings: "Volume discounts available"
      }
    ]

    # Feature comparison matrix
    @feature_comparison = {
      "Data Sources" => {
        starter: "5 sources",
        professional: "25 sources",
        enterprise: "Unlimited"
      },
      "AI-Powered Insights" => {
        starter: "Basic insights",
        professional: "Advanced predictions",
        enterprise: "Custom AI models"
      },
      "Real-Time Analytics" => {
        starter: "✓",
        professional: "✓",
        enterprise: "✓"
      },
      "Natural Language Queries" => {
        starter: "✓",
        professional: "✓",
        enterprise: "✓"
      },
      "Anomaly Detection" => {
        starter: "Basic",
        professional: "Advanced",
        enterprise: "Custom algorithms"
      },
      "Custom Dashboards" => {
        starter: "Templates only",
        professional: "Full customization",
        enterprise: "White-label"
      },
      "API Access" => {
        starter: "—",
        professional: "✓",
        enterprise: "✓ + Custom"
      },
      "Support" => {
        starter: "Email",
        professional: "Priority email",
        enterprise: "24/7 phone + dedicated manager"
      }
    }
  end

  def about
    # Company information
    @company_info = {
      founded: "2020",
      headquarters: "San Francisco, CA",
      employees: "50-100",
      mission: "To democratize enterprise-grade analytics, making powerful data insights accessible to businesses of all sizes.",
      vision: "A world where every business, regardless of size, can harness the power of their data to make informed decisions and drive growth."
    }

    # Leadership team
    @leadership_team = [
      {
        name: "Sarah Johnson",
        role: "CEO & Co-Founder",
        bio: "Former VP of Analytics at Salesforce with 15+ years in enterprise data solutions. Led data transformation initiatives for Fortune 500 companies.",
        image: "https://images.unsplash.com/photo-1494790108755-2616b612b786?w=400&h=400&fit=crop&crop=face",
        linkedin: "#"
      },
      {
        name: "Michael Chen",
        role: "CTO & Co-Founder",
        bio: "Ex-Google engineer who built machine learning systems at scale. PhD in Computer Science from Stanford, specializing in AI and data processing.",
        image: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=400&h=400&fit=crop&crop=face",
        linkedin: "#"
      },
      {
        name: "Dr. Emily Rodriguez",
        role: "Head of AI Research",
        bio: "Former Principal Data Scientist at Microsoft. Published researcher in machine learning with 20+ papers in top-tier conferences.",
        image: "https://images.unsplash.com/photo-1580489944761-15a19d654956?w=400&h=400&fit=crop&crop=face",
        linkedin: "#"
      },
      {
        name: "David Kim",
        role: "VP of Customer Success",
        bio: "15+ years helping businesses transform through technology. Previously led customer success teams at HubSpot and Zendesk.",
        image: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&h=400&fit=crop&crop=face",
        linkedin: "#"
      }
    ]

    # Company milestones
    @milestones = [
      {
        year: "2020",
        title: "Company Founded",
        description: "Started with a vision to make enterprise analytics accessible to SMEs"
      },
      {
        year: "2021",
        title: "First 100 Customers",
        description: "Reached our first major milestone with businesses across 5 industries"
      },
      {
        year: "2022",
        title: "AI Platform Launch",
        description: "Launched our proprietary AI engine for automated insights and predictions"
      },
      {
        year: "2023",
        title: "Series A Funding",
        description: "Raised $15M to accelerate product development and market expansion"
      },
      {
        year: "2024",
        title: "10,000+ Customers",
        description: "Serving businesses in 45+ countries with 99.99% uptime"
      }
    ]

    # Company values
    @values = [
      {
        title: "Data Democracy",
        description: "We believe every business deserves access to enterprise-grade analytics, regardless of size or technical expertise.",
        icon: "users"
      },
      {
        title: "AI for Good",
        description: "Our AI solutions are designed to augment human decision-making, not replace it. We prioritize transparency and explainability.",
        icon: "brain"
      },
      {
        title: "Customer Success",
        description: "Your success is our success. We're committed to helping you achieve measurable ROI from day one.",
        icon: "target"
      },
      {
        title: "Innovation",
        description: "We continuously push the boundaries of what's possible with data analytics and AI technology.",
        icon: "lightbulb"
      }
    ]

    # Awards and recognition
    @awards = [
      {
        title: "Best AI Analytics Platform 2024",
        organization: "TechCrunch Disrupt",
        year: "2024"
      },
      {
        title: "Top 50 SaaS Companies to Watch",
        organization: "Forbes",
        year: "2023"
      },
      {
        title: "Innovation Award - Data Analytics",
        organization: "Gartner",
        year: "2023"
      },
      {
        title: "Customer Choice Award",
        organization: "G2 Crowd",
        year: "2024"
      }
    ]

    # Statistics
    @stats = {
      customers: "10,000+",
      countries: "45+",
      data_processed: "2.5B+",
      uptime: "99.99%",
      avg_roi: "340%",
      support_rating: "4.9/5"
    }
  end
end
