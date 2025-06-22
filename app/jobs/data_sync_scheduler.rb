# Scheduled job to automatically sync data sources based on their sync frequency
# Runs periodically to check for data sources that need syncing
class DataSyncScheduler < ApplicationJob
  queue_as :analytics

  # This job should be scheduled to run every 5 minutes
  def perform
    Rails.logger.info "Running data sync scheduler"

    # Find data sources that need syncing
    sources_needing_sync = DataSource.connected.needs_sync

    if sources_needing_sync.empty?
      Rails.logger.info "No data sources need syncing at this time"
      return
    end

    Rails.logger.info "Found #{sources_needing_sync.count} data sources needing sync"

    # Group by sync frequency for prioritization
    sources_by_frequency = sources_needing_sync.group_by(&:sync_frequency)

    # Process in priority order: realtime -> hourly -> daily -> weekly -> monthly
    priority_order = %w[realtime hourly daily weekly monthly]

    priority_order.each do |frequency|
      sources = sources_by_frequency[frequency] || []
      next if sources.empty?

      Rails.logger.info "Scheduling #{sources.count} #{frequency} sync jobs"

      sources.each do |data_source|
        schedule_extraction_job(data_source)
      end
    end
  end

  private

  def schedule_extraction_job(data_source)
    begin
      # Check if there's already a running extraction job for this data source
      running_jobs = data_source.extraction_jobs.running

      if running_jobs.exists?
        Rails.logger.info "Skipping #{data_source.name} - extraction already running"
        return
      end

      # Schedule the extraction job
      ExtractionJobProcessor.perform_later(data_source.id)

      Rails.logger.info "Scheduled extraction job for #{data_source.name}"

      # Update next sync time to prevent immediate re-scheduling
      data_source.update!(next_sync_at: calculate_next_sync_time(data_source))

    rescue => error
      Rails.logger.error "Failed to schedule extraction for #{data_source.name}: #{error.message}"

      # Create audit log for scheduling failure
      AuditLog.create!(
        organization: data_source.organization,
        user: nil,
        action: "sync_scheduling_failed",
        resource_type: "DataSource",
        resource_id: data_source.id,
        details: {
          error_message: error.message,
          error_type: error.class.name,
          sync_frequency: data_source.sync_frequency
        }
      )
    end
  end

  def calculate_next_sync_time(data_source)
    case data_source.sync_frequency
    when "realtime"
      5.minutes.from_now
    when "hourly"
      1.hour.from_now
    when "daily"
      1.day.from_now
    when "weekly"
      1.week.from_now
    when "monthly"
      1.month.from_now
    else
      1.hour.from_now # Default fallback
    end
  end
end
