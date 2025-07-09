class IndustryTemplatesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_template, only: [:show, :apply]

  def index
    @templates = IndustryTemplate.all_templates
  end

  def show
    @template_config = @template[:config]
    @preview_data = generate_preview_data(@template)
  end

  def apply
    current_user.update(dashboard_template: @template[:id])
    
    # Apply template configuration to user's dashboard
    apply_template_to_dashboard(@template)
    
    redirect_to dashboard_path, notice: "#{@template[:name]} template applied successfully!"
  end

  def reset
    current_user.update(dashboard_template: nil)
    redirect_to dashboard_path, notice: "Dashboard reset to default layout."
  end

  private

  def set_template
    @template = IndustryTemplate.find_template(params[:id])
    redirect_to industry_templates_path, alert: "Template not found." unless @template
  end

  def apply_template_to_dashboard(template)
    # Store template configuration in user preferences or session
    session[:dashboard_config] = template[:config]
  end

  def generate_preview_data(template)
    # Generate sample data for template preview
    case template[:id]
    when 'retail_ecommerce'
      {
        total_revenue: 125000,
        orders_count: 1250,
        conversion_rate: 3.2,
        avg_order_value: 100,
        inventory_turnover: 8.5,
        customer_lifetime_value: 450
      }
    when 'manufacturing'
      {
        production_efficiency: 92,
        quality_score: 98.5,
        downtime_hours: 2.3,
        units_produced: 15000,
        defect_rate: 0.8,
        oee_score: 85
      }
    when 'professional_services'
      {
        billable_hours: 1680,
        project_margin: 28.5,
        utilization_rate: 87,
        client_satisfaction: 4.6,
        revenue_per_employee: 125000,
        project_completion_rate: 94
      }
    when 'healthcare'
      {
        patient_satisfaction: 4.8,
        readmission_rate: 8.2,
        bed_occupancy: 78,
        average_los: 3.2,
        staff_efficiency: 91,
        compliance_score: 96
      }
    else
      {}
    end
  end
end
