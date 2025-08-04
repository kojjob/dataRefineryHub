# Service to generate sample data for testing ETL pipelines
class SampleDataGeneratorService
  attr_reader :organization, :logger

  def initialize(organization)
    @organization = organization
    @logger = Rails.logger
  end

  # Create sample data sources with realistic configurations
  def create_sample_data_sources
    sources = []

    # 1. Shopify E-commerce Data Source
    sources << create_shopify_data_source

    # 2. PostgreSQL Database Data Source
    sources << create_postgresql_data_source

    # 3. CSV File Data Source
    sources << create_csv_data_source

    # 4. API Data Source (Generic REST API)
    sources << create_api_data_source

    # 5. Google Sheets Data Source
    sources << create_google_sheets_data_source

    sources.compact
  end

  # Create sample ETL pipelines
  def create_sample_pipelines
    pipelines = []

    # 1. E-commerce Analytics Pipeline
    pipelines << create_ecommerce_pipeline

    # 2. Customer 360 Pipeline
    pipelines << create_customer_360_pipeline

    # 3. Financial Reporting Pipeline
    pipelines << create_financial_pipeline

    # 4. Real-time Event Processing Pipeline
    pipelines << create_realtime_pipeline

    pipelines.compact
  end

  private

  def create_shopify_data_source
    DataSource.create!(
      organization: organization,
      name: "Demo Shopify Store",
      source_type: "shopify",
      description: "Sample e-commerce data from Shopify store",
      status: "connected",
      sync_frequency: "hourly",
      configuration: {
        shop_domain: "demo-store.myshopify.com",
        api_version: "2024-01",
        include_orders: true,
        include_products: true,
        include_customers: true,
        include_inventory: true
      },
      credentials: {
        access_token: "demo_access_token_encrypted",
        api_key: "demo_api_key_encrypted",
        api_secret: "demo_api_secret_encrypted"
      },
      metadata: {
        demo: true,
        sample_data_available: true,
        estimated_records: {
          orders: 5000,
          customers: 2000,
          products: 500,
          inventory_levels: 2000
        }
      }
    )
  rescue => e
    logger.error "Failed to create Shopify data source: #{e.message}"
    nil
  end

  def create_postgresql_data_source
    DataSource.create!(
      organization: organization,
      name: "Analytics Database",
      source_type: "postgresql",
      description: "PostgreSQL database with business analytics data",
      status: "connected",
      sync_frequency: "daily",
      configuration: {
        host: "demo-analytics.db.internal",
        port: 5432,
        database: "analytics_demo",
        schema: "public",
        tables: [ "sales_transactions", "customer_segments", "product_performance" ],
        use_streaming: true,
        batch_size: 10000
      },
      credentials: {
        username: "demo_reader",
        password: "encrypted_demo_password"
      },
      metadata: {
        demo: true,
        sample_data_available: true,
        table_info: {
          sales_transactions: { row_count: 50000, columns: 15 },
          customer_segments: { row_count: 5000, columns: 8 },
          product_performance: { row_count: 1000, columns: 12 }
        }
      }
    )
  rescue => e
    logger.error "Failed to create PostgreSQL data source: #{e.message}"
    nil
  end

  def create_csv_data_source
    # Create sample CSV file
    csv_path = Rails.root.join("tmp", "sample_data", "sales_data.csv")
    FileUtils.mkdir_p(File.dirname(csv_path))

    # Generate sample CSV data
    CSV.open(csv_path, "w") do |csv|
      csv << [ "order_id", "customer_id", "product_id", "quantity", "price", "order_date", "region" ]

      1000.times do |i|
        csv << [
          "ORD-#{i + 1}",
          "CUST-#{rand(1..200)}",
          "PROD-#{rand(1..50)}",
          rand(1..10),
          (rand(10.0..500.0).round(2)),
          (Date.today - rand(0..365)).to_s,
          %w[North South East West].sample
        ]
      end
    end

    DataSource.create!(
      organization: organization,
      name: "Sales Data CSV",
      source_type: "csv",
      description: "Historical sales data in CSV format",
      status: "connected",
      sync_frequency: "manual",
      configuration: {
        source_type: "file",
        file_path: csv_path.to_s,
        delimiter: ",",
        headers: true,
        encoding: "UTF-8",
        auto_detect: true
      },
      metadata: {
        demo: true,
        sample_data_available: true,
        file_info: {
          size: File.size(csv_path),
          row_count: 1001,
          columns: 7
        }
      }
    )
  rescue => e
    logger.error "Failed to create CSV data source: #{e.message}"
    nil
  end

  def create_api_data_source
    DataSource.create!(
      organization: organization,
      name: "REST API - Customer Service",
      source_type: "api",
      description: "Customer service data via REST API",
      status: "connected",
      sync_frequency: "realtime",
      configuration: {
        api_type: "rest",
        base_url: "https://api.demo-service.com/v1",
        endpoints: [
          { name: "tickets", path: "/tickets", method: "GET" },
          { name: "customers", path: "/customers", method: "GET" },
          { name: "interactions", path: "/interactions", method: "GET" }
        ],
        auth_type: "bearer",
        pagination_type: "offset",
        rate_limit: 100,
        timeout: 30
      },
      credentials: {
        api_key: "demo_api_key_encrypted",
        bearer_token: "demo_bearer_token_encrypted"
      },
      metadata: {
        demo: true,
        sample_data_available: true,
        api_version: "v1",
        rate_limits: {
          per_hour: 1000,
          per_minute: 100
        }
      }
    )
  rescue => e
    logger.error "Failed to create API data source: #{e.message}"
    nil
  end

  def create_google_sheets_data_source
    DataSource.create!(
      organization: organization,
      name: "Marketing Campaign Data",
      source_type: "google_sheets",
      description: "Marketing campaign performance data from Google Sheets",
      status: "connected",
      sync_frequency: "hourly",
      configuration: {
        spreadsheet_id: "demo_spreadsheet_id",
        sheet_names: [ "Campaign Performance", "Budget Tracking", "ROI Analysis" ],
        range: "A1:Z1000",
        include_headers: true
      },
      credentials: {
        service_account_json: {
          type: "service_account",
          project_id: "demo-project",
          private_key_id: "demo_key_id",
          private_key: "demo_private_key_encrypted"
        }.to_json
      },
      metadata: {
        demo: true,
        sample_data_available: true,
        sheets_info: {
          'Campaign Performance': { rows: 500, columns: 15 },
          'Budget Tracking': { rows: 200, columns: 8 },
          'ROI Analysis': { rows: 100, columns: 10 }
        }
      }
    )
  rescue => e
    logger.error "Failed to create Google Sheets data source: #{e.message}"
    nil
  end

  def create_ecommerce_pipeline
    user = organization.users.first

    Pipeline.create!(
      organization: organization,
      created_by: user,
      name: "E-commerce Analytics Pipeline",
      description: "Comprehensive e-commerce data pipeline combining Shopify, CSV, and database sources",
      pipeline_type: "etl",
      status: "active",

      source_config: {
        type: "multi_source",
        sources: [
          {
            data_source_name: "Demo Shopify Store",
            extract_config: {
              record_types: [ "orders", "customers", "products" ],
              incremental: true
            }
          },
          {
            data_source_name: "Sales Data CSV",
            extract_config: {
              full_extract: true
            }
          }
        ]
      },

      transformation_rules: [
        {
          type: "join",
          name: "Join orders with customer data",
          left_dataset: "shopify_orders",
          right_dataset: "shopify_customers",
          join_keys: { left: "customer_id", right: "id" },
          join_type: "left"
        },
        {
          type: "calculated_field",
          name: "Calculate customer lifetime value",
          field_name: "lifetime_value",
          expression: "sum(order_total) group by customer_id"
        },
        {
          type: "aggregate",
          name: "Daily sales summary",
          group_by: [ "date", "product_category" ],
          aggregations: [
            { field: "order_total", function: "sum", alias: "daily_revenue" },
            { field: "order_id", function: "count", alias: "order_count" }
          ]
        },
        {
          type: "data_quality",
          name: "Validate order amounts",
          rules: [
            { field: "order_total", condition: "greater_than", value: 0 },
            { field: "customer_email", condition: "is_valid_email" }
          ]
        }
      ],

      destination_config: {
        type: "data_warehouse",
        warehouse_type: "internal",
        schema: "ecommerce_analytics",
        tables: {
          'fact_orders': { mode: "append" },
          'dim_customers': { mode: "merge", merge_keys: [ "customer_id" ] },
          'dim_products': { mode: "replace" },
          'agg_daily_sales': { mode: "merge", merge_keys: [ "date", "product_category" ] }
        }
      },

      schedule_config: {
        type: "cron",
        cron_expression: "0 */2 * * *", # Every 2 hours
        timezone: "UTC"
      },

      notification_settings: {
        on_success: { email: true, webhook: false },
        on_failure: { email: true, webhook: true, slack: true },
        recipients: [ user.email ]
      }
    )
  rescue => e
    logger.error "Failed to create e-commerce pipeline: #{e.message}"
    nil
  end

  def create_customer_360_pipeline
    user = organization.users.first

    Pipeline.create!(
      organization: organization,
      created_by: user,
      name: "Customer 360 View Pipeline",
      description: "Unified customer view combining data from multiple sources",
      pipeline_type: "elt",
      status: "active",

      source_config: {
        type: "multi_source",
        sources: [
          { data_source_name: "Demo Shopify Store" },
          { data_source_name: "REST API - Customer Service" },
          { data_source_name: "Analytics Database" }
        ]
      },

      transformation_rules: [
        {
          type: "post_load_sql",
          name: "Create unified customer view",
          sql: <<-SQL
            CREATE OR REPLACE VIEW customer_360 AS
            WITH customer_base AS (
              SELECT DISTINCT
                COALESCE(s.customer_id, cs.customer_id) as unified_customer_id,
                s.email,
                s.first_name,
                s.last_name,
                s.created_at as customer_since
              FROM shopify_customers s
              FULL OUTER JOIN customer_service_customers cs
                ON s.email = cs.email
            ),
            customer_metrics AS (
              SELECT#{' '}
                customer_id,
                COUNT(DISTINCT order_id) as total_orders,
                SUM(order_total) as lifetime_value,
                MAX(order_date) as last_order_date,
                AVG(order_total) as avg_order_value
              FROM shopify_orders
              GROUP BY customer_id
            ),
            service_metrics AS (
              SELECT#{' '}
                customer_id,
                COUNT(DISTINCT ticket_id) as support_tickets,
                AVG(resolution_time_hours) as avg_resolution_time,
                MAX(created_at) as last_contact_date
              FROM customer_service_tickets
              GROUP BY customer_id
            )
            SELECT#{' '}
              cb.*,
              COALESCE(cm.total_orders, 0) as total_orders,
              COALESCE(cm.lifetime_value, 0) as lifetime_value,
              cm.last_order_date,
              cm.avg_order_value,
              COALESCE(sm.support_tickets, 0) as support_tickets,
              sm.avg_resolution_time,
              sm.last_contact_date,
              CASE#{' '}
                WHEN cm.lifetime_value > 1000 THEN 'VIP'
                WHEN cm.lifetime_value > 100 THEN 'Regular'
                ELSE 'New'
              END as customer_segment
            FROM customer_base cb
            LEFT JOIN customer_metrics cm ON cb.unified_customer_id = cm.customer_id
            LEFT JOIN service_metrics sm ON cb.unified_customer_id = sm.customer_id
          SQL
        }
      ],

      destination_config: {
        type: "database",
        database_type: "postgresql",
        connection_string: "postgresql://analytics:password@localhost/warehouse",
        schema: "customer_analytics"
      },

      schedule_config: {
        type: "cron",
        cron_expression: "0 6 * * *", # Daily at 6 AM
        timezone: "UTC"
      }
    )
  rescue => e
    logger.error "Failed to create customer 360 pipeline: #{e.message}"
    nil
  end

  def create_financial_pipeline
    user = organization.users.first

    Pipeline.create!(
      organization: organization,
      created_by: user,
      name: "Financial Reporting Pipeline",
      description: "Daily financial metrics and reporting pipeline",
      pipeline_type: "etl",
      status: "active",

      source_config: {
        type: "database",
        data_source_name: "Analytics Database",
        query: <<-SQL.squish,
          SELECT#{' '}
            t.*,
            p.category,
            p.cost,
            c.segment
          FROM sales_transactions t
          JOIN products p ON t.product_id = p.id
          JOIN customers c ON t.customer_id = c.id
          WHERE t.transaction_date >= :start_date
        SQL
        parameters: {
          start_date: "{{ yesterday }}"
        }
      },

      transformation_rules: [
        {
          type: "calculated_field",
          name: "Calculate profit margin",
          field_name: "profit_margin",
          expression: "(price - cost) / price * 100"
        },
        {
          type: "pivot",
          name: "Revenue by category and segment",
          index_columns: [ "transaction_date" ],
          pivot_column: "category",
          value_column: "revenue",
          aggregation: "sum"
        },
        {
          type: "running_total",
          name: "Cumulative revenue",
          partition_by: [ "category" ],
          order_by: [ "transaction_date" ],
          field: "daily_revenue",
          alias: "cumulative_revenue"
        }
      ],

      destination_config: {
        type: "multi_destination",
        destinations: [
          {
            type: "database",
            name: "Financial data warehouse",
            table: "financial_metrics"
          },
          {
            type: "file",
            name: "Daily report export",
            format: "excel",
            path: "/reports/financial/daily_{{ date }}.xlsx"
          }
        ]
      },

      schedule_config: {
        type: "cron",
        cron_expression: "30 7 * * *", # Daily at 7:30 AM
        timezone: "America/New_York"
      },

      dependencies: [ "E-commerce Analytics Pipeline" ]
    )
  rescue => e
    logger.error "Failed to create financial pipeline: #{e.message}"
    nil
  end

  def create_realtime_pipeline
    user = organization.users.first

    Pipeline.create!(
      organization: organization,
      created_by: user,
      name: "Real-time Customer Events",
      description: "Stream processing for real-time customer behavior analysis",
      pipeline_type: "streaming",
      status: "draft",

      source_config: {
        type: "streaming",
        platform: "webhook",
        endpoint: "/webhooks/customer-events",
        event_types: [ "page_view", "add_to_cart", "purchase", "support_ticket" ]
      },

      transformation_rules: [
        {
          type: "filter",
          name: "Remove test events",
          condition: {
            field: "environment",
            operator: "!=",
            value: "test"
          }
        },
        {
          type: "enrich",
          name: "Add customer segment",
          lookup_table: "dim_customers",
          lookup_key: "customer_id",
          fields_to_add: [ "segment", "lifetime_value" ]
        },
        {
          type: "window_aggregate",
          name: "Session metrics",
          window_type: "session",
          timeout_minutes: 30,
          group_by: [ "customer_id", "session_id" ],
          aggregations: [
            { field: "event_id", function: "count", alias: "events_in_session" },
            { field: "timestamp", function: "min", alias: "session_start" },
            { field: "timestamp", function: "max", alias: "session_end" }
          ]
        },
        {
          type: "anomaly_detection",
          name: "Detect unusual behavior",
          method: "isolation_forest",
          features: [ "events_per_minute", "unique_pages", "cart_value" ],
          threshold: 0.95
        }
      ],

      destination_config: {
        type: "multi_destination",
        destinations: [
          {
            type: "streaming",
            platform: "websocket",
            channel: "real-time-dashboard"
          },
          {
            type: "database",
            name: "Event store",
            table: "customer_events",
            mode: "append"
          },
          {
            type: "alert",
            condition: "anomaly_score > 0.95",
            channels: [ "email", "slack" ]
          }
        ]
      },

      error_handling_strategy: "dead_letter_queue",

      retry_policy: {
        max_retries: 3,
        backoff_type: "exponential",
        initial_delay: 1000,
        max_delay: 30000
      }
    )
  rescue => e
    logger.error "Failed to create real-time pipeline: #{e.message}"
    nil
  end

  # Generate sample execution history
  def create_sample_executions(pipeline)
    10.times do |i|
      start_time = (i + 1).days.ago
      duration = rand(60..600) # 1-10 minutes
      status = i == 0 ? "running" : [ "completed", "completed", "completed", "failed" ].sample

      PipelineExecution.create!(
        organization: organization,
        pipeline_name: pipeline.name,
        execution_id: SecureRandom.uuid,
        status: status,
        execution_mode: "automatic",
        started_at: start_time,
        completed_at: status == "running" ? nil : start_time + duration.seconds,
        progress: status == "running" ? rand(20..80) : 100,
        current_stage: status == "running" ? [ "extraction", "transformation", "loading" ].sample : "completed",
        user: pipeline.created_by,
        parameters: {
          start_date: start_time.to_date.to_s,
          full_refresh: false
        },
        result_summary: {
          rows_extracted: rand(1000..50000),
          rows_transformed: rand(900..49000),
          rows_loaded: rand(900..49000),
          duration_seconds: duration,
          data_quality_score: rand(85..100)
        },
        error_details: status == "failed" ? {
          error_type: [ "ConnectionError", "DataValidationError", "TransformationError" ].sample,
          error_message: "Sample error for demonstration",
          failed_at_stage: [ "extraction", "transformation", "loading" ].sample
        } : nil
      )
    end
  end
end
