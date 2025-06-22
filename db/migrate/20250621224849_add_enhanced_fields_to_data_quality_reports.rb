class AddEnhancedFieldsToDataQualityReports < ActiveRecord::Migration[7.0]
  def change
    add_reference :data_quality_reports, :user, null: true, foreign_key: true
    add_column :data_quality_reports, :status, :string, default: 'pending'
    add_column :data_quality_reports, :validation_type, :string, default: 'full'
    add_column :data_quality_reports, :started_at, :datetime
    add_column :data_quality_reports, :completed_at, :datetime
    add_column :data_quality_reports, :error_message, :text
    add_column :data_quality_reports, :quality_metrics, :json, default: {}
    add_column :data_quality_reports, :metadata, :json, default: {}
    add_column :data_quality_reports, :records_analyzed, :integer, default: 0
    add_column :data_quality_reports, :uniqueness_score, :decimal, precision: 5, scale: 2, default: 0.0
    add_column :data_quality_reports, :freshness_score, :decimal, precision: 5, scale: 2, default: 0.0
    
    add_index :data_quality_reports, :status unless index_exists?(:data_quality_reports, :status)
    add_index :data_quality_reports, :validation_type unless index_exists?(:data_quality_reports, :validation_type)
    add_index :data_quality_reports, [:data_source_id, :status] unless index_exists?(:data_quality_reports, [:data_source_id, :status])
    add_index :data_quality_reports, [:overall_score] unless index_exists?(:data_quality_reports, [:overall_score])
  end
end
