class AddMonitoringFieldsToPipelineExecutions < ActiveRecord::Migration[8.0]
  def change
    add_column :pipeline_executions, :records_processed, :integer, default: 0
    add_column :pipeline_executions, :records_failed, :integer, default: 0
    add_column :pipeline_executions, :average_speed, :integer, default: 0
    add_column :pipeline_executions, :estimated_completion_at, :datetime
    add_column :pipeline_executions, :cpu_usage, :decimal, precision: 5, scale: 2
    add_column :pipeline_executions, :memory_usage_gb, :decimal, precision: 8, scale: 2
  end
end
