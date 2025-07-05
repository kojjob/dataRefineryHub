class CreateTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :tasks do |t|
      t.references :pipeline_execution, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :task_type, null: false
      t.string :execution_mode, null: false, default: 'automated'
      t.string :status, null: false, default: 'pending'
      t.integer :priority, default: 0
      t.integer :position
      t.jsonb :configuration, default: {}
      t.jsonb :metadata, default: {}
      t.text :error_message
      t.datetime :started_at
      t.datetime :completed_at
      t.integer :retry_count, default: 0
      t.integer :max_retries, default: 3
      t.integer :timeout_seconds, default: 300
      t.references :assignee, foreign_key: { to_table: :users }
      t.uuid :execution_id
      t.string :depends_on, array: true, default: []

      t.timestamps

      # Indexes for performance
      t.index :status
      t.index :execution_mode
      t.index :priority
      t.index [ :pipeline_execution_id, :position ]
      t.index [ :pipeline_execution_id, :status ]
      t.index [ :status, :execution_mode ]
      t.index :execution_id, unique: true
      t.index :created_at
    end
  end
end
