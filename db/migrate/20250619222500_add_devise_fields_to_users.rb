class AddDeviseFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :reset_password_token, :string
    add_column :users, :reset_password_sent_at, :datetime
    add_column :users, :remember_created_at, :datetime
    add_column :users, :current_sign_in_ip, :string
    add_column :users, :last_sign_in_ip, :string
    add_column :users, :confirmation_token, :string
    add_column :users, :confirmation_sent_at, :datetime
    add_column :users, :unconfirmed_email, :string
    
    # Add indexes for Devise fields
    add_index :users, :reset_password_token, unique: true
    add_index :users, :confirmation_token, unique: true
    
    # Make encrypted_password not nullable for existing Devise functionality
    change_column_null :users, :encrypted_password, false, ''
  end
end
