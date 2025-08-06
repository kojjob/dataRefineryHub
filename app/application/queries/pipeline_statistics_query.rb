# frozen_string_literal: true

module Application
  module Queries
    # Query handler for pipeline statistics and analytics
    class PipelineStatisticsQuery
      include ActiveModel::Model

      attr_accessor :pipeline_id, :organization_id
      attr_accessor :start_date, :end_date
      attr_accessor :group_by # 'day', 'week', 'month'

      validates :organization_id, presence: true
      validate :validate_date_range

      def initialize(attributes = {})
        super
        @start_date ||= 30.days.ago
        @end_date ||= Time.current
        @group_by ||= "day"
      end

      def execute
        validate!

        if pipeline_id.present?
          single_pipeline_statistics
        else
          organization_statistics
        end
      end

      private

      def single_pipeline_statistics
        pipeline = repository.find(pipeline_id)
        return {} unless pipeline && pipeline.organization_id == organization_id

        executions = execution_records(pipeline_id)

        {
          pipeline_id: pipeline_id,
          pipeline_name: pipeline.name,
          period: {
            start: start_date,
            end: end_date
          },
          summary: calculate_summary(executions),
          time_series: calculate_time_series(executions),
          error_analysis: analyze_errors(executions),
          performance_metrics: calculate_performance_metrics(executions)
        }
      end

      def organization_statistics
        pipelines = repository.find_by_organization(organization_id)

        all_executions = pipelines.flat_map do |pipeline|
          execution_records(pipeline.id).map do |execution|
            execution.attributes.merge(pipeline_name: pipeline.name)
          end
        end

        {
          organization_id: organization_id,
          period: {
            start: start_date,
            end: end_date
          },
          summary: calculate_summary(all_executions),
          pipeline_breakdown: calculate_pipeline_breakdown(pipelines, all_executions),
          time_series: calculate_time_series(all_executions),
          top_errors: top_errors(all_executions),
          busiest_times: calculate_busiest_times(all_executions)
        }
      end

      def execution_records(pipeline_id)
        PipelineExecution
          .where(pipeline_id: pipeline_id)
          .where(created_at: start_date..end_date)
          .order(:created_at)
      end

      def calculate_summary(executions)
        total = executions.count
        successful = executions.count { |e| e["status"] == "success" }
        failed = executions.count { |e| e["status"] == "failed" }

        {
          total_executions: total,
          successful_executions: successful,
          failed_executions: failed,
          success_rate: total.positive? ? (successful.to_f / total * 100).round(2) : 0,
          total_rows_processed: executions.sum { |e| e["rows_processed"] || 0 },
          average_duration_seconds: calculate_average_duration(executions),
          total_duration_hours: executions.sum { |e| e["duration_seconds"] || 0 } / 3600.0
        }
      end

      def calculate_time_series(executions)
        grouped = group_executions_by_period(executions)

        grouped.map do |period, period_executions|
          {
            period: period,
            total: period_executions.count,
            successful: period_executions.count { |e| e["status"] == "success" },
            failed: period_executions.count { |e| e["status"] == "failed" },
            rows_processed: period_executions.sum { |e| e["rows_processed"] || 0 },
            average_duration: calculate_average_duration(period_executions)
          }
        end
      end

      def calculate_pipeline_breakdown(pipelines, executions)
        pipelines.map do |pipeline|
          pipeline_executions = executions.select { |e| e["pipeline_id"] == pipeline.id }

          {
            pipeline_id: pipeline.id,
            pipeline_name: pipeline.name,
            status: pipeline.status.value,
            executions: pipeline_executions.count,
            success_rate: calculate_success_rate(pipeline_executions),
            average_duration: calculate_average_duration(pipeline_executions),
            last_execution: pipeline_executions.max_by { |e| e["created_at"] }&.dig("created_at")
          }
        end.sort_by { |p| -p[:executions] }
      end

      def analyze_errors(executions)
        failed_executions = executions.select { |e| e["status"] == "failed" }

        error_groups = failed_executions.group_by { |e| e["error_message"] || "Unknown error" }

        error_groups.map do |error, instances|
          {
            error_message: error,
            count: instances.count,
            first_occurrence: instances.min_by { |e| e["created_at"] }["created_at"],
            last_occurrence: instances.max_by { |e| e["created_at"] }["created_at"],
            percentage: (instances.count.to_f / failed_executions.count * 100).round(2)
          }
        end.sort_by { |e| -e[:count] }.take(10)
      end

      def calculate_performance_metrics(executions)
        successful_executions = executions.select { |e| e["status"] == "success" }
        return {} if successful_executions.empty?

        durations = successful_executions.map { |e| e["duration_seconds"] || 0 }.sort
        rows_processed = successful_executions.map { |e| e["rows_processed"] || 0 }.sort

        {
          duration: {
            min: durations.first,
            max: durations.last,
            median: percentile(durations, 50),
            p95: percentile(durations, 95),
            p99: percentile(durations, 99)
          },
          rows_processed: {
            min: rows_processed.first,
            max: rows_processed.last,
            median: percentile(rows_processed, 50),
            average: rows_processed.sum.to_f / rows_processed.count
          },
          throughput: {
            average_rows_per_second: calculate_average_throughput(successful_executions),
            peak_rows_per_second: calculate_peak_throughput(successful_executions)
          }
        }
      end

      def calculate_busiest_times(executions)
        by_hour = executions.group_by { |e| e["created_at"].hour }
        by_day = executions.group_by { |e| e["created_at"].wday }

        {
          busiest_hours: by_hour.transform_values(&:count).sort_by { |_, v| -v }.take(5).to_h,
          busiest_days: by_day.transform_values(&:count).sort_by { |_, v| -v }.map do |day, count|
            { day: Date::DAYNAMES[day], count: count }
          end
        }
      end

      def top_errors(executions)
        failed = executions.select { |e| e["status"] == "failed" }

        failed.group_by { |e| e["error_message"] || "Unknown error" }
              .transform_values(&:count)
              .sort_by { |_, v| -v }
              .take(5)
              .map { |error, count| { error: error, count: count } }
      end

      def group_executions_by_period(executions)
        case group_by
        when "day"
          executions.group_by { |e| e["created_at"].to_date }
        when "week"
          executions.group_by { |e| e["created_at"].beginning_of_week.to_date }
        when "month"
          executions.group_by { |e| e["created_at"].beginning_of_month.to_date }
        else
          executions.group_by { |e| e["created_at"].to_date }
        end
      end

      def calculate_average_duration(executions)
        durations = executions.map { |e| e["duration_seconds"] || 0 }.compact
        return 0 if durations.empty?

        (durations.sum.to_f / durations.count).round(2)
      end

      def calculate_success_rate(executions)
        return 0 if executions.empty?

        successful = executions.count { |e| e["status"] == "success" }
        (successful.to_f / executions.count * 100).round(2)
      end

      def calculate_average_throughput(executions)
        throughputs = executions.map do |e|
          next 0 if e["duration_seconds"].nil? || e["duration_seconds"].zero?
          (e["rows_processed"] || 0).to_f / e["duration_seconds"]
        end.compact

        return 0 if throughputs.empty?
        (throughputs.sum / throughputs.count).round(2)
      end

      def calculate_peak_throughput(executions)
        executions.map do |e|
          next 0 if e["duration_seconds"].nil? || e["duration_seconds"].zero?
          (e["rows_processed"] || 0).to_f / e["duration_seconds"]
        end.compact.max || 0
      end

      def percentile(values, percentile)
        return 0 if values.empty?

        k = (percentile / 100.0) * (values.count - 1)
        f = k.floor
        c = k.ceil

        return values[f] if f == c

        d0 = values[f] * (c - k)
        d1 = values[c] * (k - f)
        d0 + d1
      end

      def validate_date_range
        if start_date && end_date && start_date > end_date
          errors.add(:start_date, "must be before end date")
        end
      end

      def repository
        @repository ||= Infrastructure::Persistence::Repositories::ActiveRecordPipelineRepository.new
      end
    end
  end
end
