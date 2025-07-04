class CreateTaskTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :task_templates do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name
      t.text :description
      t.string :task_type
      t.string :execution_mode
      t.jsonb :template_config
      t.integer :default_timeout
      t.integer :default_priority
      t.integer :default_weight
      t.string :category
      t.string :tags
      t.boolean :active

      t.timestamps
    end
    add_index :task_templates, :active
  end
end
