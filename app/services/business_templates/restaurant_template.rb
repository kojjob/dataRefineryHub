# frozen_string_literal: true

module BusinessTemplates
  class RestaurantTemplate < BaseTemplate
    protected
    
    def template_name
      'restaurant'
    end
    
    def create_data_sources
      # POS System Integration
      create_configured_data_source(
        name: "POS System",
        source_type: "square",
        configuration: {
          sync_type: "orders",
          include_items: true,
          include_customers: true,
          include_payments: true,
          include_inventory: true
        }
      )
      
      # Online Ordering Integration
      create_configured_data_source(
        name: "Online Orders",
        source_type: "doordash",
        configuration: {
          sync_type: "orders",
          include_delivery_data: true
        }
      )
      
      # Reservation System
      create_configured_data_source(
        name: "Reservations",
        source_type: "opentable",
        configuration: {
          sync_type: "reservations",
          include_customer_data: true,
          include_table_data: true
        }
      )
      
      # Accounting Integration
      create_configured_data_source(
        name: "Accounting",
        source_type: "quickbooks",
        configuration: {
          sync_type: "all",
          include_invoices: true,
          include_expenses: true,
          include_inventory: true
        }
      )
    end
    
    def create_pipelines
      # Daily Sales Pipeline
      create_etl_pipeline(
        name: "Daily Sales Analysis",
        description: "Process daily sales data from POS and online orders",
        steps: [
          {
            name: "Extract Sales Data",
            type: "extract",
            configuration: {
              sources: ["POS System", "Online Orders"],
              fields: ["order_id", "timestamp", "total", "items", "payment_method"]
            }
          },
          {
            name: "Transform Sales Metrics",
            type: "transform",
            configuration: {
              aggregations: {
                daily_revenue: "sum(total)",
                order_count: "count(order_id)",
                average_ticket: "avg(total)"
              },
              grouping: ["date", "order_source"]
            }
          },
          {
            name: "Load to Analytics",
            type: "load",
            configuration: {
              destination: "analytics_warehouse",
              table: "daily_sales_metrics"
            }
          }
        ]
      )
      
      # Menu Performance Pipeline
      create_etl_pipeline(
        name: "Menu Item Performance",
        description: "Analyze best and worst performing menu items",
        steps: [
          {
            name: "Extract Item Sales",
            type: "extract",
            configuration: {
              sources: ["POS System"],
              fields: ["item_name", "category", "quantity", "revenue", "cost"]
            }
          },
          {
            name: "Calculate Item Metrics",
            type: "transform",
            configuration: {
              calculations: {
                profit_margin: "(revenue - cost) / revenue",
                popularity_rank: "rank() over (order by quantity desc)"
              }
            }
          },
          {
            name: "Identify Opportunities",
            type: "analyze",
            configuration: {
              rules: {
                low_margin_high_volume: "profit_margin < 0.3 AND popularity_rank <= 10",
                high_margin_low_volume: "profit_margin > 0.7 AND popularity_rank > 20"
              }
            }
          }
        ]
      )
      
      # Labor Cost Analysis Pipeline
      create_etl_pipeline(
        name: "Labor Cost Optimization",
        description: "Analyze labor costs vs revenue by hour and day",
        steps: [
          {
            name: "Extract Labor Data",
            type: "extract",
            configuration: {
              sources: ["POS System", "Accounting"],
              fields: ["employee_hours", "hourly_rate", "shift_time", "revenue_per_hour"]
            }
          },
          {
            name: "Calculate Labor Metrics",
            type: "transform",
            configuration: {
              calculations: {
                labor_cost_percentage: "sum(employee_hours * hourly_rate) / sum(revenue_per_hour)",
                optimal_staffing: "round(revenue_per_hour / 150)" # $150 revenue per staff hour target
              }
            }
          },
          {
            name: "Generate Recommendations",
            type: "analyze",
            configuration: {
              optimization_targets: {
                labor_cost_percentage: 0.30,
                service_quality_threshold: 0.85
              }
            }
          }
        ]
      )
    end
    
    def configure_dashboards
      super
      
      # Restaurant-specific dashboard
      Dashboard.create!(
        organization: organization,
        name: "Restaurant Operations",
        dashboard_type: "operations",
        configuration: {
          widgets: [
            { 
              type: "metric", 
              title: "Today's Revenue", 
              metric: "revenue_today",
              format: "currency",
              comparison: "yesterday"
            },
            { 
              type: "metric", 
              title: "Table Turnover", 
              metric: "table_turnover_rate",
              format: "decimal",
              target: 2.5
            },
            { 
              type: "metric", 
              title: "Labor Cost %", 
              metric: "labor_cost_percentage",
              format: "percentage",
              target: 30,
              alert_threshold: 35
            },
            { 
              type: "chart", 
              title: "Hourly Sales", 
              chart_type: "bar",
              metric: "sales_by_hour",
              group_by: "hour"
            },
            { 
              type: "table", 
              title: "Top Menu Items", 
              data_source: "menu_performance",
              columns: ["item", "quantity", "revenue", "margin"],
              limit: 10
            },
            {
              type: "heatmap",
              title: "Peak Hours",
              metric: "revenue_by_hour_day",
              x_axis: "hour",
              y_axis: "day_of_week"
            }
          ]
        }
      )
    end
    
    def setup_automated_reports
      super
      
      # Daily closing report
      DeliveryPreference.create!(
        user: user,
        organization: organization,
        report_type: "daily_summary",
        channel: "whatsapp",
        format: "text",
        schedule: "daily",
        delivery_time: "23:00", # End of day
        timezone: user.timezone || "Eastern Time (US & Canada)",
        active: true,
        options: {
          include_metrics: [
            "total_revenue",
            "order_count",
            "average_ticket",
            "labor_cost_percentage",
            "top_items",
            "low_stock_items"
          ]
        }
      )
      
      # Weekly performance review
      DeliveryPreference.create!(
        user: user,
        organization: organization,
        report_type: "weekly_report",
        channel: "email",
        format: "pdf",
        schedule: "weekly",
        delivery_time: "10:00",
        timezone: user.timezone || "Eastern Time (US & Canada)",
        active: true,
        options: {
          sections: [
            "revenue_trends",
            "menu_performance",
            "labor_analysis",
            "customer_feedback",
            "inventory_alerts"
          ]
        }
      )
    end
    
    def create_sample_data
      # Create sample menu items
      menu_items = [
        { name: "Burger Deluxe", category: "Mains", price: 15.99, cost: 5.50 },
        { name: "Caesar Salad", category: "Starters", price: 9.99, cost: 2.50 },
        { name: "Margherita Pizza", category: "Mains", price: 14.99, cost: 4.00 },
        { name: "Chocolate Cake", category: "Desserts", price: 7.99, cost: 2.00 },
        { name: "House Wine", category: "Beverages", price: 8.99, cost: 2.50 }
      ]
      
      # Generate 30 days of sample sales data
      30.days.ago.to_date.upto(Date.current) do |date|
        # Vary order count by day of week
        base_orders = case date.wday
                      when 0, 6 then 150 # Weekend
                      when 5 then 120     # Friday
                      else 80             # Weekday
                      end
        
        order_count = base_orders + rand(-20..20)
        
        order_count.times do
          # Create order
          order_time = date.to_time + rand(10..22).hours + rand(0..59).minutes
          items_count = rand(1..4)
          
          order_items = menu_items.sample(items_count).map do |item|
            quantity = rand(1..3)
            {
              item_name: item[:name],
              category: item[:category],
              quantity: quantity,
              unit_price: item[:price],
              total_price: item[:price] * quantity,
              cost: item[:cost] * quantity
            }
          end
          
          order_total = order_items.sum { |i| i[:total_price] }
          
          organization.raw_data_records.create!(
            source_type: "pos_system",
            record_type: "order",
            external_id: SecureRandom.uuid,
            data: {
              order_id: SecureRandom.hex(8),
              timestamp: order_time,
              items: order_items,
              subtotal: order_total,
              tax: (order_total * 0.08).round(2),
              total: (order_total * 1.08).round(2),
              payment_method: ["cash", "credit", "debit"].sample,
              server: ["Alice", "Bob", "Charlie", "Diana"].sample,
              table_number: rand(1..20)
            },
            recorded_at: order_time
          )
        end
      end
      
      Rails.logger.info "Created sample restaurant data for #{organization.name}"
    end
  end
end