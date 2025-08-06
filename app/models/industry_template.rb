class IndustryTemplate
  include ActiveModel::Model

  attr_accessor :id, :name, :description, :category, :icon, :color, :metrics, :charts, :insights

  TEMPLATES = {
    "retail_ecommerce" => {
      id: "retail_ecommerce",
      name: "Retail & E-commerce Analytics",
      description: "Comprehensive dashboard for retail operations, inventory management, and customer analytics",
      category: "Retail",
      icon: "shopping-cart",
      color: "primary",
      metrics: [
        { key: "total_revenue", label: "Total Revenue", format: "currency", icon: "dollar-sign" },
        { key: "orders_count", label: "Orders", format: "number", icon: "shopping-bag" },
        { key: "conversion_rate", label: "Conversion Rate", format: "percentage", icon: "trending-up" },
        { key: "avg_order_value", label: "Avg Order Value", format: "currency", icon: "credit-card" },
        { key: "inventory_turnover", label: "Inventory Turnover", format: "decimal", icon: "refresh-cw" },
        { key: "customer_lifetime_value", label: "Customer LTV", format: "currency", icon: "users" }
      ],
      charts: [
        { type: "line", title: "Revenue Trends", data_key: "revenue_over_time" },
        { type: "bar", title: "Top Products", data_key: "product_performance" },
        { type: "doughnut", title: "Traffic Sources", data_key: "traffic_sources" },
        { type: "area", title: "Customer Acquisition", data_key: "customer_acquisition" }
      ],
      insights: [
        { type: "critical", title: "Inventory Alert", message: "Low stock detected for 15 products. Reorder recommended." },
        { type: "opportunity", title: "Conversion Optimization", message: "Cart abandonment rate increased 12%. Consider email remarketing." },
        { type: "trend", title: "Seasonal Pattern", message: "Weekend sales show 23% increase. Optimize weekend promotions." }
      ]
    },
    "manufacturing" => {
      id: "manufacturing",
      name: "Manufacturing Operations",
      description: "OEE monitoring, production tracking, and quality control dashboard",
      category: "Manufacturing",
      icon: "settings",
      color: "warning",
      metrics: [
        { key: "production_efficiency", label: "Production Efficiency", format: "percentage", icon: "activity" },
        { key: "quality_score", label: "Quality Score", format: "percentage", icon: "check-circle" },
        { key: "downtime_hours", label: "Downtime Hours", format: "decimal", icon: "clock" },
        { key: "units_produced", label: "Units Produced", format: "number", icon: "package" },
        { key: "defect_rate", label: "Defect Rate", format: "percentage", icon: "alert-triangle" },
        { key: "oee_score", label: "OEE Score", format: "percentage", icon: "target" }
      ],
      charts: [
        { type: "line", title: "Production Output", data_key: "production_over_time" },
        { type: "bar", title: "Equipment Efficiency", data_key: "equipment_performance" },
        { type: "gauge", title: "Overall Equipment Effectiveness", data_key: "oee_gauge" },
        { type: "heatmap", title: "Quality Control Matrix", data_key: "quality_heatmap" }
      ],
      insights: [
        { type: "critical", title: "Equipment Maintenance", message: "Machine #3 showing efficiency decline. Schedule maintenance." },
        { type: "opportunity", title: "Process Optimization", message: "Line 2 could increase output by 15% with workflow adjustments." },
        { type: "trend", title: "Quality Improvement", message: "Defect rate decreased 0.3% this month. Quality initiatives working." }
      ]
    },
    "professional_services" => {
      id: "professional_services",
      name: "Professional Services",
      description: "Project profitability, resource utilization, and client management dashboard",
      category: "Services",
      icon: "briefcase",
      color: "success",
      metrics: [
        { key: "billable_hours", label: "Billable Hours", format: "number", icon: "clock" },
        { key: "project_margin", label: "Project Margin", format: "percentage", icon: "trending-up" },
        { key: "utilization_rate", label: "Utilization Rate", format: "percentage", icon: "users" },
        { key: "client_satisfaction", label: "Client Satisfaction", format: "rating", icon: "star" },
        { key: "revenue_per_employee", label: "Revenue/Employee", format: "currency", icon: "user-check" },
        { key: "project_completion_rate", label: "On-Time Delivery", format: "percentage", icon: "check-square" }
      ],
      charts: [
        { type: "line", title: "Revenue by Practice", data_key: "practice_revenue" },
        { type: "bar", title: "Resource Utilization", data_key: "resource_utilization" },
        { type: "scatter", title: "Project Profitability", data_key: "project_profitability" },
        { type: "timeline", title: "Project Pipeline", data_key: "project_timeline" }
      ],
      insights: [
        { type: "opportunity", title: "Resource Optimization", message: "Senior consultants underutilized. Consider project reallocation." },
        { type: "trend", title: "Client Retention", message: "Client satisfaction scores improving. Renewal rate up 18%." },
        { type: "critical", title: "Project Risk", message: "3 projects at risk of budget overrun. Review scope and resources." }
      ]
    },
    "healthcare" => {
      id: "healthcare",
      name: "Healthcare Analytics",
      description: "Patient outcomes, operational efficiency, and compliance monitoring dashboard",
      category: "Healthcare",
      icon: "heart",
      color: "error",
      metrics: [
        { key: "patient_satisfaction", label: "Patient Satisfaction", format: "rating", icon: "heart" },
        { key: "readmission_rate", label: "Readmission Rate", format: "percentage", icon: "rotate-ccw" },
        { key: "bed_occupancy", label: "Bed Occupancy", format: "percentage", icon: "home" },
        { key: "average_los", label: "Average LOS", format: "decimal", icon: "calendar" },
        { key: "staff_efficiency", label: "Staff Efficiency", format: "percentage", icon: "user-plus" },
        { key: "compliance_score", label: "Compliance Score", format: "percentage", icon: "shield-check" }
      ],
      charts: [
        { type: "line", title: "Patient Flow", data_key: "patient_flow" },
        { type: "bar", title: "Department Performance", data_key: "department_metrics" },
        { type: "radar", title: "Quality Indicators", data_key: "quality_radar" },
        { type: "funnel", title: "Care Pathway", data_key: "care_funnel" }
      ],
      insights: [
        { type: "critical", title: "Capacity Alert", message: "ICU approaching capacity. Consider patient transfer protocols." },
        { type: "opportunity", title: "Length of Stay", message: "Average LOS decreased 0.5 days. Discharge planning improvements working." },
        { type: "trend", title: "Patient Satisfaction", message: "Satisfaction scores up 8% following staff training program." }
      ]
    }
  }.freeze

  def self.all_templates
    TEMPLATES.values.map { |template_data| new(template_data) }
  end

  def self.find_template(id)
    TEMPLATES[id]
  end

  def initialize(attributes = {})
    attributes.each do |key, value|
      if respond_to?("#{key}=")
        send("#{key}=", value)
      end
    end
  end
end
