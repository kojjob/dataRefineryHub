# Standardized order data model for all e-commerce platforms
# Provides unified schema for order data regardless of source platform
class StandardOrder
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations

  # Core order identification
  attribute :external_id, :string
  attribute :order_number, :string
  attribute :platform_name, :string # shopify, woocommerce, amazon, etc.

  # Financial information
  attribute :total_price, :decimal
  attribute :subtotal_price, :decimal
  attribute :total_tax, :decimal
  attribute :total_discounts, :decimal
  attribute :total_shipping, :decimal
  attribute :currency, :string

  # Order status
  attribute :financial_status, :string  # paid, pending, refunded, etc.
  attribute :fulfillment_status, :string # fulfilled, partial, unfulfilled, etc.
  attribute :order_status, :string # processing, completed, cancelled, etc.

  # Customer information
  attribute :customer_external_id, :string
  attribute :customer_email, :string
  attribute :customer_phone, :string

  # Timestamps
  attribute :created_at, :datetime
  attribute :updated_at, :datetime
  attribute :processed_at, :datetime
  attribute :cancelled_at, :datetime
  attribute :shipped_at, :datetime

  # Order metadata
  attribute :tags, :string # comma-separated tags
  attribute :notes, :string
  attribute :source_name, :string # web, mobile, pos, etc.
  attribute :referring_site, :string
  attribute :landing_site, :string

  # Addresses (as nested hashes)
  attribute :billing_address
  attribute :shipping_address

  # Line items (array of StandardLineItem hashes)
  attribute :line_items

  # Additional platform-specific data
  attribute :platform_data

  # Validations
  validates :external_id, presence: true
  validates :platform_name, presence: true, inclusion: { in: %w[shopify woocommerce amazon] }
  validates :total_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, presence: true, length: { is: 3 }
  validates :created_at, presence: true
  validates :customer_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  # Status constants
  FINANCIAL_STATUSES = %w[
    pending authorized partially_paid paid partially_refunded refunded voided
  ].freeze

  FULFILLMENT_STATUSES = %w[
    unfulfilled partial fulfilled
  ].freeze

  ORDER_STATUSES = %w[
    pending processing shipped delivered cancelled refunded
  ].freeze

  def initialize(attributes = {})
    super(attributes)
    self.line_items ||= []
    self.platform_data ||= {}
    self.tags ||= ""
  end

  # Convert to hash for database storage
  def to_hash
    attributes.compact
  end

  # Create from platform-specific data
  def self.from_platform_data(platform_name, raw_data)
    case platform_name.to_s
    when "shopify"
      from_shopify_data(raw_data)
    when "woocommerce"
      from_woocommerce_data(raw_data)
    when "amazon"
      from_amazon_data(raw_data)
    else
      raise ArgumentError, "Unsupported platform: #{platform_name}"
    end
  end

  # Platform-specific factory methods
  def self.from_shopify_data(shopify_order)
    new(
      external_id: shopify_order["id"].to_s,
      order_number: shopify_order["order_number"] || shopify_order["name"],
      platform_name: "shopify",

      total_price: shopify_order["total_price"]&.to_f,
      subtotal_price: shopify_order["subtotal_price"]&.to_f,
      total_tax: shopify_order["total_tax"]&.to_f,
      total_discounts: shopify_order["total_discounts"]&.to_f,
      total_shipping: shopify_order["total_shipping_price_set"]&.dig("shop_money", "amount")&.to_f,
      currency: shopify_order["currency"],

      financial_status: normalize_shopify_financial_status(shopify_order["financial_status"]),
      fulfillment_status: normalize_shopify_fulfillment_status(shopify_order["fulfillment_status"]),
      order_status: derive_order_status_from_shopify(shopify_order),

      customer_external_id: shopify_order["customer"]&.dig("id")&.to_s,
      customer_email: shopify_order["email"],
      customer_phone: shopify_order["phone"],

      created_at: shopify_order["created_at"],
      updated_at: shopify_order["updated_at"],
      processed_at: shopify_order["processed_at"],
      cancelled_at: shopify_order["cancelled_at"],

      tags: shopify_order["tags"],
      notes: shopify_order["note"],
      source_name: shopify_order["source_name"],
      referring_site: shopify_order["referring_site"],
      landing_site: shopify_order["landing_site"],

      billing_address: normalize_address(shopify_order["billing_address"]),
      shipping_address: normalize_address(shopify_order["shipping_address"]),

      line_items: normalize_shopify_line_items(shopify_order["line_items"] || []),
      platform_data: {
        shopify_id: shopify_order["id"],
        gateway: shopify_order["gateway"],
        payment_gateway_names: shopify_order["payment_gateway_names"],
        processing_method: shopify_order["processing_method"],
        checkout_id: shopify_order["checkout_id"],
        location_id: shopify_order["location_id"],
        user_id: shopify_order["user_id"],
        checkout_token: shopify_order["checkout_token"],
        cart_token: shopify_order["cart_token"]
      }
    )
  end

  def self.from_woocommerce_data(wc_order)
    new(
      external_id: wc_order["id"].to_s,
      order_number: wc_order["number"],
      platform_name: "woocommerce",

      total_price: wc_order["total"]&.to_f,
      subtotal_price: calculate_wc_subtotal(wc_order),
      total_tax: wc_order["total_tax"]&.to_f,
      total_discounts: wc_order["discount_total"]&.to_f,
      total_shipping: wc_order["shipping_total"]&.to_f,
      currency: wc_order["currency"],

      financial_status: normalize_woocommerce_status(wc_order["status"]),
      fulfillment_status: derive_wc_fulfillment_status(wc_order),
      order_status: wc_order["status"],

      customer_external_id: wc_order["customer_id"]&.to_s,
      customer_email: wc_order["billing"]&.dig("email"),
      customer_phone: wc_order["billing"]&.dig("phone"),

      created_at: wc_order["date_created"],
      updated_at: wc_order["date_modified"],
      processed_at: wc_order["date_paid"],

      notes: wc_order["customer_note"],

      billing_address: normalize_wc_address(wc_order["billing"]),
      shipping_address: normalize_wc_address(wc_order["shipping"]),

      line_items: normalize_wc_line_items(wc_order["line_items"] || []),
      platform_data: {
        woocommerce_id: wc_order["id"],
        transaction_id: wc_order["transaction_id"],
        payment_method: wc_order["payment_method"],
        payment_method_title: wc_order["payment_method_title"],
        date_completed: wc_order["date_completed"],
        parent_id: wc_order["parent_id"],
        version: wc_order["version"]
      }
    )
  end

  def self.from_amazon_data(amazon_order)
    new(
      external_id: amazon_order["AmazonOrderId"],
      order_number: amazon_order["AmazonOrderId"],
      platform_name: "amazon",

      total_price: amazon_order["OrderTotal"]&.dig("Amount")&.to_f,
      currency: amazon_order["OrderTotal"]&.dig("CurrencyCode"),

      order_status: normalize_amazon_status(amazon_order["OrderStatus"]),

      customer_email: amazon_order["BuyerEmail"],

      created_at: amazon_order["PurchaseDate"],
      updated_at: amazon_order["LastUpdateDate"],

      shipping_address: normalize_amazon_address(amazon_order["ShippingAddress"]),

      platform_data: {
        amazon_order_id: amazon_order["AmazonOrderId"],
        marketplace_id: amazon_order["MarketplaceId"],
        sales_channel: amazon_order["SalesChannel"],
        order_type: amazon_order["OrderType"],
        fulfillment_channel: amazon_order["FulfillmentChannel"],
        ship_service_level: amazon_order["ShipServiceLevel"],
        number_of_items_shipped: amazon_order["NumberOfItemsShipped"],
        number_of_items_unshipped: amazon_order["NumberOfItemsUnshipped"]
      }
    )
  end

  # Status normalization helpers
  def self.normalize_shopify_financial_status(status)
    case status&.downcase
    when "pending" then "pending"
    when "authorized" then "authorized"
    when "partially_paid" then "partially_paid"
    when "paid" then "paid"
    when "partially_refunded" then "partially_refunded"
    when "refunded" then "refunded"
    when "voided" then "voided"
    else "pending"
    end
  end

  def self.normalize_shopify_fulfillment_status(status)
    case status&.downcase
    when nil then "unfulfilled"
    when "partial" then "partial"
    when "fulfilled" then "fulfilled"
    else "unfulfilled"
    end
  end

  def self.derive_order_status_from_shopify(order)
    return "cancelled" if order["cancelled_at"]
    return "shipped" if order["fulfillment_status"] == "fulfilled"
    return "processing" if order["financial_status"] == "paid"
    "pending"
  end

  def self.normalize_woocommerce_status(status)
    case status&.downcase
    when "pending" then "pending"
    when "processing" then "authorized"
    when "on-hold" then "pending"
    when "completed" then "paid"
    when "cancelled" then "voided"
    when "refunded" then "refunded"
    when "failed" then "voided"
    else "pending"
    end
  end

  def self.derive_wc_fulfillment_status(order)
    case order["status"]&.downcase
    when "completed" then "fulfilled"
    when "processing" then "partial"
    else "unfulfilled"
    end
  end

  def self.normalize_amazon_status(status)
    case status&.downcase
    when "pending" then "pending"
    when "unshipped" then "processing"
    when "partiallyshipped" then "processing"
    when "shipped" then "shipped"
    when "canceled" then "cancelled"
    else "pending"
    end
  end

  # Address normalization
  def self.normalize_address(address)
    return nil unless address

    {
      first_name: address["first_name"],
      last_name: address["last_name"],
      company: address["company"],
      address1: address["address1"],
      address2: address["address2"],
      city: address["city"],
      province: address["province"] || address["state"],
      country: address["country"],
      zip: address["zip"] || address["postcode"],
      phone: address["phone"],
      province_code: address["province_code"] || address["state"],
      country_code: address["country_code"]
    }.compact
  end

  def self.normalize_wc_address(address)
    return nil unless address

    {
      first_name: address["first_name"],
      last_name: address["last_name"],
      company: address["company"],
      address1: address["address_1"],
      address2: address["address_2"],
      city: address["city"],
      province: address["state"],
      country: address["country"],
      zip: address["postcode"],
      phone: address["phone"]
    }.compact
  end

  def self.normalize_amazon_address(address)
    return nil unless address

    {
      first_name: address["Name"]&.split(" ")&.first,
      last_name: address["Name"]&.split(" ", 2)&.last,
      address1: address["AddressLine1"],
      address2: address["AddressLine2"],
      city: address["City"],
      province: address["StateOrRegion"],
      country: address["CountryCode"],
      zip: address["PostalCode"],
      phone: address["Phone"]
    }.compact
  end

  # Line items normalization
  def self.normalize_shopify_line_items(line_items)
    line_items.map do |item|
      {
        external_id: item["id"]&.to_s,
        product_external_id: item["product_id"]&.to_s,
        variant_external_id: item["variant_id"]&.to_s,
        title: item["title"],
        quantity: item["quantity"]&.to_i,
        price: item["price"]&.to_f,
        total_discount: item["total_discount"]&.to_f,
        sku: item["sku"],
        vendor: item["vendor"],
        fulfillment_status: item["fulfillment_status"]
      }.compact
    end
  end

  def self.normalize_wc_line_items(line_items)
    line_items.map do |item|
      {
        external_id: item["id"]&.to_s,
        product_external_id: item["product_id"]&.to_s,
        variant_external_id: item["variation_id"]&.to_s,
        title: item["name"],
        quantity: item["quantity"]&.to_i,
        price: item["price"]&.to_f,
        total: item["total"]&.to_f,
        sku: item["sku"]
      }.compact
    end
  end

  def self.calculate_wc_subtotal(order)
    line_items = order["line_items"] || []
    line_items.sum { |item| item["total"]&.to_f || 0 }
  end
end
