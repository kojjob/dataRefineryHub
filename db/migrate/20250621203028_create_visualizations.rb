class CreateVisualizations < ActiveRecord::Migration[8.0]
  def change
    create_table :visualizations do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :data_source, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      
      t.string :title, null: false
      t.string :chart_type, null: false
      t.string :x_column, null: false
      t.string :y_column, null: false
      t.string :aggregation, null: false, default: 'sum'
      t.string :filter_column
      t.string :filter_value
      
      t.json :config, default: {}
      
      t.timestamps
    end

    add_index :visualizations, [:organization_id, :created_at]
    add_index :visualizations, [:data_source_id, :created_at]
    add_index :visualizations, [:user_id, :created_at]
  end
end
