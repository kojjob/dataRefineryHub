class CreateOrganizations < ActiveRecord::Migration[8.0]
  def change
    create_table :organizations do |t|
      t.string :name, null: false
      t.string :slug
      t.string :plan, null: false, default: 'free_trial'
      t.json :plan_limits, default: {}
      t.json :settings, default: {}
      t.string :stripe_customer_id
      t.string :status, null: false, default: 'trial'

      t.timestamps
    end
    
    add_index :organizations, :slug, unique: true
    add_index :organizations, :stripe_customer_id, unique: true
    add_index :organizations, :plan
    add_index :organizations, :status
  end
end
