class AddComprehensivePerformanceIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    # 1. Add missing indexes for raw_data_records
    # Skip JSONB index if column is not JSONB type
    if column_exists?(:raw_data_records, :raw_data) &&
       ActiveRecord::Base.connection.columns(:raw_data_records).find { |c| c.name == 'raw_data' }&.sql_type == 'jsonb'
      unless index_exists?(:raw_data_records, :raw_data)
        add_index :raw_data_records, :raw_data, using: :gin, algorithm: :concurrently,
                  name: 'idx_raw_data_records_raw_data_gin'
      end
    end

    unless index_exists?(:raw_data_records, [ :organization_id, :processing_status, :created_at ])
      add_index :raw_data_records, [ :organization_id, :processing_status, :created_at ],
                algorithm: :concurrently,
                name: 'idx_raw_data_records_org_status_created'
    end

    # 2. Add compound indexes for audit_logs
    unless index_exists?(:audit_logs, [ :resource_type, :resource_id, :performed_at ])
      add_index :audit_logs, [ :resource_type, :resource_id, :performed_at ],
                algorithm: :concurrently,
                name: 'idx_audit_logs_resource_performed'
    end

    unless index_exists?(:audit_logs, [ :user_id, :action, :performed_at ])
      add_index :audit_logs, [ :user_id, :action, :performed_at ],
                algorithm: :concurrently,
                name: 'idx_audit_logs_user_action_performed'
    end

    # 3. Add partial index for unread notifications
    unless index_exists?(:notifications, [ :user_id, :organization_id, :created_at ], name: 'idx_notifications_unread')
      add_index :notifications, [ :user_id, :organization_id, :created_at ],
                where: "read_at IS NULL",
                algorithm: :concurrently,
                name: 'idx_notifications_unread'
    end

    # 4. Add missing foreign key indexes (only if tables exist)
    if table_exists?(:ai_insights)
      unless index_exists?(:ai_insights, :acknowledged_by)
        add_index :ai_insights, :acknowledged_by, algorithm: :concurrently,
                  name: 'idx_ai_insights_acknowledged_by'
      end

      unless index_exists?(:ai_insights, :read_by)
        add_index :ai_insights, :read_by, algorithm: :concurrently,
                  name: 'idx_ai_insights_read_by'
      end
    end

    # 5. Add partial indexes for status fields
    unless index_exists?(:extraction_jobs, :created_at, name: 'idx_extraction_jobs_active')
      add_index :extraction_jobs, :created_at,
                where: "status IN ('running', 'queued')",
                algorithm: :concurrently,
                name: 'idx_extraction_jobs_active'
    end

    if column_exists?(:pipeline_executions, :organization_id)
      unless index_exists?(:pipeline_executions, [ :organization_id, :started_at ], name: 'idx_pipeline_executions_running')
        add_index :pipeline_executions, [ :organization_id, :started_at ],
                  where: "status = 'running'",
                  algorithm: :concurrently,
                  name: 'idx_pipeline_executions_running'
      end
    end

    # 6. Add indexes for time-based queries (only if tables exist)
    if table_exists?(:ai_presentation_views)
      unless index_exists?(:ai_presentation_views, [ :organization_id, :started_at ])
        add_index :ai_presentation_views, [ :organization_id, :started_at ],
                  algorithm: :concurrently,
                  name: 'idx_ai_presentation_views_org_started'
      end
    end

    if table_exists?(:ai_presentation_interactions)
      unless index_exists?(:ai_presentation_interactions, [ :organization_id, :timestamp ])
        add_index :ai_presentation_interactions, [ :organization_id, :timestamp ],
                  algorithm: :concurrently,
                  name: 'idx_ai_presentation_interactions_org_timestamp'
      end
    end

    # 7. Add indexes for pipeline configuration queries
    unless index_exists?(:pipelines, [ :organization_id, :status ])
      add_index :pipelines, [ :organization_id, :status ],
                algorithm: :concurrently,
                name: 'idx_pipeline_configs_org_status'
    end

    unless index_exists?(:pipelines, :schedule_config)
      add_index :pipelines, :schedule_config, using: :gin,
                algorithm: :concurrently,
                name: 'idx_pipeline_configs_schedule_gin'
    end

    # 8. Add indexes for data source queries
    unless index_exists?(:data_sources, [ :organization_id, :status, :source_type ])
      add_index :data_sources, [ :organization_id, :status, :source_type ],
                algorithm: :concurrently,
                name: 'idx_data_sources_org_status_type'
    end

    # 9. Create materialized view for analytics (if not exists)
    # Check if extraction_jobs has organization_id before creating view
    if column_exists?(:extraction_jobs, :organization_id)
      execute <<-SQL
        CREATE MATERIALIZED VIEW IF NOT EXISTS organization_daily_metrics AS
        SELECT#{' '}
          organization_id,
          date_trunc('day', created_at) as date,
          COUNT(DISTINCT user_id) as active_users,
          COUNT(CASE WHEN status = 'completed' THEN 1 END) as successful_jobs,
          COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed_jobs,
          AVG(EXTRACT(EPOCH FROM (completed_at - started_at))) as avg_job_duration
        FROM extraction_jobs
        WHERE created_at > CURRENT_DATE - INTERVAL '90 days'
        GROUP BY organization_id, date_trunc('day', created_at)
        WITH DATA;
      SQL
    else
      # Alternative view using data_sources join
      execute <<-SQL
        CREATE MATERIALIZED VIEW IF NOT EXISTS organization_daily_metrics AS
        SELECT#{' '}
          ds.organization_id,
          date_trunc('day', ej.created_at) as date,
          COUNT(DISTINCT ej.id) as active_jobs,
          COUNT(CASE WHEN ej.status = 'completed' THEN 1 END) as successful_jobs,
          COUNT(CASE WHEN ej.status = 'failed' THEN 1 END) as failed_jobs,
          AVG(EXTRACT(EPOCH FROM (ej.completed_at - ej.started_at))) as avg_job_duration
        FROM extraction_jobs ej
        JOIN data_sources ds ON ds.id = ej.data_source_id
        WHERE ej.created_at > CURRENT_DATE - INTERVAL '90 days'
        GROUP BY ds.organization_id, date_trunc('day', ej.created_at)
        WITH DATA;
      SQL
    end

    # Create unique index on the materialized view
    execute <<-SQL
      CREATE UNIQUE INDEX IF NOT EXISTS idx_org_daily_metrics_lookup#{' '}
      ON organization_daily_metrics(organization_id, date);
    SQL

    # 10. Add database-level constraints for better performance
    execute <<-SQL
      -- Add check constraints for better query planning
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint#{' '}
          WHERE conname = 'check_valid_status'#{' '}
          AND conrelid = 'extraction_jobs'::regclass
        ) THEN
          ALTER TABLE extraction_jobs#{' '}
          ADD CONSTRAINT check_valid_status#{' '}
          CHECK (status IN ('queued', 'running', 'completed', 'failed', 'cancelled', 'retrying'));
        END IF;
      #{'  '}
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint#{' '}
          WHERE conname = 'check_valid_source_type'#{' '}
          AND conrelid = 'data_sources'::regclass
        ) THEN
          ALTER TABLE data_sources#{' '}
          ADD CONSTRAINT check_valid_source_type#{' '}
          CHECK (source_type IN ('shopify', 'quickbooks', 'google_analytics', 'stripe',#{' '}
                                'mailchimp', 'zendesk', 'hubspot', 'google_ads',#{' '}
                                'facebook_ads', 'woocommerce', 'salesforce',#{' '}
                                'amazon_seller_central', 'custom_api', 'file_upload',
                                'postgresql', 'mysql', 'csv', 'api', 'google_sheets'));
        END IF;
      END $$;
    SQL
  end

  def down
    # Remove indexes
    if index_exists?(:raw_data_records, name: 'idx_raw_data_records_raw_data_gin')
      remove_index :raw_data_records, name: 'idx_raw_data_records_raw_data_gin'
    end
    remove_index :raw_data_records, name: 'idx_raw_data_records_org_status_created', if_exists: true
    remove_index :audit_logs, name: 'idx_audit_logs_resource_performed', if_exists: true
    remove_index :audit_logs, name: 'idx_audit_logs_user_action_performed', if_exists: true
    remove_index :notifications, name: 'idx_notifications_unread', if_exists: true
    remove_index :ai_insights, name: 'idx_ai_insights_acknowledged_by', if_exists: true
    remove_index :ai_insights, name: 'idx_ai_insights_read_by', if_exists: true
    remove_index :extraction_jobs, name: 'idx_extraction_jobs_active', if_exists: true
    remove_index :pipeline_executions, name: 'idx_pipeline_executions_running', if_exists: true
    remove_index :ai_presentation_views, name: 'idx_ai_presentation_views_org_started', if_exists: true
    remove_index :ai_presentation_interactions, name: 'idx_ai_presentation_interactions_org_timestamp', if_exists: true
    remove_index :pipelines, name: 'idx_pipeline_configs_org_status', if_exists: true
    remove_index :pipelines, name: 'idx_pipeline_configs_schedule_gin', if_exists: true
    remove_index :data_sources, name: 'idx_data_sources_org_status_type', if_exists: true

    # Drop materialized view
    execute "DROP MATERIALIZED VIEW IF EXISTS organization_daily_metrics"

    # Remove constraints
    execute <<-SQL
      ALTER TABLE extraction_jobs DROP CONSTRAINT IF EXISTS check_valid_status;
      ALTER TABLE data_sources DROP CONSTRAINT IF EXISTS check_valid_source_type;
    SQL
  end
end
