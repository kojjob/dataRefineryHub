class CreatePipelineConfigurations < ActiveRecord::Migration[8.0]
  def change
    return if table_exists?(:pipeline_configurations) || table_exists?(:pipelines)
    
    create_table :pipeline_configurations do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :last_executed_by, foreign_key: { to_table: :users }

      t.string :name, null: false
      t.text :description
      t.string :pipeline_type, null: false, default: 'etl'
      t.string :status, null: false, default: 'draft'

      t.jsonb :source_config, null: false, default: {}
      t.jsonb :destination_config, null: false, default: {}
      t.jsonb :transformation_rules, default: []
      t.jsonb :schedule_config, default: {}
      t.jsonb :dependencies, default: []
      t.jsonb :retry_policy, default: {}
      t.jsonb :notification_settings, default: {}

      t.string :error_handling_strategy, default: 'circuit_breaker'
      t.datetime :last_executed_at

      t.timestamps

      t.index [ :organization_id, :name ], unique: true
      t.index :pipeline_type
      t.index :status
      t.index :created_at
    end
  end
end
