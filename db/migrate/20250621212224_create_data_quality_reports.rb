class CreateDataQualityReports < ActiveRecord::Migration[8.0]
  def change
    create_table :data_quality_reports do |t|
      t.references :data_source, null: false, foreign_key: true
      t.decimal :overall_score, precision: 5, scale: 2, default: 0.0
      t.decimal :completeness_score, precision: 5, scale: 2, default: 0.0
      t.decimal :accuracy_score, precision: 5, scale: 2, default: 0.0
      t.decimal :consistency_score, precision: 5, scale: 2, default: 0.0
      t.decimal :validity_score, precision: 5, scale: 2, default: 0.0
      t.decimal :timeliness_score, precision: 5, scale: 2, default: 0.0
      t.integer :issues_count, default: 0
      t.integer :total_records, default: 0
      t.integer :valid_records, default: 0
      t.json :report_data, default: {}
      t.datetime :run_at

      t.timestamps
    end

    add_index :data_quality_reports, [:data_source_id, :run_at]
    add_index :data_quality_reports, :run_at
  end
end
