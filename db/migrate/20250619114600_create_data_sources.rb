class CreateDataSources < ActiveRecord::Migration[8.0]
  def change
    create_table :data_sources do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.string :source_type, null: false
      t.json :config, default: {}
      t.text :credentials
      t.string :status, null: false, default: 'disconnected'
      t.datetime :last_sync_at
      t.datetime :next_sync_at
      t.string :sync_frequency, null: false, default: 'daily'
      t.text :error_message

      t.timestamps
    end
    
    add_index :data_sources, [:organization_id, :name], unique: true
    add_index :data_sources, :source_type
    add_index :data_sources, :status
    add_index :data_sources, :next_sync_at
    add_index :data_sources, [:status, :next_sync_at]
  end
end
