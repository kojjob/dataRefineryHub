# Service class to handle data source wizard preparation and logic
class DataSourceWizardService
  def initialize
    @wizard_data = {}
  end

  def prepare_wizard_data
    {
      wizard_data: build_wizard_metadata,
      configurations: load_data_source_configurations,
      sync_frequencies: build_sync_frequency_options,
      file_config: build_file_upload_configuration
    }
  end

  private

  def build_wizard_metadata
    {
      steps: [
        {
          id: 1,
          name: 'Platform Selection',
          description: 'Choose your data source platform',
          icon: 'database',
          required: true
        },
        {
          id: 2,
          name: 'Configuration',
          description: 'Configure connection settings',
          icon: 'settings',
          required: true
        },
        {
          id: 3,
          name: 'Data Preview',
          description: 'Preview and validate your data',
          icon: 'eye',
          required: false
        },
        {
          id: 4,
          name: 'Final Setup',
          description: 'Review and launch',
          icon: 'check-circle',
          required: true
        }
      ],
      current_step: 1,
      total_steps: 4,
      auto_save_enabled: true,
      auto_save_interval: 30000 # 30 seconds
    }
  end

  def load_data_source_configurations
    # Load from configuration file or database
    # This would typically come from a YAML file or database
    {
      # Database Platforms
      postgresql: {
        name: 'PostgreSQL',
        category: 'Database',
        description: 'Connect to PostgreSQL databases with real-time sync capabilities',
        icon: 'postgresql',
        sync_type: 'real_time',
        status: 'production_ready',
        features: ['Real-time sync', 'Schema detection', 'Incremental updates'],
        connection_fields: [
          { name: 'host', type: 'text', required: true, placeholder: 'localhost' },
          { name: 'port', type: 'number', required: true, placeholder: '5432', default: 5432 },
          { name: 'database', type: 'text', required: true, placeholder: 'database_name' },
          { name: 'username', type: 'text', required: true, placeholder: 'username' },
          { name: 'password', type: 'password', required: true, placeholder: 'password' },
          { name: 'ssl_mode', type: 'select', required: false, options: ['disable', 'require', 'prefer'], default: 'prefer' }
        ]
      },
      mysql: {
        name: 'MySQL',
        category: 'Database',
        description: 'Connect to MySQL databases with reliable data synchronization',
        icon: 'mysql',
        sync_type: 'real_time',
        status: 'production_ready',
        features: ['Real-time sync', 'Binary log parsing', 'Schema detection'],
        connection_fields: [
          { name: 'host', type: 'text', required: true, placeholder: 'localhost' },
          { name: 'port', type: 'number', required: true, placeholder: '3306', default: 3306 },
          { name: 'database', type: 'text', required: true, placeholder: 'database_name' },
          { name: 'username', type: 'text', required: true, placeholder: 'username' },
          { name: 'password', type: 'password', required: true, placeholder: 'password' }
        ]
      },
      
      # Cloud Platforms
      salesforce: {
        name: 'Salesforce',
        category: 'CRM',
        description: 'Sync your Salesforce data including leads, opportunities, and custom objects',
        icon: 'salesforce',
        sync_type: 'scheduled',
        status: 'production_ready',
        features: ['API-based sync', 'Custom objects', 'Field mapping'],
        connection_fields: [
          { name: 'instance_url', type: 'text', required: true, placeholder: 'https://your-instance.salesforce.com' },
          { name: 'username', type: 'text', required: true, placeholder: 'your-email@company.com' },
          { name: 'password', type: 'password', required: true, placeholder: 'password' },
          { name: 'security_token', type: 'password', required: true, placeholder: 'security_token' }
        ]
      },
      hubspot: {
        name: 'HubSpot',
        category: 'CRM',
        description: 'Connect your HubSpot CRM for comprehensive customer data analysis',
        icon: 'hubspot',
        sync_type: 'scheduled',
        status: 'production_ready',
        features: ['OAuth authentication', 'Contact sync', 'Deal tracking'],
        connection_fields: [
          { name: 'api_key', type: 'password', required: true, placeholder: 'your-hubspot-api-key' }
        ]
      },
      
      # File-based
      csv_upload: {
        name: 'CSV Upload',
        category: 'File',
        description: 'Upload CSV files for one-time or scheduled data imports',
        icon: 'file-csv',
        sync_type: 'manual',
        status: 'production_ready',
        features: ['Drag & drop upload', 'Column mapping', 'Data validation'],
        connection_fields: []
      },
      
      # Coming Soon
      snowflake: {
        name: 'Snowflake',
        category: 'Data Warehouse',
        description: 'Connect to Snowflake for enterprise data warehousing',
        icon: 'snowflake',
        sync_type: 'real_time',
        status: 'coming_soon',
        estimated_release: 'Q2 2025',
        features: ['Real-time sync', 'Zero-copy cloning', 'Time travel']
      },
      bigquery: {
        name: 'Google BigQuery',
        category: 'Data Warehouse',
        description: 'Sync data from Google BigQuery for analytics',
        icon: 'bigquery',
        sync_type: 'scheduled',
        status: 'coming_soon',
        estimated_release: 'Q2 2025',
        features: ['SQL queries', 'Partitioned tables', 'Streaming inserts']
      },
      stripe: {
        name: 'Stripe',
        category: 'Payment',
        description: 'Sync payment and subscription data from Stripe',
        icon: 'stripe',
        sync_type: 'real_time',
        status: 'coming_soon',
        estimated_release: 'Q1 2025',
        features: ['Webhook sync', 'Payment tracking', 'Subscription analytics']
      }
    }
  end

  def build_sync_frequency_options
    [
      {
        value: 'real_time',
        label: 'Real-time',
        description: 'Sync changes as they happen',
        icon: 'lightning',
        recommended_for: ['Databases', 'APIs with webhooks']
      },
      {
        value: 'every_15_minutes',
        label: 'Every 15 minutes',
        description: 'High-frequency updates',
        icon: 'clock-fast',
        recommended_for: ['Critical business data']
      },
      {
        value: 'hourly',
        label: 'Hourly',
        description: 'Sync every hour',
        icon: 'clock',
        recommended_for: ['Regular business data']
      },
      {
        value: 'daily',
        label: 'Daily',
        description: 'Once per day at midnight',
        icon: 'calendar-day',
        recommended_for: ['Reports and analytics']
      },
      {
        value: 'weekly',
        label: 'Weekly',
        description: 'Once per week on Sunday',
        icon: 'calendar-week',
        recommended_for: ['Historical data']
      },
      {
        value: 'manual',
        label: 'Manual',
        description: 'Sync only when triggered',
        icon: 'hand',
        recommended_for: ['One-time imports']
      }
    ]
  end

  def build_file_upload_configuration
    {
      max_file_size: 100.megabytes,
      allowed_types: ['.csv', '.xlsx', '.json', '.parquet'],
      max_files: 10,
      chunk_size: 1.megabyte,
      preview_rows: 100,
      supported_encodings: ['UTF-8', 'ISO-8859-1', 'Windows-1252'],
      delimiter_options: [',', ';', '\t', '|'],
      quote_options: ['"', "'", 'None']
    }
  end
end