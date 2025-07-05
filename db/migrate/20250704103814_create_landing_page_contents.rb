class CreateLandingPageContents < ActiveRecord::Migration[8.0]
  def change
    create_table :landing_page_contents do |t|
      t.string :section, null: false
      t.string :title, null: false
      t.text :content, null: false
      t.json :metadata, default: {}
      t.boolean :active, default: true, null: false
      t.integer :display_order, default: 0, null: false

      t.timestamps
    end

    add_index :landing_page_contents, :section
    add_index :landing_page_contents, :active
    add_index :landing_page_contents, :display_order
    add_index :landing_page_contents, [ :section, :active, :display_order ], name: 'index_landing_contents_on_section_active_order'
  end
end
