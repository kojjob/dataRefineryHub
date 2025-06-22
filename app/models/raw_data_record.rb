class RawDataRecord < ApplicationRecord
  belongs_to :organization
  belongs_to :data_source
  belongs_to :extraction_job

  RECORD_TYPES = %w[
    customer order product invoice payment subscription
    session pageview conversion campaign email_campaign
    support_ticket lead contact deal
  ].freeze

  PROCESSING_STATUSES = %w[pending processing processed failed skipped].freeze

  encrypts :encrypted_payload, deterministic: false
  has_encrypted :raw_data

  validates :record_type, inclusion: { in: RECORD_TYPES }
  validates :external_id, presence: true
  validates :processing_status, inclusion: { in: PROCESSING_STATUSES }
  validates :checksum, presence: true, uniqueness: { scope: [ :data_source_id, :external_id ] }

  scope :by_type, ->(type) { where(record_type: type) }
  scope :by_status, ->(status) { where(processing_status: status) }
  scope :pending_processing, -> { where(processing_status: "pending") }
  scope :processed, -> { where(processing_status: "processed") }
  scope :failed, -> { where(processing_status: "failed") }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_date_range, ->(start_date, end_date) { where(created_at: start_date..end_date) }

  before_validation :generate_checksum, on: :create
  before_validation :set_defaults, on: :create

  def pending?
    processing_status == "pending"
  end

  def processing?
    processing_status == "processing"
  end

  def processed?
    processing_status == "processed"
  end

  def failed?
    processing_status == "failed"
  end

  def skipped?
    processing_status == "skipped"
  end

  def can_process?
    pending? || failed?
  end

  def can_reprocess?
    processed? || failed? || skipped?
  end

  def payload_data
    return {} if encrypted_payload.blank?

    JSON.parse(decrypt_payload)
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse payload for RawDataRecord #{id}: #{e.message}"
    {}
  end

  def set_payload_data(data)
    self.encrypted_payload = encrypt_payload(data.to_json)
    generate_checksum
  end

  def mark_as_processing!
    update!(processing_status: "processing", processed_at: nil, validation_errors: nil)
  end

  def mark_as_processed!
    update!(
      processing_status: "processed",
      processed_at: Time.current,
      validation_errors: nil
    )
  end

  def mark_as_failed!(errors)
    validation_errors = case errors
    when String then [ errors ]
    when Array then errors
    when Hash then errors.values.flatten
    else [ errors.to_s ]
    end

    update!(
      processing_status: "failed",
      processed_at: Time.current,
      validation_errors: {
        errors: validation_errors,
        failed_at: Time.current,
        record_type: record_type,
        external_id: external_id
      }
    )
  end

  def mark_as_skipped!(reason)
    update!(
      processing_status: "skipped",
      processed_at: Time.current,
      validation_errors: {
        skip_reason: reason,
        skipped_at: Time.current
      }
    )
  end

  def has_validation_errors?
    validation_errors.present? && validation_errors["errors"].present?
  end

  def validation_error_summary
    return nil unless has_validation_errors?

    errors = validation_errors["errors"]
    case errors.length
    when 1 then errors.first
    when 2..3 then errors.join(", ")
    else "#{errors.first} and #{errors.length - 1} other errors"
    end
  end

  def data_size_bytes
    encrypted_payload&.bytesize || 0
  end

  def is_duplicate?
    self.class.exists?(
      data_source: data_source,
      external_id: external_id,
      checksum: checksum
    ) && !persisted?
  end

  def similar_records
    self.class.where(
      data_source: data_source,
      external_id: external_id
    ).where.not(id: id)
  end

  def data_freshness
    return nil unless extraction_job&.completed_at

    Time.current - extraction_job.completed_at
  end

  def self.cleanup_old_records(days_to_keep = 90)
    cutoff_date = days_to_keep.days.ago
    where("created_at < ?", cutoff_date).destroy_all
  end

  def self.data_quality_metrics(date_range = 1.week.ago..Time.current)
    records = where(created_at: date_range)
    total_count = records.count

    return { total_records: 0 } if total_count.zero?

    {
      total_records: total_count,
      processed_count: records.processed.count,
      failed_count: records.failed.count,
      skipped_count: records.skipped.count,
      success_rate: (records.processed.count.to_f / total_count * 100).round(2),
      failure_rate: (records.failed.count.to_f / total_count * 100).round(2),
      average_processing_time: calculate_average_processing_time(records),
      data_volume_mb: (records.sum(:data_size_bytes) / 1024.0 / 1024.0).round(2),
      record_types: records.group(:record_type).count,
      processing_status_breakdown: records.group(:processing_status).count
    }
  end

  private

  def generate_checksum
    return unless raw_data.present? || encrypted_payload.present?

    content = encrypted_payload.present? ? encrypted_payload : raw_data.to_s
    self.checksum = Digest::SHA256.hexdigest("#{external_id}:#{content}")
  end

  def set_defaults
    self.processing_status ||= "pending"
    self.validation_errors ||= {}
  end

  def encrypt_payload(data)
    # Using Rails built-in encryption
    self.class.encrypt_value_for(:encrypted_payload, data)
  end

  def decrypt_payload
    # Using Rails built-in decryption
    self.class.decrypt_value_for(:encrypted_payload, encrypted_payload)
  end

  def self.calculate_average_processing_time(records)
    processed_records = records.processed.where.not(processed_at: nil)
    return 0 if processed_records.empty?

    total_time = processed_records.sum do |record|
      next 0 unless record.processed_at && record.created_at

      record.processed_at - record.created_at
    end

    (total_time / processed_records.count).round(2)
  end
end
