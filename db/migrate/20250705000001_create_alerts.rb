class CreateAlerts < ActiveRecord::Migration[8.0]
  def change
    create_table :alerts do |t|
      t.string :alert_type, null: false
      t.string :title, null: false
      t.text :message, null: false
      t.string :severity, null: false, default: 'medium'
      t.string :status, null: false, default: 'active'
      
      # Associations
      t.references :organization, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.references :data_source, null: true, foreign_key: true
      t.references :pipeline_execution, null: true, foreign_key: true
      
      # Resolution tracking
      t.datetime :resolved_at
      t.datetime :acknowledged_at
      t.datetime :dismissed_at
      t.string :resolved_by
      t.string :acknowledged_by
      t.string :dismissed_by
      
      # Additional metadata
      t.json :metadata, default: {}

      t.timestamps
    end

    # Indexes for performance (references already create single column indexes)
    add_index :alerts, :alert_type
    add_index :alerts, :severity
    add_index :alerts, :status
    add_index :alerts, :created_at
    add_index :alerts, [:organization_id, :alert_type]
    add_index :alerts, [:organization_id, :status]
    add_index :alerts, [:organization_id, :severity]
    add_index :alerts, [:alert_type, :status]
    add_index :alerts, [:severity, :status]
  end
end
