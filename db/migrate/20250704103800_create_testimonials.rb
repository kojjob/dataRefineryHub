class CreateTestimonials < ActiveRecord::Migration[8.0]
  def change
    create_table :testimonials do |t|
      t.string :name, null: false
      t.string :company, null: false
      t.string :role, null: false
      t.text :quote, null: false
      t.integer :rating, null: false
      t.string :highlight, null: false
      t.string :ai_feature, null: false
      t.boolean :active, default: true, null: false
      t.integer :display_order, default: 0, null: false

      t.timestamps
    end

    add_index :testimonials, :active
    add_index :testimonials, :display_order
    add_index :testimonials, [:active, :display_order]
  end
end
