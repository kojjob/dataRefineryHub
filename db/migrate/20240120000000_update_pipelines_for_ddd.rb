# frozen_string_literal: true

class UpdatePipelinesForDdd < ActiveRecord::Migration[7.1]
  def change
    # Rename existing table to match our convention
    rename_table :pipeline_configurations, :pipelines if table_exists?(:pipeline_configurations)
    
    # Add missing columns if they don't exist
    add_column :pipelines, :tags, :jsonb, default: [] unless column_exists?(:pipelines, :tags)
    add_column :pipelines, :aggregate_version, :integer, default: 0 unless column_exists?(:pipelines, :aggregate_version)
    
    # Add indexes for better performance
    add_index :pipelines, :status unless index_exists?(:pipelines, :status)
    add_index :pipelines, [:organization_id, :status] unless index_exists?(:pipelines, [:organization_id, :status])
    add_index :pipelines, :tags, using: :gin unless index_exists?(:pipelines, :tags)
    
    # Ensure we have proper JSON columns
    change_column :pipelines, :source_config, :jsonb if column_exists?(:pipelines, :source_config)
    change_column :pipelines, :destination_config, :jsonb if column_exists?(:pipelines, :destination_config)
    change_column :pipelines, :transformation_rules, :jsonb if column_exists?(:pipelines, :transformation_rules)
    change_column :pipelines, :schedule_config, :jsonb if column_exists?(:pipelines, :schedule_config)
    change_column :pipelines, :retry_policy, :jsonb if column_exists?(:pipelines, :retry_policy)
  end
end
