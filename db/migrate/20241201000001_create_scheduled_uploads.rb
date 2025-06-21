class CreateScheduledUploads < ActiveRecord::Migration[7.0]
  def change
    create_table :scheduled_uploads do |t|
      t.references :data_source, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :frequency, null: false, default: 'daily'
      t.boolean :active, default: true
      t.datetime :next_run_at
      t.datetime :last_run_at
      t.string :file_pattern
      t.text :notification_emails
      t.string :webhook_url
      t.integer :max_file_age_hours
      t.boolean :delete_after_processing, default: false
      t.boolean :retry_failed_files, default: true
      t.json :configuration

      t.timestamps
    end

    add_index :scheduled_uploads, [:data_source_id, :active]
    add_index :scheduled_uploads, :next_run_at
    add_index :scheduled_uploads, :frequency
    add_index :scheduled_uploads, [:user_id, :active]
  end
end