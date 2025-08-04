class CreateAiAgentConfigurations < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_agent_configurations do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :agent_type, null: false
      t.boolean :enabled, default: true
      t.json :settings
      t.json :learning_data
      t.float :performance_score
      t.timestamps
    end

    add_index :ai_agent_configurations, [:organization_id, :agent_type], unique: true
    add_index :ai_agent_configurations, :agent_type
  end
end