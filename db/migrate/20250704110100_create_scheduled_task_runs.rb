class CreateScheduledTaskRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :scheduled_task_runs do |t|
      t.references :scheduled_task, null: false, foreign_key: true
      t.references :pipeline_execution, foreign_key: true
      t.references :task, foreign_key: true
      
      t.string :status, null: false, default: 'pending'
      t.datetime :started_at, null: false
      t.datetime :completed_at
      t.integer :duration_seconds
      
      t.text :error_message
      t.jsonb :output, default: {}
      
      t.timestamps
    end
    
    add_index :scheduled_task_runs, :status
    add_index :scheduled_task_runs, :started_at
    add_index :scheduled_task_runs, [:scheduled_task_id, :started_at]
  end
end