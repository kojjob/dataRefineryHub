class CreatePipelineExecutions < ActiveRecord::Migration[7.0]
  def change
    create_table :pipeline_executions do |t|
      t.string :execution_id, null: false
      t.string :pipeline_name, null: false
      t.references :data_source, null: true, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.string :status, null: false, default: 'pending'
      t.decimal :progress, precision: 5, scale: 2, default: 0.0
      t.string :current_stage
      t.datetime :started_at, null: false
      t.datetime :completed_at
      t.text :error_message
      t.text :parameters
      t.text :result_summary
      t.text :error_details
      
      t.timestamps
    end
    
    # Indexes for performance
    add_index :pipeline_executions, :execution_id, unique: true, if_not_exists: true
    add_index :pipeline_executions, :pipeline_name, if_not_exists: true
    add_index :pipeline_executions, :status, if_not_exists: true
    add_index :pipeline_executions, :data_source_id, if_not_exists: true
    add_index :pipeline_executions, :user_id, if_not_exists: true
    add_index :pipeline_executions, :started_at, if_not_exists: true
    add_index :pipeline_executions, [:pipeline_name, :status], if_not_exists: true
    add_index :pipeline_executions, [:data_source_id, :status], if_not_exists: true
    add_index :pipeline_executions, [:started_at, :status], if_not_exists: true
  end
end