# Standardized customer data model for all e-commerce platforms
# Provides unified schema for customer data regardless of source platform
class StandardCustomer
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations

  # Core customer identification
  attribute :external_id, :string
  attribute :platform_name, :string # shopify, woocommerce, amazon, etc.
  
  # Personal information
  attribute :email, :string
  attribute :first_name, :string
  attribute :last_name, :string
  attribute :phone, :string
  attribute :date_of_birth, :date
  
  # Account status
  attribute :status, :string # active, inactive, suspended
  attribute :verified_email, :boolean
  attribute :accepts_marketing, :boolean
  attribute :marketing_opt_in_level, :string
  
  # Customer metrics
  attribute :orders_count, :integer
  attribute :total_spent, :decimal
  attribute :currency, :string
  attribute :lifetime_value, :decimal
  attribute :average_order_value, :decimal
  
  # Segmentation
  attribute :customer_segment, :string # vip, regular, new, churned
  attribute :tags, :string # comma-separated tags
  
  # Address information (as nested hash)
  attribute :default_address
  attribute :addresses # array of address hashes
  
  # Order history references
  attribute :first_order_id, :string
  attribute :last_order_id, :string
  attribute :last_order_name, :string
  
  # Timestamps
  attribute :created_at, :datetime
  attribute :updated_at, :datetime
  attribute :last_order_at, :datetime
  
  # Additional platform-specific data
  attribute :platform_data

  # Validations
  validates :external_id, presence: true
  validates :platform_name, presence: true, inclusion: { in: %w[shopify woocommerce amazon] }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :orders_count, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :total_spent, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Status constants
  CUSTOMER_STATUSES = %w[active inactive suspended].freeze
  CUSTOMER_SEGMENTS = %w[new regular vip churned at_risk].freeze
  MARKETING_OPT_IN_LEVELS = %w[single_opt_in confirmed_opt_in unknown].freeze

  def initialize(attributes = {})
    super(attributes)
    self.addresses ||= []
    self.platform_data ||= {}
    self.tags ||= ''
    self.orders_count ||= 0
    self.total_spent ||= 0.0
  end

  # Computed properties
  def full_name
    "#{first_name} #{last_name}".strip
  end

  def initials
    "#{first_name&.first}#{last_name&.first}".upcase
  end

  def has_orders?
    orders_count > 0
  end

  def high_value_customer?
    total_spent >= 1000 # Configurable threshold
  end

  def recent_customer?
    created_at && created_at > 30.days.ago
  end

  # Convert to hash for database storage
  def to_hash
    attributes.compact
  end

  # Create from platform-specific data
  def self.from_platform_data(platform_name, raw_data)
    case platform_name.to_s
    when 'shopify'
      from_shopify_data(raw_data)
    when 'woocommerce'
      from_woocommerce_data(raw_data)
    when 'amazon'
      from_amazon_data(raw_data)
    else
      raise ArgumentError, "Unsupported platform: #{platform_name}"
    end
  end

  # Platform-specific factory methods
  def self.from_shopify_data(shopify_customer)
    new(
      external_id: shopify_customer['id'].to_s,
      platform_name: 'shopify',
      
      email: shopify_customer['email'],
      first_name: shopify_customer['first_name'],
      last_name: shopify_customer['last_name'],
      phone: shopify_customer['phone'],
      
      status: normalize_shopify_status(shopify_customer['state']),
      verified_email: shopify_customer['verified_email'],
      accepts_marketing: shopify_customer['accepts_marketing'],
      marketing_opt_in_level: shopify_customer['marketing_opt_in_level'],
      
      orders_count: shopify_customer['orders_count'] || 0,
      total_spent: shopify_customer['total_spent']&.to_f || 0.0,
      currency: shopify_customer['currency'],
      
      customer_segment: derive_shopify_segment(shopify_customer),
      tags: shopify_customer['tags'],
      
      default_address: normalize_shopify_address(shopify_customer['default_address']),
      addresses: normalize_shopify_addresses(shopify_customer['addresses'] || []),
      
      last_order_id: shopify_customer['last_order_id']&.to_s,
      last_order_name: shopify_customer['last_order_name'],
      
      created_at: shopify_customer['created_at'],
      updated_at: shopify_customer['updated_at'],
      
      platform_data: {
        shopify_id: shopify_customer['id'],
        tax_exempt: shopify_customer['tax_exempt'],
        tax_exemptions: shopify_customer['tax_exemptions'],
        admin_graphql_api_id: shopify_customer['admin_graphql_api_id'],
        multipass_identifier: shopify_customer['multipass_identifier'],
        note: shopify_customer['note']
      }
    )
  end

  def self.from_woocommerce_data(wc_customer)
    new(
      external_id: wc_customer['id'].to_s,
      platform_name: 'woocommerce',
      
      email: wc_customer['email'],
      first_name: wc_customer['first_name'],
      last_name: wc_customer['last_name'],
      
      status: normalize_wc_status(wc_customer),
      
      orders_count: wc_customer['orders_count'] || 0,
      total_spent: wc_customer['total_spent']&.to_f || 0.0,
      
      customer_segment: derive_wc_segment(wc_customer),
      
      default_address: normalize_wc_billing_address(wc_customer['billing']),
      addresses: [
        normalize_wc_billing_address(wc_customer['billing']),
        normalize_wc_shipping_address(wc_customer['shipping'])
      ].compact,
      
      created_at: wc_customer['date_created'],
      updated_at: wc_customer['date_modified'],
      
      platform_data: {
        woocommerce_id: wc_customer['id'],
        username: wc_customer['username'],
        role: wc_customer['role'],
        is_paying_customer: wc_customer['is_paying_customer'],
        avatar_url: wc_customer['avatar_url'],
        meta_data: wc_customer['meta_data']
      }
    )
  end

  def self.from_amazon_data(amazon_customer)
    # Amazon doesn't provide detailed customer data due to privacy
    # We create minimal customer records from order data
    new(
      external_id: amazon_customer['buyer_email'], # Use email as ID
      platform_name: 'amazon',
      
      email: amazon_customer['buyer_email'],
      
      status: 'active',
      
      platform_data: {
        marketplace_id: amazon_customer['marketplace_id'],
        buyer_name: amazon_customer['buyer_name']
      }
    )
  end

  # Status normalization helpers
  def self.normalize_shopify_status(state)
    case state&.downcase
    when 'enabled', 'invited', 'enabled' then 'active'
    when 'disabled' then 'inactive'
    when 'declined' then 'suspended'
    else 'active'
    end
  end

  def self.normalize_wc_status(customer)
    # WooCommerce doesn't have explicit status, infer from data
    return 'active' if customer['is_paying_customer']
    return 'inactive' if customer['orders_count']&.zero?
    'active'
  end

  # Segmentation helpers
  def self.derive_shopify_segment(customer)
    orders_count = customer['orders_count'] || 0
    total_spent = customer['total_spent']&.to_f || 0.0
    created_at = Date.parse(customer['created_at']) rescue nil
    
    return 'vip' if total_spent >= 1000
    return 'new' if created_at && created_at > 30.days.ago
    return 'churned' if orders_count > 0 && customer['last_order_id'].nil?
    return 'regular' if orders_count > 1
    'new'
  end

  def self.derive_wc_segment(customer)
    orders_count = customer['orders_count'] || 0
    total_spent = customer['total_spent']&.to_f || 0.0
    created_at = Date.parse(customer['date_created']) rescue nil
    
    return 'vip' if total_spent >= 1000
    return 'new' if created_at && created_at > 30.days.ago
    return 'regular' if orders_count > 1
    'new'
  end

  # Address normalization
  def self.normalize_shopify_address(address)
    return nil unless address

    {
      id: address['id']&.to_s,
      first_name: address['first_name'],
      last_name: address['last_name'],
      company: address['company'],
      address1: address['address1'],
      address2: address['address2'],
      city: address['city'],
      province: address['province'],
      country: address['country'],
      zip: address['zip'],
      phone: address['phone'],
      name: address['name'],
      province_code: address['province_code'],
      country_code: address['country_code'],
      country_name: address['country_name'],
      default: address['default']
    }.compact
  end

  def self.normalize_shopify_addresses(addresses)
    addresses.map { |addr| normalize_shopify_address(addr) }.compact
  end

  def self.normalize_wc_billing_address(billing)
    return nil unless billing

    {
      type: 'billing',
      first_name: billing['first_name'],
      last_name: billing['last_name'],
      company: billing['company'],
      address1: billing['address_1'],
      address2: billing['address_2'],
      city: billing['city'],
      province: billing['state'],
      country: billing['country'],
      zip: billing['postcode'],
      phone: billing['phone'],
      email: billing['email']
    }.compact
  end

  def self.normalize_wc_shipping_address(shipping)
    return nil unless shipping

    {
      type: 'shipping',
      first_name: shipping['first_name'],
      last_name: shipping['last_name'],
      company: shipping['company'],
      address1: shipping['address_1'],
      address2: shipping['address_2'],
      city: shipping['city'],
      province: shipping['state'],
      country: shipping['country'],
      zip: shipping['postcode']
    }.compact
  end

  # Customer analytics helpers
  def calculate_lifetime_value
    # Simple LTV calculation: average order value * purchase frequency * customer lifespan
    return 0 if orders_count.zero?
    
    avg_order_value = total_spent / orders_count
    # Estimate customer lifespan as 2 years for now
    customer_lifespan_months = 24
    # Estimate purchase frequency based on orders per month since creation
    months_since_creation = created_at ? ((Time.current - created_at) / 1.month).round : 1
    purchase_frequency = orders_count.to_f / [months_since_creation, 1].max
    
    (avg_order_value * purchase_frequency * customer_lifespan_months).round(2)
  end

  def calculate_average_order_value
    return 0 if orders_count.zero?
    (total_spent / orders_count).round(2)
  end
end