class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :email, null: false
      t.string :encrypted_password
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :role, null: false, default: 'member'
      t.datetime :last_sign_in_at
      t.datetime :current_sign_in_at
      t.integer :sign_in_count, default: 0
      t.datetime :confirmed_at
      t.string :invitation_token
      t.references :invited_by, null: true, foreign_key: { to_table: :users }
      t.datetime :invitation_accepted_at

      t.timestamps
    end

    add_index :users, [ :organization_id, :email ], unique: true
    add_index :users, :invitation_token, unique: true
    add_index :users, :role
    add_index :users, :confirmed_at
  end
end
