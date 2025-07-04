class CreateAiPresentationInteractions < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_presentation_interactions do |t|
      t.references :presentation, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.string :interaction_type, null: false
      t.string :element_id
      t.string :element_type
      t.text :coordinates
      t.text :metadata
      t.text :form_data
      t.datetime :timestamp
      t.string :session_id
      t.string :ip_address
      t.text :user_agent
      t.string :page_url
      t.string :referrer

      t.timestamps
    end
    
    add_index :ai_presentation_interactions, [:presentation_id, :created_at]
    add_index :ai_presentation_interactions, [:organization_id, :created_at]
    add_index :ai_presentation_interactions, [:user_id, :created_at]
    add_index :ai_presentation_interactions, :interaction_type
    add_index :ai_presentation_interactions, :session_id
    add_index :ai_presentation_interactions, :timestamp
  end
end
