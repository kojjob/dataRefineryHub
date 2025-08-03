# frozen_string_literal: true

class BusinessTemplatesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_organization_admin, except: [:index, :show]
  
  def index
    @templates = available_templates
    @applied_template = current_organization.applied_template
  end
  
  def show
    @template = find_template(params[:id])
    unless @template
      redirect_to business_templates_path, alert: "Template not found"
    end
  end
  
  def apply
    template_class = find_template_class(params[:id])
    
    unless template_class
      redirect_to business_templates_path, alert: "Template not found"
      return
    end
    
    # Check if a template has already been applied
    if current_organization.applied_template.present?
      redirect_to business_templates_path, 
                  alert: "A template has already been applied to this organization"
      return
    end
    
    # Apply the template
    template = template_class.new(
      organization: current_organization,
      user: current_user,
      options: template_params
    )
    
    if template.apply!
      redirect_to dashboard_path, 
                  notice: "#{params[:id].humanize} template applied successfully! Your dashboards and reports are ready."
    else
      redirect_to business_templates_path, 
                  alert: "Failed to apply template. Please try again or contact support."
    end
  end
  
  private
  
  def ensure_organization_admin
    unless current_user.organization_admin? || current_user.organization_owner?
      redirect_to business_templates_path, 
                  alert: "Only organization administrators can apply templates"
    end
  end
  
  def available_templates
    [
      {
        id: 'restaurant',
        name: 'Restaurant Business',
        description: 'Perfect for restaurants, cafes, and food service businesses',
        icon: '🍽️',
        features: [
          'POS system integration (Square, Toast)',
          'Daily sales and labor analysis',
          'Menu item performance tracking',
          'Table turnover optimization',
          'Inventory management'
        ],
        data_sources: ['Square/Toast POS', 'OpenTable', 'DoorDash', 'QuickBooks'],
        sample_insights: [
          'Identify your most profitable menu items',
          'Optimize staffing based on hourly sales',
          'Track food cost percentages in real-time',
          'Monitor table turnover rates'
        ]
      },
      {
        id: 'ecommerce',
        name: 'E-commerce Store',
        description: 'Comprehensive analytics for online retailers',
        icon: '🛒',
        features: [
          'Multi-channel sales tracking',
          'Customer lifetime value analysis',
          'Cart abandonment recovery',
          'Marketing ROI optimization',
          'Inventory forecasting'
        ],
        data_sources: ['Shopify/WooCommerce', 'Stripe', 'Google Analytics', 'Mailchimp', 'Google Ads'],
        sample_insights: [
          'Track conversion rates by traffic source',
          'Identify high-value customer segments',
          'Optimize marketing spend across channels',
          'Predict inventory needs'
        ]
      },
      {
        id: 'service_business',
        name: 'Service Business',
        description: 'Ideal for consultants, agencies, and professional services',
        icon: '💼',
        features: [
          'Project profitability tracking',
          'Team utilization monitoring',
          'Client health scoring',
          'Revenue recognition',
          'Resource planning'
        ],
        data_sources: ['HubSpot CRM', 'Asana/Monday', 'QuickBooks', 'Calendly', 'Zendesk'],
        sample_insights: [
          'Monitor project profitability in real-time',
          'Track team utilization and capacity',
          'Identify at-risk clients early',
          'Forecast revenue and cash flow'
        ]
      }
    ]
  end
  
  def find_template(id)
    available_templates.find { |t| t[:id] == id }
  end
  
  def find_template_class(id)
    case id
    when 'restaurant'
      BusinessTemplates::RestaurantTemplate
    when 'ecommerce'
      BusinessTemplates::EcommerceTemplate
    when 'service_business'
      BusinessTemplates::ServiceBusinessTemplate
    else
      nil
    end
  end
  
  def template_params
    params.permit(:include_sample_data)
  end
end