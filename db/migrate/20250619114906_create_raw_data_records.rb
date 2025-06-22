class CreateRawDataRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :raw_data_records do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :data_source, null: false, foreign_key: true
      t.references :extraction_job, null: false, foreign_key: true
      t.string :record_type, null: false
      t.string :external_id, null: false
      t.text :raw_data
      t.text :encrypted_payload
      t.string :checksum, null: false
      t.string :processing_status, null: false, default: 'pending'
      t.datetime :processed_at
      t.json :validation_errors, default: {}

      t.timestamps
    end

    add_index :raw_data_records, [ :data_source_id, :external_id, :checksum ],
              unique: true, name: 'index_raw_data_records_on_source_id_checksum'
    add_index :raw_data_records, :record_type
    add_index :raw_data_records, :processing_status
    add_index :raw_data_records, :processed_at
    add_index :raw_data_records, [ :organization_id, :record_type ]
    add_index :raw_data_records, [ :extraction_job_id, :processing_status ]
  end
end
