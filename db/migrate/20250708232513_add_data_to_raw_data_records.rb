class AddDataToRawDataRecords < ActiveRecord::Migration[8.0]
  def change
    add_column :raw_data_records, :data, :jsonb
  end
end
