class AddSubscriptionTierToOrganizations < ActiveRecord::Migration[8.0]
  def change
    add_column :organizations, :subscription_tier, :string, default: 'free', null: false
    add_index :organizations, :subscription_tier
  end
end
