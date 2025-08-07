class DataSource < ApplicationRecord
  include OptimizedScopes

  belongs_to :organization

  SOURCE_TYPES = %w[
    shopify quickbooks google_analytics stripe mailchimp
    zendesk hubspot google_ads facebook_ads woocommerce
    salesforce amazon_seller_central custom_api file_upload
  ].freeze

  STATUSES = %w[connected disconnected syncing error].freeze
  SYNC_FREQUENCIES = %w[realtime hourly daily weekly monthly].freeze

  has_many :extraction_jobs, dependent: :destroy
  has_many :raw_data_records, dependent: :destroy
  has_many :scheduled_uploads, dependent: :destroy
  has_many :visualizations, dependent: :destroy
  has_many :data_quality_reports, dependent: :destroy

  # AI-related associations
  has_many :ai_presentations, class_name: "Ai::Presentation", dependent: :nullify
  has_many :ai_insights, class_name: "Ai::Insight", dependent: :destroy
  has_many_attached :uploaded_files do |attachable|
    attachable.variant :preview, resize_to_limit: [ 300, 300 ]
  end

  encrypts :credentials, deterministic: false

  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :source_type, inclusion: { in: SOURCE_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :sync_frequency, inclusion: { in: SYNC_FREQUENCIES }
  validates :name, uniqueness: { scope: :organization_id }

  # File upload validations
  validate :acceptable_uploaded_files

  scope :connected, -> { where(status: "connected") }
  scope :active, -> { where(status: [ "connected", "syncing" ]) }
  scope :by_type, ->(type) { where(source_type: type) }
  scope :priority_1, -> { where(source_type: %w[shopify quickbooks google_analytics stripe mailchimp]) }

  before_validation :set_defaults, on: :create
  before_validation :normalize_name

  def connected?
    status == "connected"
  end

  def syncing?
    status == "syncing"
  end

  def error?
    status == "error"
  end

  def disconnected?
    status == "disconnected"
  end

  def needs_sync?
    return false unless connected?
    return true if next_sync_at.nil?

    next_sync_at <= Time.current
  end

  def priority_integration?
    %w[shopify quickbooks google_analytics stripe mailchimp].include?(source_type)
  end

  def can_connect?
    disconnected? || error?
  end

  def can_sync?
    connected? && !syncing?
  end

  def file_upload_source?
    source_type == "file_upload"
  end

  def has_uploaded_files?
    uploaded_files.attached?
  end

  def supported_file_types
    %w[text/csv application/vnd.ms-excel application/vnd.openxmlformats-officedocument.spreadsheetml.sheet application/json text/plain]
  end

  def file_type_display_names
    {
      "text/csv" => "CSV",
      "application/vnd.ms-excel" => "Excel (XLS)",
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" => "Excel (XLSX)",
      "application/json" => "JSON",
      "text/plain" => "Text"
    }
  end

  def sync_interval
    case sync_frequency
    when "realtime" then 5.minutes
    when "hourly" then 1.hour
    when "daily" then 1.day
    when "weekly" then 1.week
    when "monthly" then 1.month
    else 1.day
    end
  end

  def calculate_next_sync
    return nil unless connected?

    base_time = last_sync_at || Time.current
    base_time + sync_interval
  end

  def update_sync_schedule!
    update!(next_sync_at: calculate_next_sync)
  end

  def mark_syncing!
    update!(status: "syncing", error_message: nil)
  end

  def mark_sync_completed!
    update!(
      status: "connected",
      last_sync_at: Time.current,
      next_sync_at: calculate_next_sync,
      error_message: nil
    )
  end

  def mark_sync_failed!(error)
    update!(
      status: "error",
      error_message: error.to_s,
      next_sync_at: calculate_next_sync
    )
  end

  # Extractor integration methods
  def create_extractor
    ExtractorFactory.create_extractor(self)
  end

  def test_connection
    ExtractorFactory.test_connection(self)
  end

  def extract_data(job_id: nil)
    ExtractorFactory.extract_data(self, job_id: job_id)
  end

  def extraction_stats
    ExtractorFactory.extraction_stats(self)
  end

  def extractor_supported?
    ExtractorFactory.supported_source_type?(source_type)
  end

  def extractor_implemented?
    return false unless extractor_supported?

    metadata = ExtractorFactory.extractor_metadata[source_type]
    metadata&.dig(:implemented) || false
  end

  def supports_realtime?
    return false unless extractor_implemented?

    metadata = ExtractorFactory.extractor_metadata[source_type]
    metadata&.dig(:supports_realtime) || false
  end

  def sync_now!
    return false unless can_sync?

    ExtractionJobProcessor.perform_later(id)
    true
  end

  def configuration
    config || {}
  end

  def configuration=(new_config)
    self.config = new_config.is_a?(String) ? JSON.parse(new_config) : new_config
  end

  def source_display_name
    case source_type
    when "google_analytics" then "Google Analytics"
    when "facebook_ads" then "Facebook Ads"
    when "google_ads" then "Google Ads"
    when "amazon_seller_central" then "Amazon Seller Central"
    when "custom_api" then "Custom API"
    when "file_upload" then "File Upload"
    else source_type.humanize
    end
  end

  def latest_quality_report
    data_quality_reports.order(run_at: :desc).first
  end

  def quality_score
    latest_quality_report&.overall_score || 0
  end

  def has_quality_issues?
    latest_quality_report&.issues_count&.> 0
  end

  def run_quality_validation!
    DataQualityValidationJob.perform_later(self)
  end

  private

  def set_defaults
    self.status ||= "disconnected"
    self.sync_frequency ||= "daily"
    self.config ||= {}
  end

  def normalize_name
    self.name = name&.strip
  end

  def acceptable_uploaded_files
    return unless uploaded_files.attached?

    uploaded_files.each do |file|
      unless supported_file_types.include?(file.content_type)
        errors.add(:uploaded_files, "#{file.filename} must be a CSV, Excel, JSON, or text file")
      end

      unless file.byte_size <= 50.megabytes
        errors.add(:uploaded_files, "#{file.filename} must be less than 50MB")
      end
    end
  end
end
