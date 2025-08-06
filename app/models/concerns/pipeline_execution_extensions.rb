# frozen_string_literal: true

# Extension for PipelineExecution model
# Add this to your app/models/pipeline_execution.rb file

class PipelineExecution < ApplicationRecord
  belongs_to :organization
  belongs_to :data_source
  has_many :pipeline_metrics, dependent: :destroy

  # Calculate progress percentage
  def progress_percentage
    return 0 if total_records.nil? || total_records.zero?
    return 100 if status == "completed"
    return 0 if status == "pending" || status == "initializing"

    ((records_processed.to_f / total_records) * 100).round(1)
  end

  # Get destination type from config or default
  def destination_type
    execution_config&.dig("destination", "type") ||
    destination_config&.dig("type") ||
    "data_warehouse"
  end

  # Check if pipeline is active
  def active?
    %w[running pending initializing].include?(status)
  end

  # Get latest metric
  def latest_metric
    pipeline_metrics.order(recorded_at: :desc).first
  end

  # Calculate estimated time to completion
  def estimated_completion_time
    return nil unless status == "running" && latest_metric.present?

    records_remaining = total_records - records_processed
    records_per_second = latest_metric.records_per_second

    return nil if records_per_second.zero?

    seconds_remaining = records_remaining / records_per_second
    started_at + seconds_remaining.seconds
  end
end
