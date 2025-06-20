class LandingController < ApplicationController
  skip_before_action :authenticate_user!
  
  def index
    # Redirect authenticated users to dashboard
    if user_signed_in?
      redirect_to dashboard_path and return
    end
    
    # Landing page metrics for display
    @stats = {
      businesses_served: "10,000+",
      data_processed: "2.5B+",
      integrations: "25+",
      uptime: "99.99%"
    }
    
    # Customer testimonials
    @testimonials = [
      {
        name: "Sarah Chen",
        company: "TechStart Inc.",
        role: "CEO",
        quote: "DataReflow transformed how we understand our customers. Revenue increased 40% in 6 months.",
        rating: 5
      },
      {
        name: "Michael Rodriguez",
        company: "GrowthCorp",
        role: "VP of Operations", 
        quote: "The real-time insights helped us identify bottlenecks we never knew existed.",
        rating: 5
      },
      {
        name: "Emma Thompson",
        company: "ScaleUp Solutions",
        role: "Data Director",
        quote: "Setup took 15 minutes. Results were immediate. This is the future of business intelligence.",
        rating: 5
      }
    ]
    
    # Integration logos/names
    @integrations = [
      "Shopify", "QuickBooks", "Stripe", "Mailchimp", "Google Analytics",
      "HubSpot", "Zendesk", "Slack", "Microsoft Teams", "Salesforce"
    ]
  end
end