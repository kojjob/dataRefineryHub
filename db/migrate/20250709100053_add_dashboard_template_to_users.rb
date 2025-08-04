class AddDashboardTemplateToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :dashboard_template, :string
  end
end
