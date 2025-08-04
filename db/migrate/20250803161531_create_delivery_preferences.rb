class CreateDeliveryPreferences < ActiveRecord::Migration[8.0]
  def change
    create_table :delivery_preferences do |t|
      t.references :user, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.string :report_type
      t.string :channel
      t.string :format
      t.jsonb :schedule
      t.jsonb :options
      t.boolean :active
      t.string :delivery_time
      t.string :timezone

      t.timestamps
    end
  end
end
