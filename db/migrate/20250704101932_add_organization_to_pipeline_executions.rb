class AddOrganizationToPipelineExecutions < ActiveRecord::Migration[8.0]
  def change
    add_reference :pipeline_executions, :organization, null: false, foreign_key: true
  end
end
