# frozen_string_literal: true

class PipelineMetric < ApplicationRecord
  belongs_to :pipeline_execution
  belongs_to :organization

  validates :recorded_at, presence: true
  validates :records_per_second, numericality: { greater_than_or_equal_to: 0 }
  validates :cpu_usage, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validates :memory_usage_gb, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :recent, -> { order(recorded_at: :desc) }
  scope :for_period, ->(start_time, end_time) { where(recorded_at: start_time..end_time) }

  def performance_status
    return "optimal" if records_per_second > 100 && cpu_usage.to_f < 70
    return "degraded" if records_per_second < 50 || cpu_usage.to_f > 85
    "normal"
  end

  def efficiency_score
    return 0 if records_per_second == 0 || cpu_usage.nil?
    (records_per_second / (cpu_usage.to_f + 1)) * 100
  end
end
