class CreateAiQueries < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_queries do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :query, null: false
      t.text :response
      t.json :context
      t.json :entities
      t.string :intent
      t.timestamps
    end

    add_index :ai_queries, :created_at
    add_index :ai_queries, :intent
    add_index :ai_queries, [:organization_id, :user_id, :created_at]
  end
end