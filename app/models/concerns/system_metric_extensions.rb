# frozen_string_literal: true

# Extension for SystemMetric model
# Add this to your app/models/system_metric.rb file

class SystemMetric < ApplicationRecord
  belongs_to :organization

  # Convert raw values to percentages for display
  def to_percentage_hash
    {
      cpu_usage: cpu_usage || 0,
      memory_usage: memory_usage || 0,
      storage_usage: storage_usage || 0
    }
  end

  # Helper method to check if any metric is critical
  def critical?
    cpu_usage > 90 || memory_usage > 90 || storage_usage > 90
  end

  # Helper method to check if any metric is warning level
  def warning?
    !critical? && (cpu_usage > 70 || memory_usage > 70 || storage_usage > 80)
  end
end
