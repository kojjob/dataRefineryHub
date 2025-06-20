# Standardized inventory data model for all e-commerce platforms
# Provides unified schema for inventory data regardless of source platform
class StandardInventory
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations

  # Core inventory identification
  attribute :external_id, :string # composite ID for uniqueness
  attribute :platform_name, :string # shopify, woocommerce, amazon, etc.
  
  # Product/Variant relationship
  attribute :product_external_id, :string
  attribute :variant_external_id, :string
  attribute :inventory_item_id, :string # Platform-specific inventory item ID
  
  # Location information
  attribute :location_id, :string
  attribute :location_name, :string
  attribute :location_type, :string # warehouse, store, dropshipper, etc.
  
  # Inventory levels
  attribute :available_quantity, :integer
  attribute :committed_quantity, :integer # reserved for orders
  attribute :incoming_quantity, :integer # expected from suppliers
  attribute :on_hand_quantity, :integer # physical count
  
  # Product information (denormalized for analytics)
  attribute :sku, :string
  attribute :product_title, :string
  attribute :variant_title, :string
  
  # Inventory management
  attribute :tracked, :boolean # whether this item is tracked
  attribute :policy, :string # deny, continue (when out of stock)
  attribute :cost_per_item, :decimal
  attribute :currency, :string
  
  # Reorder information
  attribute :reorder_point, :integer
  attribute :reorder_quantity, :integer
  attribute :supplier_name, :string
  
  # Timestamps
  attribute :updated_at, :datetime
  attribute :last_count_at, :datetime
  
  # Additional platform-specific data
  attribute :platform_data, :json

  # Validations
  validates :external_id, presence: true
  validates :platform_name, presence: true, inclusion: { in: %w[shopify woocommerce amazon] }
  validates :product_external_id, presence: true
  validates :available_quantity, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :committed_quantity, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :incoming_quantity, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :on_hand_quantity, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Constants
  INVENTORY_POLICIES = %w[deny continue].freeze
  LOCATION_TYPES = %w[warehouse store dropshipper supplier].freeze

  def initialize(attributes = {})
    super(attributes)
    self.platform_data ||= {}
    self.tracked ||= true
    self.available_quantity ||= 0
    self.committed_quantity ||= 0
    self.incoming_quantity ||= 0
    self.on_hand_quantity ||= 0
  end

  # Computed properties
  def in_stock?
    available_quantity > 0
  end

  def low_stock?
    reorder_point && available_quantity <= reorder_point
  end

  def overstocked?
    reorder_point && reorder_quantity && 
    available_quantity > (reorder_point + reorder_quantity * 2)
  end

  def total_quantity
    (available_quantity || 0) + (committed_quantity || 0)
  end

  def free_quantity
    (available_quantity || 0) - (committed_quantity || 0)
  end

  def total_value
    return 0 unless cost_per_item && available_quantity
    cost_per_item * available_quantity
  end

  def turnover_ratio
    # Would need sales data to calculate properly
    # This is a placeholder for analytics
    0
  end

  # Convert to hash for database storage
  def to_hash
    attributes.compact
  end

  # Create from platform-specific data
  def self.from_platform_data(platform_name, raw_data, location_data = {})
    case platform_name.to_s
    when 'shopify'
      from_shopify_data(raw_data, location_data)
    when 'woocommerce'
      from_woocommerce_data(raw_data, location_data)
    when 'amazon'
      from_amazon_data(raw_data, location_data)
    else
      raise ArgumentError, "Unsupported platform: #{platform_name}"
    end
  end

  # Platform-specific factory methods
  def self.from_shopify_data(shopify_inventory, location_data = {})
    # Shopify inventory levels are per location per inventory item
    new(
      external_id: "#{shopify_inventory['inventory_item_id']}_#{shopify_inventory['location_id']}",
      platform_name: 'shopify',
      
      inventory_item_id: shopify_inventory['inventory_item_id']&.to_s,
      
      location_id: shopify_inventory['location_id']&.to_s,
      location_name: location_data['name'],
      location_type: normalize_shopify_location_type(location_data['type']),
      
      available_quantity: shopify_inventory['available'],
      
      tracked: true, # Shopify tracks if we have the data
      
      updated_at: shopify_inventory['updated_at'],
      
      platform_data: {
        shopify_inventory_item_id: shopify_inventory['inventory_item_id'],
        shopify_location_id: shopify_inventory['location_id'],
        admin_graphql_api_id: shopify_inventory['admin_graphql_api_id']
      }
    )
  end

  def self.from_woocommerce_data(wc_product, location_data = {})
    # WooCommerce products have inventory at product/variant level
    new(
      external_id: "#{wc_product['id']}_default",
      platform_name: 'woocommerce',
      
      product_external_id: wc_product['id']&.to_s,
      variant_external_id: wc_product['id']&.to_s, # Same for simple products
      
      location_id: 'default',
      location_name: 'Default Location',
      location_type: 'warehouse',
      
      available_quantity: wc_product['stock_quantity'],
      on_hand_quantity: wc_product['stock_quantity'],
      
      sku: wc_product['sku'],
      product_title: wc_product['name'],
      variant_title: 'Default',
      
      tracked: wc_product['manage_stock'],
      policy: wc_product['backorders'] == 'no' ? 'deny' : 'continue',
      
      updated_at: wc_product['date_modified'],
      
      platform_data: {
        woocommerce_id: wc_product['id'],
        stock_status: wc_product['stock_status'],
        backorders: wc_product['backorders'],
        low_stock_amount: wc_product['low_stock_amount']
      }
    )
  end

  def self.from_amazon_data(amazon_inventory, location_data = {})
    # Amazon FBA inventory data
    new(
      external_id: "#{amazon_inventory['SellerSKU']}_#{amazon_inventory['FulfillmentChannelSKU']}",
      platform_name: 'amazon',
      
      inventory_item_id: amazon_inventory['SellerSKU'],
      
      location_id: amazon_inventory['FulfillmentChannelSKU'],
      location_name: 'Amazon Fulfillment Center',
      location_type: 'warehouse',
      
      available_quantity: amazon_inventory['TotalSupplyQuantity'],
      committed_quantity: amazon_inventory['ReservedQuantity'],
      incoming_quantity: amazon_inventory['InboundWorkingQuantity'],
      on_hand_quantity: amazon_inventory['TotalSupplyQuantity'],
      
      sku: amazon_inventory['SellerSKU'],
      
      tracked: true,
      
      updated_at: amazon_inventory['LastUpdatedTime'],
      
      platform_data: {
        seller_sku: amazon_inventory['SellerSKU'],
        fulfillment_channel_sku: amazon_inventory['FulfillmentChannelSKU'],
        asin: amazon_inventory['ASIN'],
        condition: amazon_inventory['Condition'],
        inbound_working_quantity: amazon_inventory['InboundWorkingQuantity'],
        inbound_shipped_quantity: amazon_inventory['InboundShippedQuantity'],
        inbound_receiving_quantity: amazon_inventory['InboundReceivingQuantity'],
        reserved_quantity: amazon_inventory['ReservedQuantity'],
        unfulfillable_quantity: amazon_inventory['UnfulfillableQuantity']
      }
    )
  end

  # Helper methods for location type normalization
  def self.normalize_shopify_location_type(location_type)
    case location_type&.downcase
    when 'retail' then 'store'
    when 'warehouse' then 'warehouse'
    when 'dropshipper' then 'dropshipper'
    else 'warehouse'
    end
  end

  # Bulk operations for inventory management
  def self.calculate_reorder_recommendations(inventory_items)
    inventory_items.select(&:low_stock?).map do |item|
      {
        sku: item.sku,
        current_quantity: item.available_quantity,
        reorder_point: item.reorder_point,
        recommended_quantity: item.reorder_quantity,
        supplier: item.supplier_name,
        estimated_cost: item.cost_per_item * item.reorder_quantity
      }
    end
  end

  def self.calculate_total_inventory_value(inventory_items)
    inventory_items.sum(&:total_value)
  end

  def self.group_by_location(inventory_items)
    inventory_items.group_by(&:location_name)
  end

  def self.low_stock_items(inventory_items)
    inventory_items.select(&:low_stock?)
  end

  def self.out_of_stock_items(inventory_items)
    inventory_items.reject(&:in_stock?)
  end

  # Analytics helpers
  def days_of_inventory_remaining(average_daily_sales = 0)
    return Float::INFINITY if average_daily_sales.zero?
    available_quantity.to_f / average_daily_sales
  end

  def inventory_turnover_rate(annual_sales = 0)
    return 0 if available_quantity.zero? || annual_sales.zero?
    annual_sales.to_f / available_quantity
  end
end