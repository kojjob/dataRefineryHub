class CreatePipelineMetrics < ActiveRecord::Migration[8.0]
  def change
    create_table :pipeline_metrics do |t|
      t.references :pipeline_execution, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.integer :records_per_second, default: 0
      t.decimal :cpu_usage, precision: 5, scale: 2
      t.decimal :memory_usage_gb, precision: 8, scale: 2
      t.integer :active_threads, default: 0
      t.integer :queue_size, default: 0
      t.datetime :recorded_at, null: false

      t.timestamps
    end

    add_index :pipeline_metrics, :recorded_at
    add_index :pipeline_metrics, [:pipeline_execution_id, :recorded_at]
  end
end
