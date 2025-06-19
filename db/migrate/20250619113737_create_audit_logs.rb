class CreateAuditLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_logs do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.string :action, null: false
      t.string :resource_type
      t.string :resource_id
      t.json :details, default: {}
      t.string :ip_address
      t.text :user_agent
      t.datetime :performed_at, null: false

      t.timestamps
    end
    
    add_index :audit_logs, :action
    add_index :audit_logs, :resource_type
    add_index :audit_logs, :performed_at
    add_index :audit_logs, [:organization_id, :performed_at]
  end
end
