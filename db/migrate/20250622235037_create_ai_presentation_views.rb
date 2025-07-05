class CreateAiPresentationViews < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_presentation_views do |t|
      t.references :presentation, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.string :session_id, null: false
      t.string :ip_address, null: false
      t.text :user_agent
      t.datetime :started_at
      t.datetime :ended_at
      t.integer :duration
      t.boolean :completed, default: false
      t.string :referrer
      t.string :device_type
      t.string :browser
      t.string :os
      t.string :country
      t.string :city
      t.string :utm_source
      t.string :utm_medium
      t.string :utm_campaign

      t.timestamps
    end

    add_index :ai_presentation_views, [ :presentation_id, :created_at ]
    add_index :ai_presentation_views, [ :organization_id, :created_at ]
    add_index :ai_presentation_views, [ :user_id, :created_at ]
    add_index :ai_presentation_views, :session_id
    add_index :ai_presentation_views, :completed
  end
end
