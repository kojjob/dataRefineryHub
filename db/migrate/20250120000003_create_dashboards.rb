# frozen_string_literal: true

class CreateDashboards < ActiveRecord::Migration[8.0]
  def change
    create_table :dashboards do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.string :dashboard_type
      t.jsonb :configuration, default: {}
      t.boolean :active, default: true
      t.integer :position

      t.timestamps
    end

    add_index :dashboards, :dashboard_type
    add_index :dashboards, :active
    add_index :dashboards, [ :organization_id, :active ]
  end
end
