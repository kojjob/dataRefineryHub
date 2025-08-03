# frozen_string_literal: true

module BusinessTemplates
  class EcommerceTemplate < BaseTemplate
    protected
    
    def template_name
      'ecommerce'
    end
    
    def create_data_sources
      # E-commerce Platform
      create_configured_data_source(
        name: "Online Store",
        source_type: "shopify",
        configuration: {
          sync_type: "all",
          include_orders: true,
          include_customers: true,
          include_products: true,
          include_inventory: true,
          include_abandoned_carts: true
        }
      )
      
      # Payment Gateway
      create_configured_data_source(
        name: "Payment Processing",
        source_type: "stripe",
        configuration: {
          sync_type: "transactions",
          include_charges: true,
          include_refunds: true,
          include_disputes: true,
          include_payouts: true
        }
      )
      
      # Email Marketing
      create_configured_data_source(
        name: "Email Marketing",
        source_type: "mailchimp",
        configuration: {
          sync_type: "all",
          include_campaigns: true,
          include_subscribers: true,
          include_engagement: true
        }
      )
      
      # Google Analytics
      create_configured_data_source(
        name: "Website Analytics",
        source_type: "google_analytics",
        configuration: {
          sync_type: "enhanced_ecommerce",
          include_traffic: true,
          include_conversions: true,
          include_behavior: true
        }
      )
      
      # Advertising Platforms
      create_configured_data_source(
        name: "Google Ads",
        source_type: "google_ads",
        configuration: {
          sync_type: "campaigns",
          include_performance: true,
          include_costs: true,
          include_conversions: true
        }
      )
    end
    
    def create_pipelines
      # Sales Funnel Pipeline
      create_etl_pipeline(
        name: "Sales Funnel Analysis",
        description: "Track customer journey from visit to purchase",
        steps: [
          {
            name: "Extract Funnel Data",
            type: "extract",
            configuration: {
              sources: ["Website Analytics", "Online Store"],
              fields: ["session_id", "user_id", "events", "conversions", "revenue"]
            }
          },
          {
            name: "Build Funnel Metrics",
            type: "transform",
            configuration: {
              funnel_stages: {
                visits: "count(distinct session_id)",
                product_views: "count(event = 'view_item')",
                add_to_cart: "count(event = 'add_to_cart')",
                checkout_started: "count(event = 'begin_checkout')",
                purchases: "count(event = 'purchase')"
              },
              conversion_rates: {
                visit_to_view: "product_views / visits",
                view_to_cart: "add_to_cart / product_views",
                cart_to_checkout: "checkout_started / add_to_cart",
                checkout_to_purchase: "purchases / checkout_started"
              }
            }
          },
          {
            name: "Identify Drop-offs",
            type: "analyze",
            configuration: {
              bottlenecks: {
                cart_abandonment: "add_to_cart - checkout_started",
                checkout_abandonment: "checkout_started - purchases"
              }
            }
          }
        ]
      )
      
      # Customer Lifetime Value Pipeline
      create_etl_pipeline(
        name: "Customer LTV Analysis",
        description: "Calculate and predict customer lifetime value",
        steps: [
          {
            name: "Extract Customer Data",
            type: "extract",
            configuration: {
              sources: ["Online Store", "Email Marketing"],
              fields: ["customer_id", "orders", "total_spent", "first_purchase", "last_purchase"]
            }
          },
          {
            name: "Calculate LTV Metrics",
            type: "transform",
            configuration: {
              calculations: {
                purchase_frequency: "count(orders) / months_since_first_purchase",
                average_order_value: "total_spent / count(orders)",
                customer_lifespan: "avg(last_purchase - first_purchase)",
                clv: "average_order_value * purchase_frequency * customer_lifespan"
              },
              segments: {
                vip: "clv > 1000",
                regular: "clv between 100 and 1000",
                new: "count(orders) = 1"
              }
            }
          },
          {
            name: "Predict Future Value",
            type: "ml_predict",
            configuration: {
              model: "customer_ltv_predictor",
              features: ["purchase_frequency", "aov", "days_since_last_purchase"],
              target: "next_12_months_value"
            }
          }
        ]
      )
      
      # Marketing ROI Pipeline
      create_etl_pipeline(
        name: "Marketing Performance",
        description: "Track ROI across all marketing channels",
        steps: [
          {
            name: "Extract Marketing Data",
            type: "extract",
            configuration: {
              sources: ["Google Ads", "Email Marketing", "Website Analytics"],
              fields: ["channel", "campaign", "cost", "impressions", "clicks", "conversions", "revenue"]
            }
          },
          {
            name: "Calculate ROI Metrics",
            type: "transform",
            configuration: {
              calculations: {
                ctr: "clicks / impressions",
                conversion_rate: "conversions / clicks",
                cpa: "cost / conversions",
                roas: "revenue / cost",
                profit: "revenue - cost"
              },
              attribution_model: "last_click" # Can be first_click, linear, time_decay
            }
          },
          {
            name: "Optimize Budget Allocation",
            type: "analyze",
            configuration: {
              optimization_goals: {
                target_roas: 4.0,
                max_cpa: 50,
                budget_constraint: "monthly"
              }
            }
          }
        ]
      )
    end
    
    def configure_dashboards
      super
      
      # E-commerce Operations Dashboard
      Dashboard.create!(
        organization: organization,
        name: "E-commerce Performance",
        dashboard_type: "ecommerce",
        configuration: {
          widgets: [
            {
              type: "metric",
              title: "Today's Revenue",
              metric: "revenue_today",
              format: "currency",
              comparison: "yesterday",
              sparkline: true
            },
            {
              type: "metric",
              title: "Conversion Rate",
              metric: "conversion_rate",
              format: "percentage",
              target: 3.5,
              comparison: "last_week"
            },
            {
              type: "metric",
              title: "Cart Abandonment",
              metric: "cart_abandonment_rate",
              format: "percentage",
              target: 65,
              inverse: true # Lower is better
            },
            {
              type: "metric",
              title: "Average Order Value",
              metric: "aov",
              format: "currency",
              comparison: "last_month"
            },
            {
              type: "funnel",
              title: "Sales Funnel",
              stages: ["Visits", "Product Views", "Add to Cart", "Checkout", "Purchase"],
              metric: "funnel_conversion"
            },
            {
              type: "chart",
              title: "Revenue by Channel",
              chart_type: "pie",
              metric: "revenue_by_channel"
            },
            {
              type: "table",
              title: "Top Products",
              data_source: "product_performance",
              columns: ["product", "units_sold", "revenue", "conversion_rate"],
              limit: 10
            },
            {
              type: "map",
              title: "Orders by Location",
              metric: "orders_by_state",
              map_type: "usa"
            }
          ]
        }
      )
      
      # Marketing Dashboard
      Dashboard.create!(
        organization: organization,
        name: "Marketing Analytics",
        dashboard_type: "marketing",
        configuration: {
          widgets: [
            {
              type: "metric",
              title: "Marketing Spend",
              metric: "total_ad_spend",
              format: "currency",
              period: "mtd"
            },
            {
              type: "metric",
              title: "ROAS",
              metric: "return_on_ad_spend",
              format: "decimal",
              target: 4.0,
              comparison: "last_month"
            },
            {
              type: "chart",
              title: "Channel Performance",
              chart_type: "bar",
              metrics: ["cost", "revenue", "roas"],
              group_by: "channel"
            },
            {
              type: "table",
              title: "Campaign Performance",
              data_source: "campaign_metrics",
              columns: ["campaign", "spend", "conversions", "cpa", "roas"],
              sortable: true
            }
          ]
        }
      )
    end
    
    def setup_automated_reports
      super
      
      # Morning metrics via WhatsApp
      DeliveryPreference.create!(
        user: user,
        organization: organization,
        report_type: "daily_summary",
        channel: "whatsapp",
        format: "text",
        schedule: "daily",
        delivery_time: "08:00",
        timezone: user.timezone || "Eastern Time (US & Canada)",
        active: true,
        options: {
          metrics: [
            "yesterday_revenue",
            "orders_count",
            "conversion_rate",
            "top_products",
            "abandoned_carts_value"
          ]
        }
      )
      
      # Weekly marketing report
      DeliveryPreference.create!(
        user: user,
        organization: organization,
        report_type: "weekly_report",
        channel: "email",
        format: "pdf",
        schedule: "weekly",
        delivery_time: "09:00",
        timezone: user.timezone || "Eastern Time (US & Canada)",
        active: true,
        options: {
          sections: [
            "executive_summary",
            "channel_performance",
            "product_performance",
            "customer_segments",
            "marketing_roi"
          ]
        }
      )
      
      # Real-time alerts
      DeliveryPreference.create!(
        user: user,
        organization: organization,
        report_type: "real_time_alert",
        channel: "sms",
        format: "text",
        schedule: "", # On-demand
        active: true,
        options: {
          alert_types: [
            "high_value_order", # Orders over $500
            "stock_out",
            "payment_failure",
            "unusual_activity"
          ]
        }
      )
    end
    
    def create_sample_data
      # Create sample products
      products = [
        { name: "Wireless Headphones", sku: "WH-001", price: 79.99, category: "Electronics", stock: 150 },
        { name: "Yoga Mat", sku: "YM-002", price: 29.99, category: "Fitness", stock: 200 },
        { name: "Coffee Maker", sku: "CM-003", price: 149.99, category: "Home", stock: 75 },
        { name: "Running Shoes", sku: "RS-004", price: 89.99, category: "Footwear", stock: 120 },
        { name: "Laptop Stand", sku: "LS-005", price: 49.99, category: "Office", stock: 180 }
      ]
      
      # Generate 60 days of e-commerce data
      60.days.ago.to_date.upto(Date.current) do |date|
        # Website traffic (higher on weekends)
        daily_sessions = case date.wday
                        when 0, 6 then rand(1500..2000)
                        else rand(800..1200)
                        end
        
        # Generate sessions and conversions
        daily_sessions.times do
          session_time = date.to_time + rand(0..23).hours + rand(0..59).minutes
          session_id = SecureRandom.uuid
          
          # Funnel progression probabilities
          viewed_product = rand < 0.6
          added_to_cart = viewed_product && rand < 0.3
          started_checkout = added_to_cart && rand < 0.7
          completed_purchase = started_checkout && rand < 0.85
          
          if completed_purchase
            # Create order
            items = products.sample(rand(1..3))
            order_items = items.map do |product|
              quantity = rand(1..2)
              {
                product_name: product[:name],
                sku: product[:sku],
                quantity: quantity,
                unit_price: product[:price],
                total: product[:price] * quantity
              }
            end
            
            subtotal = order_items.sum { |i| i[:total] }
            shipping = subtotal > 50 ? 0 : 9.99
            tax = (subtotal * 0.08).round(2)
            total = subtotal + shipping + tax
            
            organization.raw_data_records.create!(
              source_type: "shopify",
              record_type: "order",
              external_id: SecureRandom.uuid,
              data: {
                order_number: "##{rand(10000..99999)}",
                customer_email: "customer#{rand(1000)}@example.com",
                timestamp: session_time,
                items: order_items,
                subtotal: subtotal,
                shipping: shipping,
                tax: tax,
                total: total,
                payment_method: ["credit_card", "paypal", "apple_pay"].sample,
                shipping_address: {
                  state: ["CA", "NY", "TX", "FL", "WA"].sample,
                  country: "US"
                },
                utm_source: ["google", "facebook", "email", "direct", "instagram"].sample,
                device_type: ["mobile", "desktop", "tablet"].sample
              },
              recorded_at: session_time
            )
          elsif added_to_cart && !completed_purchase
            # Record abandoned cart
            organization.raw_data_records.create!(
              source_type: "shopify",
              record_type: "abandoned_cart",
              external_id: session_id,
              data: {
                session_id: session_id,
                timestamp: session_time,
                products: products.sample(rand(1..2)).map { |p| p[:name] },
                cart_value: products.sample(rand(1..2)).sum { |p| p[:price] },
                abandonment_reason: ["shipping_cost", "payment_issue", "comparison_shopping", "unknown"].sample
              },
              recorded_at: session_time
            )
          end
        end
      end
      
      Rails.logger.info "Created sample e-commerce data for #{organization.name}"
    end
  end
end