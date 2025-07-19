class CreateEventTimeline < ActiveRecord::Migration[8.0]
  def change
    create_table :event_timelines do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :event_type, null: false # pipeline_started, pipeline_completed, alert_triggered, sync_failed, etc.
      t.string :event_category, null: false # success, error, warning, info
      t.string :title, null: false
      t.text :description
      t.string :resource_type
      t.bigint :resource_id
      t.json :metadata, default: {}
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :event_timelines, :event_type
    add_index :event_timelines, :event_category
    add_index :event_timelines, :occurred_at
    add_index :event_timelines, [:resource_type, :resource_id]
    add_index :event_timelines, [:organization_id, :occurred_at]
  end
end
