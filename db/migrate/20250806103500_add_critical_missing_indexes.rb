# frozen_string_literal: true

class AddCriticalMissingIndexes < ActiveRecord::Migration[8.0]
  def change
    # Check and add only missing indexes to avoid duplicates

    # Add indexes only if they don't exist
    unless index_exists?(:data_sources, [ :organization_id, :status ])
      add_index :data_sources, [ :organization_id, :status ], name: 'idx_data_sources_org_status_v2'
    end

    unless index_exists?(:data_sources, [ :status, :next_sync_at ])
      add_index :data_sources, [ :status, :next_sync_at ], name: 'idx_data_sources_sync_schedule_v2'
    end

    unless index_exists?(:extraction_jobs, [ :data_source_id, :status ])
      add_index :extraction_jobs, [ :data_source_id, :status ], name: 'idx_extraction_jobs_source_status_v2'
    end

    unless index_exists?(:data_quality_reports, [ :data_source_id, :run_at ])
      add_index :data_quality_reports, [ :data_source_id, :run_at ], name: 'idx_quality_reports_source_run_v2'
    end

    unless index_exists?(:raw_data_records, [ :data_source_id, :processing_status ])
      add_index :raw_data_records, [ :data_source_id, :processing_status ], name: 'idx_raw_records_source_status_v2'
    end

    # Notifications - use read_at column
    unless index_exists?(:notifications, [ :user_id, :notification_type ])
      add_index :notifications, [ :user_id, :notification_type ], name: 'idx_notifications_user_type_v2'
    end

    unless index_exists?(:notifications, [ :user_id, :created_at ])
      add_index :notifications, [ :user_id, :created_at ], name: 'idx_notifications_user_created_v2'
    end

    unless index_exists?(:audit_logs, [ :resource_type, :resource_id ])
      add_index :audit_logs, [ :resource_type, :resource_id ], name: 'idx_audit_logs_resource_v2'
    end

    unless index_exists?(:audit_logs, [ :user_id, :performed_at ])
      add_index :audit_logs, [ :user_id, :performed_at ], name: 'idx_audit_logs_user_performed_v2'
    end

    unless index_exists?(:audit_logs, [ :action, :performed_at ])
      add_index :audit_logs, [ :action, :performed_at ], name: 'idx_audit_logs_action_performed_v2'
    end

    # Add partial indexes for specific query patterns (PostgreSQL specific)
    unless index_exists?(:data_sources, :next_sync_at, where: "status = 'connected'")
      add_index :data_sources, :next_sync_at,
                where: "status = 'connected'",
                name: 'idx_data_sources_next_sync_connected_v2'
    end

    unless index_exists?(:notifications, [ :user_id, :created_at ], where: "read_at IS NULL")
      add_index :notifications, [ :user_id, :created_at ],
                where: "read_at IS NULL",
                name: 'idx_notifications_unread_v2'
    end
  end
end
