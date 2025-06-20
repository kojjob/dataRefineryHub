class ExtractionJob < ApplicationRecord
  belongs_to :data_source
  has_one :organization, through: :data_source
  has_many :raw_data_records, dependent: :destroy

  STATUSES = %w[queued running completed failed cancelled retrying].freeze
  PRIORITIES = %w[low normal high critical].freeze

  validates :job_id, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :priority, inclusion: { in: PRIORITIES }
  validates :retry_count, numericality: { greater_than_or_equal_to: 0 }
  validates :max_retries, numericality: { greater_than_or_equal_to: 0 }

  scope :by_status, ->(status) { where(status: status) }
  scope :by_priority, ->(priority) { where(priority: priority) }
  scope :needs_retry, -> { where(status: 'failed', 'next_retry_at <= ?': Time.current) }
  scope :running, -> { where(status: 'running') }
  scope :completed, -> { where(status: 'completed') }
  scope :successful, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :recent, -> { order(created_at: :desc) }

  before_validation :generate_job_id, on: :create
  before_validation :set_defaults, on: :create

  def queued?
    status == 'queued'
  end

  def running?
    status == 'running'
  end

  def completed?
    status == 'completed'
  end

  def failed?
    status == 'failed'
  end

  def cancelled?
    status == 'cancelled'
  end

  def retrying?
    status == 'retrying'
  end

  def can_retry?
    failed? && retry_count < max_retries && (next_retry_at.nil? || next_retry_at <= Time.current)
  end

  def can_cancel?
    queued? || running? || retrying?
  end

  def duration
    return nil unless started_at
    
    end_time = completed_at || Time.current
    end_time - started_at
  end

  def success_rate
    return 0 if records_processed.to_i.zero?
    
    ((records_processed - records_failed) / records_processed.to_f * 100).round(2)
  end

  def processing_speed
    return 0 unless completed? && duration && duration > 0
    
    (records_processed.to_f / duration).round(2)
  end

  def mark_as_running!
    update!(
      status: 'running',
      started_at: Time.current,
      error_details: nil
    )
  end

  def mark_as_completed!(processed_count: 0, failed_count: 0, metadata: {})
    update!(
      status: 'completed',
      completed_at: Time.current,
      records_processed: processed_count,
      records_failed: failed_count,
      extraction_metadata: metadata.merge(completed_at: Time.current),
      error_details: nil
    )
  end

  def mark_as_failed!(error, should_retry: true)
    self.retry_count += 1
    new_status = should_retry && can_retry? ? 'retrying' : 'failed'
    
    update!(
      status: new_status,
      completed_at: Time.current,
      error_details: format_error_details(error),
      next_retry_at: calculate_next_retry_time
    )
  end

  def mark_as_cancelled!
    update!(
      status: 'cancelled',
      completed_at: Time.current
    )
  end

  def retry_job!
    return false unless can_retry?
    
    update!(
      status: 'queued',
      started_at: nil,
      completed_at: nil,
      next_retry_at: nil,
      error_details: nil
    )
    
    # Re-enqueue the job
    ExtractDataJob.perform_later(self)
    true
  end

  def log_progress(processed:, failed: 0, metadata: {})
    update!(
      records_processed: processed,
      records_failed: failed,
      extraction_metadata: (extraction_metadata || {}).merge(metadata).merge(
        last_updated: Time.current,
        progress_percentage: calculate_progress_percentage(processed)
      )
    )
  end

  def estimated_completion_time
    return nil unless running? && records_processed.to_i > 0
    return nil unless extraction_metadata&.dig('total_records_estimate')
    
    total_estimate = extraction_metadata['total_records_estimate']
    current_speed = processing_speed
    return nil if current_speed.zero?
    
    remaining_records = total_estimate - records_processed
    remaining_seconds = remaining_records / current_speed
    
    Time.current + remaining_seconds.seconds
  end

  def priority_score
    base_score = case priority
                when 'critical' then 100
                when 'high' then 75
                when 'normal' then 50
                when 'low' then 25
                else 50
                end
    
    # Boost score for retries
    base_score += (retry_count * 10)
    
    # Boost score for priority data sources
    base_score += 25 if data_source.priority_integration?
    
    base_score
  end

  private

  def generate_job_id
    self.job_id ||= "extract_#{data_source.source_type}_#{SecureRandom.hex(8)}"
  end

  def set_defaults
    self.status ||= 'queued'
    self.priority ||= 'normal'
    self.retry_count ||= 0
    self.max_retries ||= 3
    self.records_processed ||= 0
    self.records_failed ||= 0
    self.extraction_metadata ||= {}
  end

  def calculate_next_retry_time
    return nil unless retry_count > 0
    
    # Exponential backoff: 5 minutes * 2^(retry_count-1)
    delay_minutes = 5 * (2 ** (retry_count - 1))
    Time.current + delay_minutes.minutes
  end

  def format_error_details(error)
    {
      message: error.message,
      class: error.class.name,
      backtrace: error.backtrace&.first(10),
      timestamp: Time.current,
      retry_count: retry_count,
      data_source_id: data_source.id,
      data_source_type: data_source.source_type
    }
  end

  def calculate_progress_percentage(processed_count)
    total_estimate = extraction_metadata&.dig('total_records_estimate')
    return nil unless total_estimate && total_estimate > 0
    
    ((processed_count.to_f / total_estimate) * 100).round(2)
  end
end
