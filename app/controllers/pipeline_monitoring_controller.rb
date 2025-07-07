# Pipeline Monitoring Controller
# Real-time monitoring and analytics for ETL/ELT pipeline executions
class PipelineMonitoringController < ApplicationController
  before_action :authenticate_user!

  def index
    @active_executions = current_organization.pipeline_executions
                                          .where(status: [ "running", "pending" ])
                                          .includes(:data_source, :user)
                                          .order(started_at: :desc)

    @recent_completions = current_organization.pipeline_executions
                                           .where(status: [ "completed", "failed" ])
                                           .where("completed_at > ?", 24.hours.ago)
                                           .includes(:data_source, :user)
                                           .order(completed_at: :desc)
                                           .limit(20)

    @pipeline_stats = calculate_pipeline_stats
    @hourly_metrics = calculate_hourly_metrics
    @pipeline_health = calculate_pipeline_health
    @alert_conditions = check_alert_conditions
  end

  def show
    @execution = current_organization.pipeline_executions.find(params[:id])
    @pipeline_config = current_organization.pipeline_configurations
                                         .find_by(name: @execution.pipeline_name)

    @tasks = @execution.tasks.includes(:assignee, :task_template).order(:position)
    @execution_logs = fetch_execution_logs(@execution)
    @performance_metrics = calculate_execution_metrics(@execution)

    respond_to do |format|
      format.html
      format.json { render json: execution_status_json }
    end
  end

  def live_updates
    @execution = current_organization.pipeline_executions.find(params[:id])

    render turbo_stream: turbo_stream.replace(
      "execution_#{@execution.id}",
      partial: "pipeline_monitoring/execution_row",
      locals: { execution: @execution }
    )
  end

  def system_health
    @queue_metrics = solid_queue_available? ? SolidQueue::Job.group(:queue_name).count : {}
    @worker_status = check_worker_status
    @resource_usage = calculate_resource_usage
    @error_trends = analyze_error_trends

    respond_to do |format|
      format.html
      format.json { render json: system_health_json }
    end
  end

  def alerts
    @alerts = current_organization.alerts
                               .where(alert_type: "pipeline")
                               .includes(:user, :data_source, :pipeline_execution)
                               .order(created_at: :desc)
                               .page(params[:page])
  end



  private

  def calculate_pipeline_stats
    executions = current_organization.pipeline_executions
                                   .where("created_at > ?", 30.days.ago)

    {
      total_executions: executions.count,
      successful_executions: executions.where(status: "completed").count,
      failed_executions: executions.where(status: "failed").count,
      average_duration: executions.where(status: "completed")
                                 .average("EXTRACT(EPOCH FROM (completed_at - started_at))"),
      total_records_processed: executions.sum(&:records_processed),
      success_rate: calculate_success_rate(executions),
      busiest_pipeline: find_busiest_pipeline(executions)
    }
  end

  def calculate_hourly_metrics
    Rails.cache.fetch("pipeline_hourly_metrics_#{current_organization.id}", expires_in: 5.minutes) do
      current_organization.pipeline_executions
                        .where("started_at > ?", 24.hours.ago)
                        .group_by_hour(:started_at)
                        .count
    end
  end

  def calculate_pipeline_health
    recent_executions = current_organization.pipeline_executions
                                          .where("created_at > ?", 1.hour.ago)

    {
      health_score: calculate_health_score(recent_executions),
      active_pipelines: recent_executions.where(status: "running").count,
      queue_depth: solid_queue_available? ? SolidQueue::Job.where(queue_name: "etl").count : 0,
      avg_wait_time: calculate_avg_wait_time,
      error_rate: calculate_recent_error_rate(recent_executions)
    }
  end

  def check_alert_conditions
    conditions = []

    # Check for high failure rate
    failure_rate = calculate_recent_error_rate(
      current_organization.pipeline_executions.where("created_at > ?", 1.hour.ago)
    )
    if failure_rate > 0.2
      conditions << {
        type: "high_failure_rate",
        severity: "warning",
        message: "Pipeline failure rate is #{(failure_rate * 100).round}% in the last hour"
      }
    end

    # Check for stuck pipelines
    stuck_pipelines = current_organization.pipeline_executions
                                        .where(status: "running")
                                        .where("started_at < ?", 2.hours.ago)
                                        .count
    if stuck_pipelines > 0
      conditions << {
        type: "stuck_pipelines",
        severity: "error",
        message: "#{stuck_pipelines} pipeline(s) have been running for over 2 hours"
      }
    end

    # Check queue depth
    queue_depth = solid_queue_available? ? SolidQueue::Job.where(queue_name: "etl").count : 0
    if queue_depth > 100
      conditions << {
        type: "high_queue_depth",
        severity: "warning",
        message: "ETL queue depth is #{queue_depth}"
      }
    end

    conditions
  end

  def fetch_execution_logs(execution)
    # In a real implementation, this would fetch from a logging service
    # For now, we'll generate some sample log entries
    [
      {
        timestamp: execution.started_at,
        level: "info",
        message: "Pipeline execution started",
        metadata: { pipeline_name: execution.pipeline_name }
      },
      {
        timestamp: execution.started_at + 30.seconds,
        level: "info",
        message: "Data extraction initiated",
        metadata: { source: execution.data_source&.name }
      }
    ]
  end

  def calculate_execution_metrics(execution)
    return {} unless execution.completed?

    duration = execution.completed_at - execution.started_at
    records_processed = execution.records_processed

    {
      duration_seconds: duration,
      records_per_second: duration > 0 ? (records_processed.to_f / duration) : 0,
      records_processed: records_processed,
      stages: {
        extraction: calculate_stage_duration(execution, "extraction"),
        transformation: calculate_stage_duration(execution, "transformation"),
        loading: calculate_stage_duration(execution, "loading")
      }
    }
  end

  def calculate_success_rate(executions)
    return 0 if executions.count.zero?

    successful = executions.where(status: "completed").count
    (successful.to_f / executions.count * 100).round(2)
  end

  def find_busiest_pipeline(executions)
    executions.group(:pipeline_name)
             .count
             .max_by { |_, count| count }
             &.first
  end

  def calculate_health_score(executions)
    return 100 if executions.empty?

    success_rate = calculate_success_rate(executions)
    avg_duration = executions.where(status: "completed")
                           .average("EXTRACT(EPOCH FROM (completed_at - started_at))") || 0

    # Simple health score calculation
    score = success_rate
    score -= 10 if avg_duration > 300 # Penalty for slow executions
    score -= 20 if executions.where(status: "failed").count > 5

    [ score, 0 ].max.round
  end

  def calculate_avg_wait_time
    # Calculate average time between creation and start
    recent = current_organization.pipeline_executions
                               .where(status: "running")
                               .where("started_at IS NOT NULL")
                               .limit(10)

    return 0 if recent.empty?

    wait_times = recent.map { |e| e.started_at - e.created_at }
    wait_times.sum / wait_times.size
  end

  def calculate_recent_error_rate(executions)
    return 0 if executions.count.zero?

    failed = executions.where(status: "failed").count
    failed.to_f / executions.count
  end

  def check_worker_status
    # Check Solid Queue worker status
    if solid_queue_available?
      {
        workers: SolidQueue::Process.count,
        active_jobs: SolidQueue::Job.where(finished_at: nil).count,
        failed_jobs: SolidQueue::FailedExecution.count
      }
    else
      {
        workers: 0,
        active_jobs: 0,
        failed_jobs: 0
      }
    end
  end

  def calculate_resource_usage
    # In production, this would interface with system monitoring
    {
      cpu_usage: rand(20..80),
      memory_usage: rand(40..70),
      disk_usage: rand(30..60),
      network_io: rand(10..50)
    }
  end

  def analyze_error_trends
    current_organization.pipeline_executions
                      .where(status: "failed")
                      .where("created_at > ?", 7.days.ago)
                      .group_by_day(:created_at)
                      .count
  end

  def calculate_stage_duration(execution, stage)
    # This would be calculated from detailed execution logs
    # For now, return estimated values
    case stage
    when "extraction"
      rand(10..60)
    when "transformation"
      rand(20..120)
    when "loading"
      rand(15..90)
    else
      0
    end
  end

  def execution_status_json
    {
      execution: {
        id: @execution.id,
        status: @execution.status,
        progress: @execution.progress,
        current_stage: @execution.current_stage,
        started_at: @execution.started_at,
        completed_at: @execution.completed_at,
        error_message: @execution.error_message
      },
      tasks: @tasks.map do |task|
        {
          id: task.id,
          name: task.name,
          status: task.status,
          started_at: task.started_at,
          completed_at: task.completed_at
        }
      end
    }
  end

  def system_health_json
    {
      queue_metrics: @queue_metrics,
      worker_status: @worker_status,
      resource_usage: @resource_usage,
      error_trends: @error_trends,
      timestamp: Time.current
    }
  end

  def solid_queue_available?
    # Check if SolidQueue tables exist in the database
    ActiveRecord::Base.connection.table_exists?("solid_queue_jobs")
  rescue ActiveRecord::ConnectionNotEstablished, PG::Error
    false
  end
end
