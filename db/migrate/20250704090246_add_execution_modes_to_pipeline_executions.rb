class AddExecutionModesToPipelineExecutions < ActiveRecord::Migration[8.0]
  def change
    add_column :pipeline_executions, :execution_mode, :string, default: 'automatic'
    add_column :pipeline_executions, :manual_intervention_required, :boolean, default: false
    add_column :pipeline_executions, :approval_status, :string
    add_reference :pipeline_executions, :approved_by, foreign_key: { to_table: :users }
    add_column :pipeline_executions, :last_manual_task_at, :datetime

    # Add indexes for performance
    add_index :pipeline_executions, :execution_mode
    add_index :pipeline_executions, :manual_intervention_required
    add_index :pipeline_executions, [ :execution_mode, :status ]
  end
end
