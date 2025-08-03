# Sample ETL Pipeline Configuration
puts "Creating sample ETL pipeline configuration..."

# Find or create a sample user and organization
org = Organization.first
user = User.first

if org && user
  # Create a sample data source first
  sample_data_source = DataSource.find_or_create_by!(
    name: "Sample Shopify Store",
    organization: org
  ) do |ds|
    ds.source_type = 'shopify'
    ds.credentials = {
      shop_domain: 'sample-store.myshopify.com',
      api_key: 'encrypted_api_key',
      api_secret: 'encrypted_api_secret',
      access_token: 'encrypted_access_token'
    }.to_json
    ds.config = {
      api_version: '2024-01',
      include_orders: true,
      include_products: true,
      include_customers: true
    }
    ds.sync_frequency = 'hourly'
    ds.status = 'connected'
  end

  # Create a sample ETL pipeline
  sample_pipeline = Pipeline.find_or_create_by!(
    name: "Customer Data ETL Pipeline",
    organization: org
  ) do |pipeline|
    pipeline.created_by = user
    pipeline.description = "Extract customer data from Shopify, transform, and load to data warehouse"
    pipeline.pipeline_type = 'etl'
    pipeline.status = 'active'

    pipeline.source_config = {
      type: 'api',
      data_source_id: sample_data_source.id,
      api_type: 'shopify',
      endpoint: '/customers.json',
      batch_size: 250,
      filters: {
        updated_at_min: ':last_sync'
      }
    }

    pipeline.transformation_rules = [
      {
        type: 'field_mapping',
        name: 'Map customer fields',
        mapping: {
          'customer_id' => 'id',
          'customer_name' => 'name',
          'customer_email' => 'email',
          'created_date' => 'created_at'
        },
        include_unmapped: false
      },
      {
        type: 'type_conversion',
        name: 'Convert dates',
        field: 'created_at',
        target_type: 'datetime',
        format: '%Y-%m-%d %H:%M:%S'
      },
      {
        type: 'calculated_field',
        name: 'Add customer segment',
        field_name: 'segment',
        expression: "if(total_spent > 1000, 'VIP', if(total_spent > 100, 'Regular', 'New'))"
      },
      {
        type: 'filter',
        name: 'Active customers only',
        condition: {
          field: 'status',
          operator: '==',
          value: 'active'
        }
      }
    ]

    pipeline.destination_config = {
      type: 'warehouse',
      warehouse_type: 'snowflake',
      schema: 'analytics',
      table_name: 'dim_customers',
      write_mode: 'merge',
      merge_keys: [ 'id' ]
    }

    pipeline.schedule_config = {
      type: 'cron',
      cron_expression: '0 */6 * * *',
      timezone: 'UTC'
    }

    pipeline.error_handling_strategy = 'circuit_breaker'
    pipeline.retry_policy = {
      max_retries: 3,
      backoff_type: 'exponential',
      initial_delay: 60,
      max_delay: 3600
    }
  end

  # Create a second pipeline for API to Database
  api_pipeline = Pipeline.find_or_create_by!(
    name: "Shopify Orders ELT Pipeline",
    organization: org
  ) do |pipeline|
    pipeline.created_by = user
    pipeline.description = "Extract orders from Shopify API, load to database, transform in place"
    pipeline.pipeline_type = 'elt'
    pipeline.status = 'active'

    pipeline.source_config = {
      type: 'api',
      endpoint: 'https://api.shopify.com/orders',
      auth_type: 'oauth2',
      pagination_type: 'cursor',
      rate_limit: 2,
      headers: {
        'X-Shopify-Access-Token' => 'encrypted_token'
      }
    }

    pipeline.destination_config = {
      type: 'database',
      database_type: 'postgresql',
      host: 'analytics.db.internal',
      database: 'raw_data',
      schema: 'shopify',
      table_name: 'orders_raw'
    }

    pipeline.transformation_rules = [
      {
        type: 'post_load_sql',
        name: 'Create orders fact table',
        sql: <<-SQL
          CREATE TABLE IF NOT EXISTS analytics.fact_orders AS
          SELECT#{' '}
            id as order_id,
            customer->>'id' as customer_id,
            created_at::timestamp as order_date,
            total_price::decimal as order_total,
            fulfillment_status,
            financial_status
          FROM shopify.orders_raw
          WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
        SQL
      }
    ]

    pipeline.schedule_config = {
      type: 'interval',
      interval_minutes: 30
    }
  end

  # Create a streaming pipeline
  streaming_pipeline = Pipeline.find_or_create_by!(
    name: "Real-time Events Pipeline",
    organization: org
  ) do |pipeline|
    pipeline.created_by = user
    pipeline.description = "Stream user events from Kafka to data warehouse"
    pipeline.pipeline_type = 'streaming'
    pipeline.status = 'draft'

    pipeline.source_config = {
      type: 'streaming',
      platform: 'kafka',
      topic: 'user-events',
      consumer_group: 'analytics-consumer',
      bootstrap_servers: 'kafka.internal:9092'
    }

    pipeline.transformation_rules = [
      {
        type: 'filter',
        name: 'Filter test events',
        condition: {
          field: 'environment',
          operator: '!=',
          value: 'test'
        }
      },
      {
        type: 'aggregate',
        name: 'Aggregate by user and event type',
        group_by: [ 'user_id', 'event_type' ],
        window: '5 minutes',
        aggregations: [
          {
            field: 'event_id',
            function: 'count',
            alias: 'event_count'
          }
        ]
      }
    ]

    pipeline.destination_config = {
      type: 'warehouse',
      warehouse_type: 'bigquery',
      dataset: 'streaming',
      table_name: 'user_events',
      streaming_insert: true
    }
  end

  # Create some sample executions for the first pipeline
  5.times do |i|
    PipelineExecution.create!(
      organization: org,
      pipeline_name: sample_pipeline.name,
      execution_id: SecureRandom.uuid,
      status: [ 'completed', 'failed', 'running' ].sample,
      execution_mode: 'automatic',
      started_at: (i + 1).hours.ago,
      completed_at: i.hours.ago,
      progress: [ 100, 85, 50 ].sample,
      current_stage: [ 'extraction', 'transformation', 'loading' ].sample,
      user: user,
      parameters: {
        last_sync: (i + 2).hours.ago.iso8601
      },
      result_summary: {
        rows_extracted: rand(1000..5000),
        rows_transformed: rand(900..4900),
        rows_loaded: rand(900..4900)
      }
    )
  end

  puts "Created sample pipelines:"
  puts "- #{sample_pipeline.name} (#{sample_pipeline.pipeline_type})"
  puts "- #{api_pipeline.name} (#{api_pipeline.pipeline_type})"
  puts "- #{streaming_pipeline.name} (#{streaming_pipeline.pipeline_type})"
  puts "- #{PipelineExecution.count} sample executions"
else
  puts "Skipping ETL pipeline creation - no organization or user found"
  puts "Run 'rails db:seed' first to create base data"
end
