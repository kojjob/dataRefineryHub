class UploadLog < ApplicationRecord
  belongs_to :scheduled_upload

  validates :status, presence: true, inclusion: { in: %w[pending running completed completed_with_errors failed] }
  validates :started_at, presence: true

  scope :recent, -> { where('started_at >= ?', 7.days.ago).order(created_at: :desc) }
  scope :successful, -> { where(status: ['completed', 'completed_with_errors']) }
  scope :failed, -> { where(status: 'failed') }
  scope :running, -> { where(status: 'running') }

  def duration
    return nil unless started_at && completed_at
    (completed_at - started_at).to_i
  end

  def duration_in_words
    return 'Still running' unless completed_at
    return 'Less than a second' if duration < 1
    
    distance_of_time_in_words(started_at, completed_at)
  end

  def success?
    status.in?(['completed', 'completed_with_errors'])
  end

  def failure?
    status == 'failed'
  end

  def running?
    status == 'running'
  end

  def summary
    case status
    when 'completed'
      "Successfully processed #{files_processed || 0} files"
    when 'completed_with_errors'
      "Processed #{files_processed || 0} files with #{files_failed || 0} errors"
    when 'failed'
      "Execution failed: #{details&.dig('error') || 'Unknown error'}"
    when 'running'
      "Currently running (started #{time_ago_in_words(started_at)} ago)"
    else
      status.humanize
    end
  end

  def error_details
    return nil unless details.present?
    
    errors = details['errors'] || []
    error_message = details['error']
    
    if error_message.present?
      [error_message]
    elsif errors.any?
      errors
    else
      nil
    end
  end

  def processed_files_details
    return [] unless details.present? && details['processed_files'].present?
    
    details['processed_files']
  end

  def error_summary
    return [] unless details.present?
    
    errors = details['errors'] || []
    return [] if errors.empty?
    
    errors.map do |error|
      "#{error['file']}: #{error['error']}"
    end
  end

  def processed_files_summary
    return [] unless details.present? && details['processed_files'].present?
    
    details['processed_files'].map do |file|
      "#{file['name']} (#{file['records']} records)"
    end
  end

  def status_color
    case status
    when 'completed'
      'green'
    when 'completed_with_errors'
      'yellow'
    when 'failed'
      'red'
    when 'running'
      'blue'
    else
      'gray'
    end
  end

  private

  def distance_of_time_in_words(from_time, to_time)
    # Simple implementation - can be enhanced with ActionView helpers
    seconds = (to_time - from_time).to_i
    
    case seconds
    when 0..59
      "#{seconds} seconds"
    when 60..3599
      minutes = seconds / 60
      "#{minutes} minutes"
    when 3600..86399
      hours = seconds / 3600
      "#{hours} hours"
    else
      days = seconds / 86400
      "#{days} days"
    end
  end

  def time_ago_in_words(time)
    distance_of_time_in_words(time, Time.current)
  end
end