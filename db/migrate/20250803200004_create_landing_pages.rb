class CreateLandingPages < ActiveRecord::Migration[8.0]
  def change
    create_table :landing_pages do |t|
      t.references :project, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.string :title
      t.text :description
      t.text :content
      t.string :meta_description
      t.jsonb :settings, default: {}
      t.string :template_type, default: 'standard'
      t.boolean :published, default: false
      t.datetime :published_at

      t.timestamps
    end
    
    add_index :landing_pages, :slug, unique: true
    add_index :landing_pages, [:project_id, :slug], unique: true, name: 'idx_landing_pages_project_slug_unique'
    add_index :landing_pages, :published
    add_index :landing_pages, :template_type
  end
end
