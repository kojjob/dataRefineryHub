class AddPerformanceIndexes < ActiveRecord::Migration[7.0]
  def change
    # Indexes for data_sources table (only add if not already exists)
    add_index :data_sources, [:organization_id, :source_type], name: 'idx_data_sources_org_type' unless index_exists?(:data_sources, [:organization_id, :source_type])
    add_index :data_sources, [:status, :updated_at], name: 'idx_data_sources_status_updated' unless index_exists?(:data_sources, [:status, :updated_at])
    add_index :data_sources, [:organization_id, :status, :created_at], name: 'idx_data_sources_org_status_created' unless index_exists?(:data_sources, [:organization_id, :status, :created_at])

    # Indexes for extraction_jobs table (only add if not already exists)
    add_index :extraction_jobs, [:status, :created_at], name: 'idx_extraction_jobs_status_created' unless index_exists?(:extraction_jobs, [:status, :created_at])
    add_index :extraction_jobs, [:data_source_id, :status, :updated_at], name: 'idx_extraction_jobs_source_status_updated' unless index_exists?(:extraction_jobs, [:data_source_id, :status, :updated_at])

    # Indexes for users table (only add if not already exists)
    add_index :users, :organization_id, name: 'idx_users_organization' unless index_exists?(:users, :organization_id)

    # Indexes for organizations table (only add if not already exists)
    add_index :organizations, :created_at, name: 'idx_organizations_created' unless index_exists?(:organizations, :created_at)

    # Indexes for notifications table (only add if not already exists)
    add_index :notifications, [:organization_id, :notification_type], name: 'idx_notifications_org_type' unless index_exists?(:notifications, [:organization_id, :notification_type])
    add_index :notifications, [:user_id, :created_at], name: 'idx_notifications_user_created' unless index_exists?(:notifications, [:user_id, :created_at])

    # Indexes for data_quality_reports table (only add if not already exists)
    add_index :data_quality_reports, [:data_source_id, :overall_score], name: 'idx_data_quality_reports_source_score' unless index_exists?(:data_quality_reports, [:data_source_id, :overall_score])
  end
end
