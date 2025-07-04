class CreateTaskExecutions < ActiveRecord::Migration[8.0]
  def change
    create_table :task_executions do |t|
      t.references :task, null: false, foreign_key: true
      t.uuid :execution_id, null: false
      t.string :status, null: false, default: 'pending'
      t.datetime :started_at
      t.datetime :completed_at
      t.jsonb :result, default: {}
      t.text :error_message
      t.jsonb :error_details, default: {}
      t.references :executed_by, foreign_key: { to_table: :users }
      t.integer :duration_seconds
      t.jsonb :metadata, default: {}

      t.timestamps

      # Indexes for performance
      t.index :execution_id, unique: true
      t.index :status
      t.index :started_at
      t.index [:task_id, :created_at]
    end
  end
end
