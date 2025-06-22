# frozen_string_literal: true

# Pipeline Execution Model
# Tracks the execution of ETL pipelines for monitoring and auditing
class PipelineExecution < ApplicationRecord
  belongs_to :data_source, optional: true
  belongs_to :user, optional: true

  validates :execution_id, presence: true, uniqueness: true
  validates :pipeline_name, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending running completed failed cancelled] }
  validates :started_at, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :successful, -> { where(status: "completed") }
  scope :failed, -> { where(status: "failed") }
  scope :running, -> { where(status: "running") }
  scope :for_pipeline, ->(name) { where(pipeline_name: name) }
  scope :for_data_source, ->(id) { where(data_source_id: id) }
  scope :within_timeframe, ->(start_time, end_time) { where(created_at: start_time..end_time) }

  before_create :set_defaults
  after_update :update_metrics, if: :saved_change_to_status?

  # Serialized attributes for storing complex data
  serialize :parameters, JSON
  serialize :result_summary, JSON
  serialize :error_details, JSON

  def duration
    return nil unless started_at && completed_at
    completed_at - started_at
  end

  def duration_in_seconds
    duration&.to_i
  end

  def duration_formatted
    return "N/A" unless duration

    seconds = duration.to_i
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    secs = seconds % 60

    if hours > 0
      "#{hours}h #{minutes}m #{secs}s"
    elsif minutes > 0
      "#{minutes}m #{secs}s"
    else
      "#{secs}s"
    end
  end

  def success?
    status == "completed"
  end

  def failed?
    status == "failed"
  end

  def running?
    status == "running"
  end

  def completed?
    %w[completed failed cancelled].include?(status)
  end

  def cancel!
    return false if completed?

    update!(
      status: "cancelled",
      completed_at: Time.current,
      error_message: "Execution cancelled by user"
    )
  end

  def progress_percentage
    return 0 unless progress
    [ progress, 100 ].min
  end

  def estimated_completion_time
    return nil unless running? && progress && progress > 0

    elapsed_time = Time.current - started_at
    estimated_total_time = elapsed_time * (100.0 / progress)
    started_at + estimated_total_time
  end

  def to_summary_hash
    {
      id: id,
      execution_id: execution_id,
      pipeline_name: pipeline_name,
      status: status,
      progress: progress,
      current_stage: current_stage,
      started_at: started_at,
      completed_at: completed_at,
      duration: duration_formatted,
      data_source_id: data_source_id,
      data_source_name: data_source&.name,
      user_id: user_id,
      user_name: user&.name,
      error_message: error_message,
      parameters: parameters
    }
  end

  def to_detailed_hash
    summary = to_summary_hash
    summary.merge({
      result_summary: result_summary,
      error_details: error_details,
      created_at: created_at,
      updated_at: updated_at
    })
  end

  # Class methods for analytics and reporting
  class << self
    def success_rate(timeframe = 24.hours)
      end_time = Time.current
      start_time = end_time - timeframe

      total = within_timeframe(start_time, end_time).where.not(status: "pending").count
      return 100.0 if total.zero?

      successful = within_timeframe(start_time, end_time).successful.count
      (successful.to_f / total * 100).round(2)
    end

    def average_duration(timeframe = 24.hours)
      end_time = Time.current
      start_time = end_time - timeframe

      completed_executions = within_timeframe(start_time, end_time)
                           .successful
                           .where.not(completed_at: nil)

      return 0 if completed_executions.empty?

      total_duration = completed_executions.sum(&:duration_in_seconds)
      (total_duration.to_f / completed_executions.count).round(2)
    end

    def pipeline_statistics(pipeline_name, timeframe = 7.days)
      end_time = Time.current
      start_time = end_time - timeframe

      executions = for_pipeline(pipeline_name).within_timeframe(start_time, end_time)

      {
        total_executions: executions.count,
        successful_executions: executions.successful.count,
        failed_executions: executions.failed.count,
        success_rate: calculate_success_rate(executions),
        average_duration: calculate_average_duration(executions.successful),
        last_execution: executions.recent.first&.to_summary_hash,
        failure_reasons: get_failure_reasons(executions.failed)
      }
    end

    def data_source_statistics(data_source_id, timeframe = 7.days)
      end_time = Time.current
      start_time = end_time - timeframe

      executions = for_data_source(data_source_id).within_timeframe(start_time, end_time)

      {
        total_executions: executions.count,
        successful_executions: executions.successful.count,
        failed_executions: executions.failed.count,
        success_rate: calculate_success_rate(executions),
        average_duration: calculate_average_duration(executions.successful),
        pipelines_used: executions.distinct.pluck(:pipeline_name),
        recent_executions: executions.recent.limit(10).map(&:to_summary_hash)
      }
    end

    def daily_execution_counts(days = 30)
      end_date = Date.current
      start_date = end_date - days.days

      (start_date..end_date).map do |date|
        day_start = date.beginning_of_day
        day_end = date.end_of_day

        executions = within_timeframe(day_start, day_end)

        {
          date: date,
          total: executions.count,
          successful: executions.successful.count,
          failed: executions.failed.count,
          running: executions.running.count
        }
      end
    end

    def pipeline_performance_trends(pipeline_name, days = 30)
      end_date = Date.current
      start_date = end_date - days.days

      (start_date..end_date).map do |date|
        day_start = date.beginning_of_day
        day_end = date.end_of_day

        executions = for_pipeline(pipeline_name).within_timeframe(day_start, day_end)
        successful_executions = executions.successful

        {
          date: date,
          executions: executions.count,
          success_rate: calculate_success_rate(executions),
          average_duration: calculate_average_duration(successful_executions)
        }
      end
    end

    def get_active_executions
      running.includes(:data_source, :user).map(&:to_summary_hash)
    end

    def get_recent_failures(limit = 10)
      failed.recent.limit(limit).includes(:data_source, :user).map do |execution|
        summary = execution.to_summary_hash
        summary[:error_details] = execution.error_details
        summary
      end
    end

    def cleanup_old_executions(retention_days = 90)
      cutoff_date = retention_days.days.ago
      old_executions = where("created_at < ?", cutoff_date)

      Rails.logger.info "Cleaning up #{old_executions.count} old pipeline executions"
      old_executions.delete_all
    end

    private

    def calculate_success_rate(executions)
      total = executions.where.not(status: "pending").count
      return 100.0 if total.zero?

      successful = executions.successful.count
      (successful.to_f / total * 100).round(2)
    end

    def calculate_average_duration(executions)
      completed = executions.where.not(completed_at: nil)
      return 0 if completed.empty?

      total_duration = completed.sum { |e| e.duration_in_seconds }
      (total_duration.to_f / completed.count).round(2)
    end

    def get_failure_reasons(failed_executions)
      failed_executions.where.not(error_message: nil)
                      .group(:error_message)
                      .count
                      .sort_by { |_, count| -count }
                      .first(5)
                      .to_h
    end
  end

  private

  def set_defaults
    self.execution_id ||= SecureRandom.uuid
    self.status ||= "pending"
    self.started_at ||= Time.current
    self.progress ||= 0
    self.parameters ||= {}
  end

  def update_metrics
    # Update monitoring metrics when status changes
    EtlMonitoringService.instance.record_pipeline_status_change(
      pipeline_name,
      status,
      {
        execution_id: execution_id,
        data_source_id: data_source_id,
        duration: duration_in_seconds,
        error_message: error_message
      }
    )
  rescue => e
    Rails.logger.error "Failed to update pipeline metrics: #{e.message}"
    # Don't raise the error to avoid breaking the pipeline execution update
  end
end
