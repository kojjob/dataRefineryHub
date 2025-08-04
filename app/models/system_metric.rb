# frozen_string_literal: true

class SystemMetric < ApplicationRecord
  belongs_to :organization

  validates :recorded_at, presence: true
  validates :cpu_usage, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validates :memory_usage, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validates :storage_usage, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true

  scope :recent, -> { order(recorded_at: :desc) }
  scope :for_period, ->(start_time, end_time) { where(recorded_at: start_time..end_time) }
  scope :latest, -> { order(recorded_at: :desc).first }

  def healthy?
    cpu_usage.to_f < 80 && memory_usage.to_f < 80 && storage_usage.to_f < 80
  end

  def critical?
    cpu_usage.to_f > 90 || memory_usage.to_f > 90 || storage_usage.to_f > 90
  end

  def warning?
    !healthy? && !critical?
  end

  def resource_status
    return 'critical' if critical?
    return 'warning' if warning?
    'healthy'
  end

  def to_percentage_hash
    {
      cpu_usage: cpu_usage&.to_f || 0,
      memory_usage: memory_usage&.to_f || 0,
      storage_usage: storage_usage&.to_f || 0
    }
  end
end