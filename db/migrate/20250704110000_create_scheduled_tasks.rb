class CreateScheduledTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :scheduled_tasks do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :task_template, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }

      t.string :name, null: false
      t.text :description
      t.string :status, null: false, default: 'active'
      t.string :schedule_type, null: false

      # Scheduling fields
      t.datetime :scheduled_at # For 'once' type
      t.time :time_of_day # For daily, weekly, monthly
      t.string :days_of_week, array: true, default: [] # For weekly
      t.integer :day_of_month # For monthly
      t.string :cron_expression # For custom

      # Execution control
      t.date :start_date
      t.date :end_date
      t.integer :max_runs
      t.integer :run_count, default: 0
      t.datetime :next_run_at

      # Configuration
      t.jsonb :configuration, default: {}
      t.jsonb :task_overrides, default: {}

      # Tracking
      t.datetime :paused_at
      t.datetime :resumed_at
      t.datetime :completed_at

      t.timestamps
    end

    add_index :scheduled_tasks, :status
    add_index :scheduled_tasks, :schedule_type
    add_index :scheduled_tasks, :next_run_at
    add_index :scheduled_tasks, [ :organization_id, :status ]
  end
end
