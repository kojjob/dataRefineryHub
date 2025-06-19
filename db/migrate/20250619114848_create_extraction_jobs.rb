class CreateExtractionJobs < ActiveRecord::Migration[8.0]
  def change
    create_table :extraction_jobs do |t|
      t.references :data_source, null: false, foreign_key: true
      t.string :job_id, null: false
      t.string :status, null: false, default: 'queued'
      t.string :priority, null: false, default: 'normal'
      t.datetime :started_at
      t.datetime :completed_at
      t.integer :records_processed, default: 0
      t.integer :records_failed, default: 0
      t.json :error_details, default: {}
      t.integer :retry_count, default: 0
      t.integer :max_retries, default: 3
      t.datetime :next_retry_at
      t.json :extraction_metadata, default: {}

      t.timestamps
    end
    
    add_index :extraction_jobs, :job_id, unique: true
    add_index :extraction_jobs, :status
    add_index :extraction_jobs, :priority
    add_index :extraction_jobs, :next_retry_at
    add_index :extraction_jobs, [:status, :priority]
    add_index :extraction_jobs, [:data_source_id, :status]
  end
end
