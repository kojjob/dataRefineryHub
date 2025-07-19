class CreateSystemMetrics < ActiveRecord::Migration[8.0]
  def change
    create_table :system_metrics do |t|
      t.references :organization, null: false, foreign_key: true
      t.decimal :cpu_usage, precision: 5, scale: 2
      t.decimal :memory_usage, precision: 5, scale: 2
      t.decimal :storage_usage, precision: 5, scale: 2
      t.decimal :network_io_read, precision: 10, scale: 2
      t.decimal :network_io_write, precision: 10, scale: 2
      t.integer :active_connections, default: 0
      t.integer :queue_depth, default: 0
      t.datetime :recorded_at, null: false
      t.json :metadata, default: {}

      t.timestamps
    end

    add_index :system_metrics, :recorded_at
    add_index :system_metrics, [:organization_id, :recorded_at]
  end
end
