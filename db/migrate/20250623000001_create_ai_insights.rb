class CreateAiInsights < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_insights do |t|
      t.references :organization, null: false, foreign_key: true, index: true
      t.references :user, null: true, foreign_key: true, index: true
      t.references :presentation, null: true, foreign_key: { to_table: :presentations }, index: true
      t.references :data_source, null: true, foreign_key: true, index: true
      
      t.string :insight_type, null: false, index: true
      t.string :title, null: false
      t.text :description, null: false
      t.decimal :confidence_score, precision: 3, scale: 2, null: false
      t.string :impact_level, null: false, index: true
      t.boolean :actionable, default: false, null: false, index: true
      
      t.json :metadata, default: {}
      t.json :recommendations, default: []
      
      t.datetime :read_at, index: true
      t.bigint :read_by
      t.datetime :acknowledged_at, index: true
      t.bigint :acknowledged_by
      t.datetime :dismissed_at, index: true
      t.text :dismissal_reason
      
      t.timestamps null: false
    end
    
    # Add composite indexes for common queries
    add_index :ai_insights, [:organization_id, :insight_type]
    add_index :ai_insights, [:organization_id, :impact_level]
    add_index :ai_insights, [:organization_id, :created_at]
    add_index :ai_insights, [:actionable, :impact_level]
    add_index :ai_insights, [:confidence_score], where: "confidence_score > 0.7"
  end
end
