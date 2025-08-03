class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :projects do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :slug, null: false
      t.string :status, default: 'active'
      t.jsonb :settings, default: {}

      t.timestamps
    end
    
    add_index :projects, :slug, unique: true
    add_index :projects, [:organization_id, :slug], unique: true, name: 'idx_projects_org_slug_unique'
    add_index :projects, :status
  end
end
