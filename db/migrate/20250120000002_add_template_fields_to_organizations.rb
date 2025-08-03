# frozen_string_literal: true

class AddTemplateFieldsToOrganizations < ActiveRecord::Migration[8.0]
  def change
    add_column :organizations, :applied_template, :string
    add_column :organizations, :template_applied_at, :datetime
  end
end