class CreateApiKeys < ActiveRecord::Migration[8.0]
  def change
    create_table :api_keys do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.string :key
      t.boolean :active
      t.datetime :last_used_at
      t.integer :usage_count

      t.timestamps
    end
  end
end
