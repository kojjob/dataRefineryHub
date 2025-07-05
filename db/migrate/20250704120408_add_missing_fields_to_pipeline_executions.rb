class AddMissingFieldsToPipelineExecutions < ActiveRecord::Migration[8.0]
  def change
    add_column :pipeline_executions, :priority, :integer, default: 0
    add_column :pipeline_executions, :configuration, :json, default: {}
    add_column :pipeline_executions, :metadata, :json, default: {}
    add_column :pipeline_executions, :retry_count, :integer, default: 0
  end
end
