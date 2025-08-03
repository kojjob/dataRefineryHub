class CreateReportTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :report_templates do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :template_type # standard, custom, shared
      t.jsonb :configuration, default: {}
      t.jsonb :query_definition, default: {}
      t.jsonb :layout, default: {}
      t.boolean :is_public, default: false
      t.boolean :is_featured, default: false
      t.integer :usage_count, default: 0

      t.timestamps
    end

    add_index :report_templates, :name
    add_index :report_templates, :template_type
    add_index :report_templates, :is_public
    add_index :report_templates, :is_featured
  end
end