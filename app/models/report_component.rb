class ReportComponent < ApplicationRecord
  belongs_to :report_template
  
  COMPONENT_TYPES = %w[chart table metric text filter image divider].freeze
  
  validates :component_type, inclusion: { in: COMPONENT_TYPES }
  validates :component_id, presence: true, uniqueness: { scope: :report_template_id }
  validates :width, :height, numericality: { greater_than: 0 }
  validates :position_x, :position_y, :z_index, numericality: { greater_than_or_equal_to: 0 }
  
  scope :ordered, -> { order(:z_index, :position_y, :position_x) }
  scope :by_type, ->(type) { where(component_type: type) }
  
  # Default properties for each component type
  def self.default_properties_for(type)
    case type
    when 'chart'
      {
        chart_type: 'bar',
        title: 'New Chart',
        show_legend: true,
        show_grid: true,
        colors: ['#3B82F6', '#10B981', '#F59E0B', '#EF4444']
      }
    when 'table'
      {
        title: 'Data Table',
        show_header: true,
        sortable: true,
        paginated: true,
        rows_per_page: 10,
        searchable: true
      }
    when 'metric'
      {
        title: 'Key Metric',
        format: 'number',
        show_trend: true,
        comparison_period: 'previous_period',
        trend_direction: 'auto'
      }
    when 'text'
      {
        content: 'Add your text here',
        format: 'markdown',
        alignment: 'left',
        font_size: 'medium'
      }
    when 'filter'
      {
        filter_type: 'date_range',
        label: 'Date Range',
        default_value: 'last_30_days',
        apply_to_all: true
      }
    when 'image'
      {
        src: '',
        alt_text: '',
        alignment: 'center',
        link: ''
      }
    when 'divider'
      {
        style: 'solid',
        thickness: 1,
        color: '#E5E7EB'
      }
    else
      {}
    end
  end
  
  # Get data source options based on component type
  def data_source_options
    case component_type
    when 'chart', 'table', 'metric'
      {
        data_sources: available_data_sources,
        aggregations: ReportTemplate.aggregation_options,
        time_groupings: ReportTemplate.time_grouping_options
      }
    else
      {}
    end
  end
  
  # Validate component placement doesn't overlap
  def validate_placement
    overlapping = report_template.report_components
                                .where.not(id: id)
                                .where("position_x < ? AND position_x + width > ? AND position_y < ? AND position_y + height > ?",
                                      position_x + width, position_x, position_y + height, position_y)
    
    errors.add(:base, "Component overlaps with existing components") if overlapping.exists?
  end
  
  # Move component to new position
  def move_to(new_x, new_y)
    update(position_x: new_x, position_y: new_y)
  end
  
  # Resize component
  def resize(new_width, new_height)
    update(width: new_width, height: new_height)
  end
  
  # Update z-index (layer order)
  def bring_to_front
    max_z = report_template.report_components.maximum(:z_index) || 0
    update(z_index: max_z + 1)
  end
  
  def send_to_back
    update(z_index: 0)
    report_template.report_components.where.not(id: id).update_all("z_index = z_index + 1")
  end
  
  private
  
  def available_data_sources
    # This would connect to your actual data sources
    # For now, returning sample options
    [
      { id: 'sales', name: 'Sales Data', tables: ['orders', 'customers', 'products'] },
      { id: 'inventory', name: 'Inventory', tables: ['stock', 'warehouses', 'movements'] },
      { id: 'finance', name: 'Financial', tables: ['transactions', 'accounts', 'budgets'] }
    ]
  end
end