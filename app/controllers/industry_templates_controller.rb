class IndustryTemplatesController < DataflowProController
  before_action :authenticate_user!
  before_action :set_template, only: [ :show, :apply ]

  def index
    @templates = IndustryTemplate.all_templates
  end

  def show
    @template_config = @template[:config]
    @preview_data = generate_preview_data(@template)
    @metric_trends = generate_metric_trends(@template)
    @chart_data = generate_chart_data(@template)
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
    # Generate realistic preview data based on actual metrics
    case template[:id]
    when "retail_ecommerce"
      {
        total_revenue: 125000,
        orders_count: 1250,
        conversion_rate: 3.2,
        avg_order_value: 100,
        inventory_turnover: 8.5,
        customer_lifetime_value: 450
      }
    when "manufacturing"
      {
        production_efficiency: 92,
        quality_score: 98.5,
        downtime_hours: 2.3,
        units_produced: 15000,
        defect_rate: 0.8,
        oee_score: 85
      }
    when "professional_services"
      {
        billable_hours: 1680,
        project_margin: 28.5,
        utilization_rate: 87,
        client_satisfaction: 4.6,
        revenue_per_employee: 125000,
        project_completion_rate: 94
      }
    when "healthcare"
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

  def generate_metric_trends(template)
    # Generate trend percentages for each metric
    template[:metrics].map do |metric|
      {
        key: metric[:key],
        trend: rand(5..15),
        direction: rand > 0.3 ? "up" : "down"
      }
    end.index_by { |m| m[:key] }
  end

  def generate_chart_data(template)
    # Generate actual chart data for each chart type
    charts = {}

    template[:charts]&.each do |chart|
      chart_id = chart[:data_key] || chart[:title]&.parameterize || "chart_#{charts.size}"
      
      case chart[:type]
      when "line"
        # Generate line chart data for last 7 days
        labels = (0..6).map { |i| (Date.today - i).strftime("%b %d") }.reverse
        # Use template metrics to generate multiple datasets for line charts
        datasets = template[:metrics]&.first(3)&.map do |metric|
          {
            label: metric[:label],
            data: (0..6).map { rand(50..150) }
          }
        end || [{
          label: chart[:title],
          data: (0..6).map { rand(50..150) }
        }]
        charts[chart_id] = { labels: labels, datasets: datasets }

      when "bar"
        # Generate bar chart data
        labels = chart[:categories] || [ "Category A", "Category B", "Category C", "Category D" ]
        datasets = [ {
          label: chart[:title],
          data: labels.map { rand(100..500) }
        } ]
        charts[chart_id] = { labels: labels, datasets: datasets }

      when "doughnut", "pie"
        # Generate pie/doughnut chart data
        labels = chart[:categories] || [ "Segment 1", "Segment 2", "Segment 3", "Segment 4" ]
        datasets = [ {
          data: labels.map { rand(15..40) }
        } ]
        charts[chart_id] = { labels: labels, datasets: datasets }
        
      when "area"
        # Generate area chart data (similar to line)
        labels = (0..6).map { |i| (Date.today - i).strftime("%b %d") }.reverse
        datasets = [{
          label: chart[:title],
          data: (0..6).map { rand(30..120) }
        }]
        charts[chart_id] = { labels: labels, datasets: datasets }
        
      when "gauge"
        # Generate gauge chart data
        datasets = [{
          value: rand(60..95),
          max: 100
        }]
        charts[chart_id] = { datasets: datasets }
        
      when "heatmap"
        # Generate heatmap data
        datasets = [{
          data: (1..7).map { |day|
            (1..24).map { |hour|
              { x: hour, y: day, v: rand(0..100) }
            }
          }.flatten
        }]
        charts[chart_id] = { datasets: datasets }
        
      when "radar"
        # Generate radar chart data
        labels = [ "Quality", "Efficiency", "Safety", "Cost", "Delivery" ]
        datasets = [{
          label: chart[:title],
          data: labels.map { rand(60..100) }
        }]
        charts[chart_id] = { labels: labels, datasets: datasets }
        
      when "scatter"
        # Generate scatter plot data
        datasets = [{
          label: chart[:title],
          data: (1..20).map { { x: rand(10..100), y: rand(10..100) } }
        }]
        charts[chart_id] = { datasets: datasets }
        
      when "funnel"
        # Generate funnel chart data
        labels = [ "Leads", "Qualified", "Proposal", "Negotiation", "Closed" ]
        datasets = [{
          data: [ 1000, 750, 500, 300, 200 ]
        }]
        charts[chart_id] = { labels: labels, datasets: datasets }
        
      when "timeline"
        # Generate timeline data
        datasets = [{
          data: [
            { name: "Project A", start: Date.today, end: Date.today + 30.days },
            { name: "Project B", start: Date.today + 10.days, end: Date.today + 45.days },
            { name: "Project C", start: Date.today + 20.days, end: Date.today + 60.days }
          ]
        }]
        charts[chart_id] = { datasets: datasets }
      end
    end

    charts
  end
end
