class CreateTransformationJobs < ActiveRecord::Migration[8.0]
  def change
    create_table :transformation_jobs do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :job_id, null: false
      t.string :transformation_type, null: false
      t.integer :input_records_count, default: 0
      t.integer :output_records_count, default: 0
      t.string :status, null: false, default: 'queued'
      t.datetime :started_at
      t.datetime :completed_at
      t.json :error_details, default: {}
      t.json :transformation_rules, default: {}
      t.json :data_quality_metrics, default: {}

      t.timestamps
    end

    add_index :transformation_jobs, :job_id, unique: true
    add_index :transformation_jobs, :transformation_type
    add_index :transformation_jobs, :status
    add_index :transformation_jobs, [ :organization_id, :transformation_type ]
    add_index :transformation_jobs, [ :status, :started_at ]
    add_index :transformation_jobs, :completed_at
  end
end
