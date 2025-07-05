class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.string :title, null: false
      t.text :message, null: false
      t.string :notification_type, null: false
      t.datetime :read_at
      t.integer :priority, default: 0
      t.json :metadata, default: {}

      # Optional reference to the object that triggered the notification
      t.string :notifiable_type
      t.bigint :notifiable_id

      t.timestamps
    end

    add_index :notifications, [ :user_id, :read_at ]
    add_index :notifications, [ :organization_id, :created_at ]
    add_index :notifications, [ :notifiable_type, :notifiable_id ]
    add_index :notifications, :notification_type
    add_index :notifications, :priority
  end
end
