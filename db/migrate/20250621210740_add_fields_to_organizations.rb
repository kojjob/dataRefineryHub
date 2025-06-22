class AddFieldsToOrganizations < ActiveRecord::Migration[8.0]
  def change
    add_column :organizations, :timezone, :string, default: 'UTC'
    add_column :organizations, :phone, :string
    add_column :organizations, :address, :text
  end
end
