class ScheduledUpload < ApplicationRecord
  belongs_to :data_source
  belongs_to :user
  has_many :upload_logs, dependent: :destroy

  validates :name, presence: true
  validates :frequency, presence: true, inclusion: { in: %w[hourly daily weekly monthly] }
  validates :file_pattern, presence: true

  scope :active, -> { where(active: true) }
  scope :due_for_execution, -> { where("next_run_at <= ?", Time.current) }

  before_create :set_next_run_at
  after_update :update_next_run_at, if: :saved_change_to_frequency?

  def self.process_due_uploads
    active.due_for_execution.find_each do |scheduled_upload|
      ScheduledUploadJob.perform_later(scheduled_upload.id)
    end
  end

  def execute!
    begin
      log_entry = upload_logs.create!(
        status: "running",
        started_at: Time.current,
        details: { message: "Starting scheduled upload execution" }
      )

      files = discover_files

      if files.empty?
        log_entry.update!(
          status: "completed",
          completed_at: Time.current,
          files_processed: 0,
          details: { message: "No files found matching pattern", pattern: file_pattern }
        )
        update_next_run_at!
        return { success: true, files_processed: 0, message: "No files found" }
      end

      processed_files = []
      errors = []

      files.each do |file_info|
        begin
          if should_process_file?(file_info)
            result = process_file(file_info)
            processed_files << result
          else
            Rails.logger.info "Skipping file #{file_info[:path]} - already processed or doesn't meet criteria"
          end
        rescue => e
          error_msg = "Failed to process file #{file_info[:path]}: #{e.message}"
          errors << error_msg
          Rails.logger.error error_msg
        end
      end

      log_entry.update!(
        status: errors.empty? ? "completed" : "completed_with_errors",
        completed_at: Time.current,
        files_processed: processed_files.length,
        files_failed: errors.length,
        details: {
          processed_files: processed_files,
          errors: errors,
          total_files_found: files.length
        }
      )

      update_next_run_at!
      send_notification_if_configured(log_entry)

      {
        success: true,
        files_processed: processed_files.length,
        files_failed: errors.length,
        errors: errors
      }
    rescue => e
      Rails.logger.error "Scheduled upload execution failed: #{e.message}"

      upload_logs.create!(
        status: "failed",
        started_at: Time.current,
        completed_at: Time.current,
        details: { error: e.message, backtrace: e.backtrace.first(10) }
      )

      { success: false, error: e.message }
    end
  end

  def next_run_description
    return "Manual execution only" if frequency == "manual"
    return "Not scheduled" if next_run_at.nil?

    if next_run_at > Time.current
      "Next run: #{next_run_at.strftime('%Y-%m-%d %H:%M:%S')}"
    else
      "Overdue (was scheduled for #{next_run_at.strftime('%Y-%m-%d %H:%M:%S')})"
    end
  end

  def last_execution_summary
    last_log = upload_logs.order(created_at: :desc).first
    return "Never executed" unless last_log

    status_text = case last_log.status
    when "completed"
                    "Success"
    when "completed_with_errors"
                    "Completed with errors"
    when "failed"
                    "Failed"
    when "running"
                    "Currently running"
    else
                    last_log.status.humanize
    end

    "#{status_text} - #{last_log.created_at.strftime('%Y-%m-%d %H:%M:%S')}"
  end

  private

  def discover_files
    case data_source.source_type
    when "local_directory"
      discover_local_files
    when "cloud_storage"
      discover_cloud_files
    when "ftp", "sftp"
      discover_remote_files
    else
      []
    end
  end

  def discover_local_files
    return [] unless source_config["directory_path"].present?

    directory = source_config["directory_path"]
    return [] unless Dir.exist?(directory)

    pattern = File.join(directory, file_pattern)
    Dir.glob(pattern).map do |file_path|
      {
        path: file_path,
        name: File.basename(file_path),
        size: File.size(file_path),
        modified_at: File.mtime(file_path),
        source_type: "local"
      }
    end
  end

  def discover_cloud_files
    # Implementation would depend on cloud provider
    # This is a placeholder for cloud storage integration
    []
  end

  def discover_remote_files
    # Implementation would depend on FTP/SFTP configuration
    # This is a placeholder for remote file access
    []
  end

  def should_process_file?(file_info)
    # Check if file meets processing criteria
    return false if incremental_processing && file_already_processed?(file_info)
    return false if file_info[:size] < (min_file_size || 0)
    return false if max_file_size.present? && file_info[:size] > max_file_size

    # Check file age if specified
    if min_file_age_minutes.present?
      file_age_minutes = (Time.current - file_info[:modified_at]) / 60
      return false if file_age_minutes < min_file_age_minutes
    end

    true
  end

  def file_already_processed?(file_info)
    # Check if this file has been processed before based on name and modification time
    upload_logs.joins(:details).where(
      "details->>'processed_files' LIKE ?",
      "%#{file_info[:name]}%"
    ).where(
      "details->>'file_modified_at' = ?",
      file_info[:modified_at].iso8601
    ).exists?
  end

  def process_file(file_info)
    # Create a temporary uploaded file object
    temp_file = Tempfile.new([ File.basename(file_info[:name], ".*"), File.extname(file_info[:name]) ])

    begin
      # Copy file content to temp file
      FileUtils.cp(file_info[:path], temp_file.path)

      # Create an ActionDispatch::Http::UploadedFile-like object
      uploaded_file = ActionDispatch::Http::UploadedFile.new(
        tempfile: temp_file,
        filename: file_info[:name],
        type: MIME::Types.type_for(file_info[:name]).first&.content_type || "application/octet-stream"
      )

      # Process the file using the existing file processor
      processor = FileProcessorService.new(
        data_source: data_source,
        file: uploaded_file,
        user: user
      )

      result = processor.process

      {
        file_name: file_info[:name],
        file_path: file_info[:path],
        file_size: file_info[:size],
        file_modified_at: file_info[:modified_at].iso8601,
        processing_result: result,
        processed_at: Time.current.iso8601
      }
    ensure
      temp_file.close
      temp_file.unlink
    end
  end

  def set_next_run_at
    update_next_run_at! if next_run_at.nil?
  end

  def update_next_run_at!
    self.next_run_at = calculate_next_run_time
    save! if persisted?
  end

  def calculate_next_run_time
    return nil if frequency == "manual"

    base_time = next_run_at || Time.current

    case frequency
    when "hourly"
      base_time + 1.hour
    when "daily"
      base_time + 1.day
    when "weekly"
      base_time + 1.week
    when "monthly"
      base_time + 1.month
    else
      nil
    end
  end

  def send_notification_if_configured(log_entry)
    return unless notification_config.present?

    if notification_config["email"].present?
      ScheduledUploadMailer.execution_summary(
        scheduled_upload: self,
        log_entry: log_entry,
        recipients: notification_config["email"]
      ).deliver_later
    end

    # Add webhook notification if configured
    if notification_config["webhook_url"].present?
      ScheduledUploadWebhookJob.perform_later(
        webhook_url: notification_config["webhook_url"],
        scheduled_upload_id: id,
        log_entry_id: log_entry.id
      )
    end
  end
end
