class CreateDeliveryLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :delivery_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.string :channel
      t.string :status
      t.string :report_type
      t.jsonb :metadata
      t.datetime :delivered_at
      t.text :error_message

      t.timestamps
    end
  end
end
