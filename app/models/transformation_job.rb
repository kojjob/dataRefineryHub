class TransformationJob < ApplicationRecord
  belongs_to :organization

  TRANSFORMATION_TYPES = %w[
    customer_deduplication order_normalization product_enrichment
    currency_conversion address_standardization phone_normalization
    email_validation data_classification rfm_calculation
    revenue_recognition churn_prediction inventory_optimization
  ].freeze

  STATUSES = %w[queued running completed failed cancelled paused].freeze

  validates :job_id, presence: true, uniqueness: true
  validates :transformation_type, inclusion: { in: TRANSFORMATION_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :input_records_count, numericality: { greater_than_or_equal_to: 0 }
  validates :output_records_count, numericality: { greater_than_or_equal_to: 0 }

  scope :by_type, ->(type) { where(transformation_type: type) }
  scope :by_status, ->(status) { where(status: status) }
  scope :running, -> { where(status: "running") }
  scope :completed, -> { where(status: "completed") }
  scope :failed, -> { where(status: "failed") }
  scope :recent, -> { order(created_at: :desc) }

  before_validation :generate_job_id, on: :create
  before_validation :set_defaults, on: :create

  def queued?
    status == "queued"
  end

  def running?
    status == "running"
  end

  def completed?
    status == "completed"
  end

  def failed?
    status == "failed"
  end

  def cancelled?
    status == "cancelled"
  end

  def paused?
    status == "paused"
  end

  def can_start?
    queued? || paused?
  end

  def can_pause?
    running?
  end

  def can_cancel?
    queued? || running? || paused?
  end

  def duration
    return nil unless started_at

    end_time = completed_at || Time.current
    end_time - started_at
  end

  def success_rate
    return 0 if input_records_count.to_i.zero?

    ((output_records_count.to_f / input_records_count) * 100).round(2)
  end

  def processing_speed
    return 0 unless completed? && duration && duration > 0

    (output_records_count.to_f / duration).round(2)
  end

  def data_quality_score
    return 0 unless data_quality_metrics.present?

    metrics = data_quality_metrics

    # Calculate weighted quality score
    completeness = metrics["completeness_score"] || 0
    accuracy = metrics["accuracy_score"] || 0
    consistency = metrics["consistency_score"] || 0
    validity = metrics["validity_score"] || 0

    # Weighted average: completeness 30%, accuracy 40%, consistency 20%, validity 10%
    (completeness * 0.3 + accuracy * 0.4 + consistency * 0.2 + validity * 0.1).round(2)
  end

  def mark_as_running!
    update!(
      status: "running",
      started_at: Time.current,
      error_details: nil
    )
  end

  def mark_as_completed!(output_count: 0, quality_metrics: {})
    update!(
      status: "completed",
      completed_at: Time.current,
      output_records_count: output_count,
      data_quality_metrics: quality_metrics.merge(completed_at: Time.current),
      error_details: nil
    )
  end

  def mark_as_failed!(error)
    update!(
      status: "failed",
      completed_at: Time.current,
      error_details: format_error_details(error)
    )
  end

  def mark_as_cancelled!
    update!(
      status: "cancelled",
      completed_at: Time.current
    )
  end

  def mark_as_paused!
    update!(status: "paused")
  end

  def resume!
    return false unless paused?

    update!(status: "running")
    # Re-enqueue the job
    TransformDataJob.perform_later(self)
    true
  end

  def log_progress(processed_count:, quality_metrics: {})
    current_metrics = data_quality_metrics || {}

    update!(
      output_records_count: processed_count,
      data_quality_metrics: current_metrics.merge(quality_metrics).merge(
        last_updated: Time.current,
        progress_percentage: calculate_progress_percentage(processed_count)
      )
    )
  end

  def estimated_completion_time
    return nil unless running? && output_records_count > 0
    return nil if input_records_count <= 0

    current_speed = processing_speed
    return nil if current_speed <= 0

    remaining_records = input_records_count - output_records_count
    remaining_seconds = remaining_records / current_speed

    Time.current + remaining_seconds.seconds
  end

  def transformation_efficiency
    return 0 unless completed? && duration && duration > 0

    # Records per second
    (input_records_count.to_f / duration).round(2)
  end

  def improvement_metrics
    return {} unless data_quality_metrics.present?

    before_quality = transformation_rules&.dig("quality_baseline") || {}
    after_quality = data_quality_metrics

    {
      completeness_improvement: calculate_improvement(before_quality["completeness_score"], after_quality["completeness_score"]),
      accuracy_improvement: calculate_improvement(before_quality["accuracy_score"], after_quality["accuracy_score"]),
      consistency_improvement: calculate_improvement(before_quality["consistency_score"], after_quality["consistency_score"]),
      overall_quality_improvement: calculate_improvement(before_quality["overall_score"], data_quality_score)
    }
  end

  def transformation_display_name
    case transformation_type
    when "customer_deduplication" then "Customer Deduplication"
    when "order_normalization" then "Order Data Normalization"
    when "product_enrichment" then "Product Data Enrichment"
    when "currency_conversion" then "Currency Conversion"
    when "address_standardization" then "Address Standardization"
    when "phone_normalization" then "Phone Number Normalization"
    when "email_validation" then "Email Address Validation"
    when "data_classification" then "Data Classification"
    when "rfm_calculation" then "RFM Analysis Calculation"
    when "revenue_recognition" then "Revenue Recognition"
    when "churn_prediction" then "Customer Churn Prediction"
    when "inventory_optimization" then "Inventory Optimization"
    else transformation_type.humanize
    end
  end

  def self.performance_metrics(date_range = 1.week.ago..Time.current)
    jobs = where(created_at: date_range)
    total_count = jobs.count

    return { total_jobs: 0 } if total_count.zero?

    completed_jobs = jobs.completed

    {
      total_jobs: total_count,
      completed_jobs: completed_jobs.count,
      failed_jobs: jobs.failed.count,
      success_rate: (completed_jobs.count.to_f / total_count * 100).round(2),
      average_duration: calculate_average_duration(completed_jobs),
      average_processing_speed: calculate_average_processing_speed(completed_jobs),
      average_quality_score: calculate_average_quality_score(completed_jobs),
      transformation_type_breakdown: jobs.group(:transformation_type).count,
      status_breakdown: jobs.group(:status).count,
      total_records_processed: completed_jobs.sum(:input_records_count),
      total_records_output: completed_jobs.sum(:output_records_count)
    }
  end

  private

  def generate_job_id
    self.job_id ||= "transform_#{transformation_type}_#{SecureRandom.hex(8)}"
  end

  def set_defaults
    self.status ||= "queued"
    self.input_records_count ||= 0
    self.output_records_count ||= 0
    self.transformation_rules ||= {}
    self.data_quality_metrics ||= {}
  end

  def calculate_progress_percentage(processed_count)
    return 0 if input_records_count <= 0

    ((processed_count.to_f / input_records_count) * 100).round(2)
  end

  def format_error_details(error)
    {
      message: error.message,
      class: error.class.name,
      backtrace: error.backtrace&.first(10),
      timestamp: Time.current,
      transformation_type: transformation_type,
      organization_id: organization.id,
      input_records_count: input_records_count
    }
  end

  def calculate_improvement(before_score, after_score)
    return 0 unless before_score && after_score && before_score > 0

    ((after_score - before_score) / before_score.to_f * 100).round(2)
  end

  def self.calculate_average_duration(jobs)
    completed_jobs = jobs.where.not(started_at: nil, completed_at: nil)
    return 0 if completed_jobs.empty?

    total_duration = completed_jobs.sum { |job| job.completed_at - job.started_at }
    (total_duration / completed_jobs.count).round(2)
  end

  def self.calculate_average_processing_speed(jobs)
    completed_jobs = jobs.where.not(started_at: nil, completed_at: nil)
    return 0 if completed_jobs.empty?

    total_speed = completed_jobs.sum(&:processing_speed)
    (total_speed / completed_jobs.count).round(2)
  end

  def self.calculate_average_quality_score(jobs)
    jobs_with_quality = jobs.where.not(data_quality_metrics: [ nil, {} ])
    return 0 if jobs_with_quality.empty?

    total_score = jobs_with_quality.sum(&:data_quality_score)
    (total_score / jobs_with_quality.count).round(2)
  end
end
