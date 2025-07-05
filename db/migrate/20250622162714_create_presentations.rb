class CreatePresentations < ActiveRecord::Migration[8.0]
  def change
    create_table :presentations do |t|
      t.string :title, null: false
      t.string :template_type, null: false
      t.string :output_format, null: false
      t.string :status, null: false, default: 'generating'
      t.string :file_path
      t.string :download_url
      t.text :content
      t.integer :progress_percentage, default: 0
      t.text :error_message
      t.datetime :generated_at
      t.datetime :failed_at
      t.references :organization, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true

      t.timestamps
    end

    add_index :presentations, [ :organization_id, :created_at ]
    add_index :presentations, [ :status, :created_at ]
    add_index :presentations, :template_type
  end
end
