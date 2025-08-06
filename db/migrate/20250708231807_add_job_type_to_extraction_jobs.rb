class AddJobTypeToExtractionJobs < ActiveRecord::Migration[8.0]
  def change
    add_column :extraction_jobs, :job_type, :string, default: "manual_sync"

    # Update existing records
    reversible do |dir|
      dir.up do
        ExtractionJob.update_all(job_type: "manual_sync")
      end
    end
  end
end
