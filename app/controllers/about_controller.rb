class AboutController < ApplicationController
  skip_before_action :authenticate_user!

  def index
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
