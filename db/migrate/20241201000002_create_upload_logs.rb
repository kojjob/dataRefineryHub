class CreateUploadLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :upload_logs do |t|
      t.references :scheduled_upload, null: false, foreign_key: true
      t.string :status, null: false, default: 'running'
      t.datetime :started_at, null: false
      t.datetime :completed_at
      t.integer :files_processed, default: 0
      t.integer :files_failed, default: 0
      t.json :details
      t.text :error_message

      t.timestamps
    end

    add_index :upload_logs, [:scheduled_upload_id, :started_at]
    add_index :upload_logs, :status
    add_index :upload_logs, :started_at
    add_index :upload_logs, [:status, :started_at]
  end
end