class ReportTemplate < ApplicationRecord
  belongs_to :organization
  belongs_to :user
  has_many :report_components, dependent: :destroy
  has_many :delivery_preferences, dependent: :nullify
  
  TEMPLATE_TYPES = %w[standard custom shared].freeze
  
  validates :name, presence: true, length: { maximum: 255 }
  validates :template_type, inclusion: { in: TEMPLATE_TYPES }
  
  scope :public_templates, -> { where(is_public: true) }
  scope :featured, -> { where(is_featured: true) }
  scope :by_type, ->(type) { where(template_type: type) }
  scope :most_used, -> { order(usage_count: :desc) }
  scope :recent, -> { order(created_at: :desc) }
  
  # Clone a template for a user
  def clone_for_user(new_user)
    cloned = self.dup
    cloned.user = new_user
    cloned.organization = new_user.organization
    cloned.name = "Copy of #{name}"
    cloned.template_type = 'custom'
    cloned.is_public = false
    cloned.is_featured = false
    cloned.usage_count = 0
    
    if cloned.save
      # Clone components
      report_components.each do |component|
        cloned_component = component.dup
        cloned_component.report_template = cloned
        cloned_component.save
      end
    end
    
    cloned
  end
  
  # Execute the report query
  def execute_query(params = {})
    return {} unless query_definition.present?
    
    # This would integrate with your existing data source connections
    # For now, returning sample data structure
    {
      success: true,
      data: generate_sample_data,
      metadata: {
        executed_at: Time.current,
        row_count: 100,
        execution_time: 0.5
      }
    }
  end
  
  # Get chart options for different chart types
  def self.chart_options
    {
      bar: {
        name: 'Bar Chart',
        icon: '📊',
        supports: ['comparison', 'time_series', 'category'],
        options: ['stacked', 'horizontal', 'show_values']
      },
      line: {
        name: 'Line Chart',
        icon: '📈',
        supports: ['time_series', 'trend'],
        options: ['smooth', 'area', 'show_points']
      },
      pie: {
        name: 'Pie Chart',
        icon: '🥧',
        supports: ['proportion', 'category'],
        options: ['donut', 'show_labels', 'show_percentage']
      },
      metric: {
        name: 'Single Metric',
        icon: '🔢',
        supports: ['kpi', 'single_value'],
        options: ['comparison', 'trend', 'format']
      },
      table: {
        name: 'Data Table',
        icon: '📋',
        supports: ['detail', 'list'],
        options: ['sortable', 'searchable', 'exportable', 'paginated']
      },
      heatmap: {
        name: 'Heat Map',
        icon: '🔥',
        supports: ['correlation', 'density'],
        options: ['color_scale', 'show_values']
      },
      scatter: {
        name: 'Scatter Plot',
        icon: '⚡',
        supports: ['correlation', 'distribution'],
        options: ['trend_line', 'clusters']
      },
      gauge: {
        name: 'Gauge',
        icon: '🎯',
        supports: ['progress', 'target'],
        options: ['min_max', 'target_line', 'color_zones']
      }
    }
  end
  
  # Available data aggregations
  def self.aggregation_options
    {
      sum: 'Sum',
      avg: 'Average',
      count: 'Count',
      min: 'Minimum',
      max: 'Maximum',
      median: 'Median',
      mode: 'Mode',
      stddev: 'Standard Deviation'
    }
  end
  
  # Available time groupings
  def self.time_grouping_options
    {
      hour: 'Hourly',
      day: 'Daily',
      week: 'Weekly',
      month: 'Monthly',
      quarter: 'Quarterly',
      year: 'Yearly'
    }
  end
  
  private
  
  def generate_sample_data
    # Generate sample data based on component types
    components_data = {}
    
    report_components.each do |component|
      case component.component_type
      when 'chart'
        components_data[component.component_id] = generate_chart_data(component)
      when 'table'
        components_data[component.component_id] = generate_table_data(component)
      when 'metric'
        components_data[component.component_id] = generate_metric_data(component)
      end
    end
    
    components_data
  end
  
  def generate_chart_data(component)
    # Sample chart data
    {
      labels: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
      datasets: [{
        label: 'Revenue',
        data: [65000, 72000, 68000, 85000, 92000, 98000],
        backgroundColor: '#3B82F6'
      }]
    }
  end
  
  def generate_table_data(component)
    # Sample table data
    {
      headers: ['Date', 'Customer', 'Amount', 'Status'],
      rows: [
        ['2024-08-03', 'Acme Corp', '$5,240', 'Completed'],
        ['2024-08-02', 'TechStart Inc', '$3,150', 'Completed'],
        ['2024-08-01', 'Global Solutions', '$7,890', 'Pending']
      ]
    }
  end
  
  def generate_metric_data(component)
    # Sample metric data
    {
      value: 125430,
      label: 'Total Revenue',
      change: 12.5,
      change_type: 'increase',
      format: 'currency'
    }
  end
end