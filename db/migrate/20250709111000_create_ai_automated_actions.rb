class CreateAiAutomatedActions < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_automated_actions do |t|
      t.references :insight, foreign_key: { to_table: :ai_insights }
      t.references :organization, null: false, foreign_key: true
      t.string :action_type, null: false
      t.json :parameters
      t.integer :status, default: 0
      t.datetime :executed_at
      t.datetime :approved_at
      t.datetime :completed_at
      t.references :approved_by, foreign_key: { to_table: :users }
      t.json :result
      t.string :suggested_by, default: 'bi_agent'
      t.timestamps
    end

    add_index :ai_automated_actions, :status
    add_index :ai_automated_actions, :action_type
    add_index :ai_automated_actions, [ :organization_id, :status ]
    add_index :ai_automated_actions, :executed_at
  end
end
