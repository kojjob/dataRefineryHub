# Standardized product data model for all e-commerce platforms
# Provides unified schema for product data regardless of source platform
class StandardProduct
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations

  # Core product identification
  attribute :external_id, :string
  attribute :platform_name, :string # shopify, woocommerce, amazon, etc.
  
  # Product information
  attribute :title, :string
  attribute :description, :string
  attribute :handle, :string # URL slug
  attribute :product_type, :string
  attribute :vendor, :string
  attribute :brand, :string
  
  # Status and visibility
  attribute :status, :string # active, draft, archived
  attribute :published, :boolean
  attribute :published_scope, :string # web, global, etc.
  
  # Categorization
  attribute :category, :string
  attribute :tags, :string # comma-separated tags
  
  # SEO
  attribute :seo_title, :string
  attribute :seo_description, :string
  
  # Variants information (as nested arrays)
  attribute :variants
  attribute :options # Size, Color, etc.
  
  # Images (as nested array)
  attribute :images
  
  # Pricing (base product pricing)
  attribute :price, :decimal
  attribute :compare_at_price, :decimal
  attribute :cost_per_item, :decimal
  attribute :currency, :string
  
  # Inventory (aggregated from variants)
  attribute :total_inventory, :integer
  attribute :track_inventory, :boolean
  attribute :inventory_policy, :string # deny, continue
  
  # Timestamps
  attribute :created_at, :datetime
  attribute :updated_at, :datetime
  attribute :published_at, :datetime
  
  # Additional platform-specific data
  attribute :platform_data

  # Validations
  validates :external_id, presence: true
  validates :platform_name, presence: true, inclusion: { in: %w[shopify woocommerce amazon] }
  validates :title, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :total_inventory, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Status constants
  PRODUCT_STATUSES = %w[active draft archived].freeze
  INVENTORY_POLICIES = %w[deny continue].freeze
  PUBLISHED_SCOPES = %w[web global].freeze

  def initialize(attributes = {})
    super(attributes)
    self.variants ||= []
    self.options ||= []
    self.images ||= []
    self.platform_data ||= {}
    self.tags ||= ''
    self.published ||= false
    self.track_inventory ||= true
  end

  # Computed properties
  def has_variants?
    variants.length > 1
  end

  def in_stock?
    total_inventory > 0
  end

  def on_sale?
    compare_at_price && price && compare_at_price > price
  end

  def discount_percentage
    return 0 unless on_sale?
    ((compare_at_price - price) / compare_at_price * 100).round(1)
  end

  def variant_count
    variants.length
  end

  def image_count
    images.length
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
  def self.from_shopify_data(shopify_product)
    variants_data = normalize_shopify_variants(shopify_product['variants'] || [])
    
    new(
      external_id: shopify_product['id'].to_s,
      platform_name: 'shopify',
      
      title: shopify_product['title'],
      description: shopify_product['body_html'],
      handle: shopify_product['handle'],
      product_type: shopify_product['product_type'],
      vendor: shopify_product['vendor'],
      brand: shopify_product['vendor'], # Shopify uses vendor as brand
      
      status: normalize_shopify_status(shopify_product['status']),
      published: shopify_product['published_scope'] != 'null',
      published_scope: shopify_product['published_scope'],
      
      tags: shopify_product['tags'],
      
      seo_title: shopify_product['seo_title'],
      seo_description: shopify_product['seo_description'],
      
      variants: variants_data,
      options: normalize_shopify_options(shopify_product['options'] || []),
      
      images: normalize_shopify_images(shopify_product['images'] || []),
      
      # Use first variant for base pricing
      price: variants_data.first&.dig('price'),
      compare_at_price: variants_data.first&.dig('compare_at_price'),
      currency: 'USD', # Default, should be configurable
      
      total_inventory: calculate_total_inventory(variants_data),
      track_inventory: variants_data.any? { |v| v['inventory_management'] },
      inventory_policy: variants_data.first&.dig('inventory_policy'),
      
      created_at: shopify_product['created_at'],
      updated_at: shopify_product['updated_at'],
      published_at: shopify_product['published_at'],
      
      platform_data: {
        shopify_id: shopify_product['id'],
        template_suffix: shopify_product['template_suffix'],
        admin_graphql_api_id: shopify_product['admin_graphql_api_id']
      }
    )
  end

  def self.from_woocommerce_data(wc_product)
    variants_data = normalize_wc_variants(wc_product)
    
    new(
      external_id: wc_product['id'].to_s,
      platform_name: 'woocommerce',
      
      title: wc_product['name'],
      description: wc_product['description'],
      handle: wc_product['slug'],
      product_type: wc_product['type'],
      
      status: normalize_wc_status(wc_product['status']),
      published: wc_product['status'] == 'publish',
      
      category: extract_wc_categories(wc_product['categories']),
      tags: extract_wc_tags(wc_product['tags']),
      
      seo_title: wc_product['meta_data']&.find { |m| m['key'] == '_yoast_wpseo_title' }&.dig('value'),
      seo_description: wc_product['meta_data']&.find { |m| m['key'] == '_yoast_wpseo_metadesc' }&.dig('value'),
      
      variants: variants_data,
      
      images: normalize_wc_images(wc_product['images'] || []),
      
      price: wc_product['price']&.to_f,
      compare_at_price: wc_product['regular_price']&.to_f,
      currency: 'USD', # Default, should be configurable
      
      total_inventory: wc_product['stock_quantity'] || 0,
      track_inventory: wc_product['manage_stock'],
      inventory_policy: wc_product['backorders'] == 'no' ? 'deny' : 'continue',
      
      created_at: wc_product['date_created'],
      updated_at: wc_product['date_modified'],
      
      platform_data: {
        woocommerce_id: wc_product['id'],
        sku: wc_product['sku'],
        weight: wc_product['weight'],
        dimensions: wc_product['dimensions'],
        shipping_class: wc_product['shipping_class'],
        tax_class: wc_product['tax_class'],
        tax_status: wc_product['tax_status'],
        featured: wc_product['featured'],
        catalog_visibility: wc_product['catalog_visibility'],
        short_description: wc_product['short_description']
      }
    )
  end

  def self.from_amazon_data(amazon_product)
    new(
      external_id: amazon_product['ASIN'],
      platform_name: 'amazon',
      
      title: amazon_product['Title'],
      description: amazon_product['Description'],
      brand: amazon_product['Brand'],
      
      status: normalize_amazon_status(amazon_product),
      published: true, # Assume published if we can fetch it
      
      price: amazon_product['Price']&.to_f,
      currency: amazon_product['Currency'] || 'USD',
      
      platform_data: {
        asin: amazon_product['ASIN'],
        parent_asin: amazon_product['ParentASIN'],
        marketplace_id: amazon_product['MarketplaceId'],
        binding: amazon_product['Binding'],
        item_package_quantity: amazon_product['ItemPackageQuantity'],
        manufacturer: amazon_product['Manufacturer'],
        model: amazon_product['Model'],
        part_number: amazon_product['PartNumber'],
        product_group: amazon_product['ProductGroup'],
        product_type_name: amazon_product['ProductTypeName']
      }
    )
  end

  # Status normalization helpers
  def self.normalize_shopify_status(status)
    case status&.downcase
    when 'active' then 'active'
    when 'draft' then 'draft'
    when 'archived' then 'archived'
    else 'draft'
    end
  end

  def self.normalize_wc_status(status)
    case status&.downcase
    when 'publish' then 'active'
    when 'draft' then 'draft'
    when 'pending' then 'draft'
    when 'private' then 'archived'
    when 'trash' then 'archived'
    else 'draft'
    end
  end

  def self.normalize_amazon_status(product)
    # Amazon products are active if we can fetch them
    'active'
  end

  # Variants normalization
  def self.normalize_shopify_variants(variants)
    variants.map do |variant|
      {
        external_id: variant['id']&.to_s,
        title: variant['title'],
        option1: variant['option1'],
        option2: variant['option2'],
        option3: variant['option3'],
        sku: variant['sku'],
        price: variant['price']&.to_f,
        compare_at_price: variant['compare_at_price']&.to_f,
        inventory_quantity: variant['inventory_quantity'],
        inventory_management: variant['inventory_management'],
        inventory_policy: variant['inventory_policy'],
        fulfillment_service: variant['fulfillment_service'],
        requires_shipping: variant['requires_shipping'],
        taxable: variant['taxable'],
        weight: variant['weight'],
        weight_unit: variant['weight_unit'],
        created_at: variant['created_at'],
        updated_at: variant['updated_at']
      }.compact
    end
  end

  def self.normalize_wc_variants(product)
    # WooCommerce simple products have one variant
    if product['type'] == 'simple'
      [{
        external_id: product['id']&.to_s,
        title: 'Default',
        sku: product['sku'],
        price: product['price']&.to_f,
        compare_at_price: product['regular_price']&.to_f,
        inventory_quantity: product['stock_quantity'],
        inventory_management: product['manage_stock'],
        weight: product['weight']
      }.compact]
    else
      # For variable products, variations would need separate API call
      []
    end
  end

  # Options normalization
  def self.normalize_shopify_options(options)
    options.map do |option|
      {
        external_id: option['id']&.to_s,
        name: option['name'],
        position: option['position'],
        values: option['values']
      }.compact
    end
  end

  # Images normalization
  def self.normalize_shopify_images(images)
    images.map do |image|
      {
        external_id: image['id']&.to_s,
        src: image['src'],
        alt: image['alt'],
        position: image['position'],
        width: image['width'],
        height: image['height'],
        created_at: image['created_at'],
        updated_at: image['updated_at']
      }.compact
    end
  end

  def self.normalize_wc_images(images)
    images.map do |image|
      {
        external_id: image['id']&.to_s,
        src: image['src'],
        alt: image['alt'],
        name: image['name'],
        position: image['position']
      }.compact
    end
  end

  # Category and tag extraction for WooCommerce
  def self.extract_wc_categories(categories)
    categories&.map { |cat| cat['name'] }&.join(', ')
  end

  def self.extract_wc_tags(tags)
    tags&.map { |tag| tag['name'] }&.join(', ')
  end

  # Inventory calculation
  def self.calculate_total_inventory(variants)
    variants.sum { |variant| variant['inventory_quantity'] || 0 }
  end
end