class CreateSystemHealthChecks < ActiveRecord::Migration[8.0]
  def change
    create_table :system_health_checks do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :check_type, null: false # database, api, storage, queue, cache
      t.string :status, null: false # healthy, degraded, down
      t.decimal :response_time_ms, precision: 10, scale: 2
      t.decimal :uptime_percentage, precision: 5, scale: 2
      t.text :error_message
      t.json :metadata, default: {}
      t.datetime :checked_at, null: false

      t.timestamps
    end

    add_index :system_health_checks, :check_type
    add_index :system_health_checks, :status
    add_index :system_health_checks, :checked_at
    add_index :system_health_checks, [ :organization_id, :check_type, :checked_at ], name: 'idx_health_checks_org_type_checked'
  end
end
