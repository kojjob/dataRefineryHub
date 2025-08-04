# frozen_string_literal: true

class Dashboard < ApplicationRecord
  belongs_to :organization
  
  # Dashboard types
  TYPES = %w[
    revenue
    customers
    operations
    marketing
    resources
    ecommerce
  ].freeze
  
  # Validations
  validates :name, presence: true
  validates :dashboard_type, inclusion: { in: TYPES }, allow_nil: true
  validates :configuration, presence: true
  
  # Scopes
  scope :by_type, ->(type) { where(dashboard_type: type) }
  scope :active, -> { where(active: true) }
  
  # Callbacks
  before_validation :set_defaults
  
  # Get widgets configuration
  def widgets
    configuration['widgets'] || []
  end
  
  # Add a widget
  def add_widget(widget_config)
    self.configuration ||= {}
    self.configuration['widgets'] ||= []
    self.configuration['widgets'] << widget_config
    save
  end
  
  # Remove a widget
  def remove_widget(widget_id)
    return unless configuration['widgets']
    
    configuration['widgets'].delete_if { |w| w['id'] == widget_id }
    save
  end
  
  # Update widget configuration
  def update_widget(widget_id, new_config)
    return unless configuration['widgets']
    
    widget = configuration['widgets'].find { |w| w['id'] == widget_id }
    widget&.merge!(new_config)
    save
  end
  
  private
  
  def set_defaults
    self.active = true if active.nil?
    self.configuration ||= { 'widgets' => [] }
  end
end