class CreateReportComponents < ActiveRecord::Migration[8.0]
  def change
    create_table :report_components do |t|
      t.references :report_template, null: false, foreign_key: true
      t.string :component_type, null: false # chart, table, metric, text, filter
      t.string :component_id, null: false # unique identifier within template
      t.jsonb :properties, default: {}
      t.jsonb :data_source, default: {}
      t.jsonb :styling, default: {}
      t.integer :position_x, default: 0
      t.integer :position_y, default: 0
      t.integer :width, default: 6
      t.integer :height, default: 4
      t.integer :z_index, default: 0

      t.timestamps
    end

    add_index :report_components, [ :report_template_id, :component_id ], unique: true, name: 'idx_report_components_unique'
    add_index :report_components, :component_type
  end
end
