# PipelineDashboardController
# Provides comprehensive pipeline monitoring and management interface
class PipelineDashboardController < DataflowProController
  before_action :authenticate_user!
  before_action :set_pipeline_execution, only: [ :show ]

  def index
    # Get running pipelines for the active monitor
    @pipeline_executions = current_organization.pipeline_executions
                                              .includes(:data_source, :user, :tasks)
                                              .where(status: ['running', 'processing', 'queued'])
                                              .recent
                                              .limit(6)

    # Pipeline statistics
    @statistics = {
      total_pipelines: current_organization.pipeline_executions.count,
      running_pipelines: current_organization.pipeline_executions.running.count,
      successful_pipelines: current_organization.pipeline_executions.successful.where("created_at >= ?", 24.hours.ago).count,
      failed_pipelines: current_organization.pipeline_executions.failed.where("created_at >= ?", 24.hours.ago).count,
      average_duration: calculate_average_duration,
      success_rate: calculate_success_rate,
      avg_runtime: calculate_average_runtime_minutes,
      data_throughput: calculate_data_throughput,
      error_rate: calculate_error_rate
    }

    # Pipeline performance by type
    @performance_by_type = calculate_performance_by_type

    # Recent pipeline activities
    @recent_activities = current_organization.pipeline_executions
                                            .includes(:user, :data_source)
                                            .recent
                                            .limit(10)

    # Active manual interventions
    @manual_interventions = Task.joins(:pipeline_execution)
                               .where(pipeline_executions: { organization_id: current_organization.id })
                               .where(execution_mode: [ "manual", "approval_required" ])
                               .where(status: [ "ready", "waiting_approval" ])
                               .includes(:pipeline_execution, :assignee)
                               .limit(5)

    respond_to do |format|
      format.html
      format.turbo_stream
      format.json { render json: @statistics }
    end
  end

  def show
    @tasks = @pipeline_execution.tasks.includes(:task_executions, :assignee).order(:position)

    # Calculate pipeline progress details
    @progress_details = calculate_progress_details

    # Task statistics
    @task_statistics = {
      total: @tasks.count,
      completed: @tasks.completed.count,
      in_progress: @tasks.in_progress.count,
      failed: @tasks.failed.count,
      pending: @tasks.pending.count + @tasks.ready.count
    }

    # Recent task executions
    @recent_executions = TaskExecution.joins(:task)
                                      .where(tasks: { pipeline_execution_id: @pipeline_execution.id })
                                      .includes(:task, :executed_by)
                                      .recent
                                      .limit(20)

    # Pipeline timeline
    @timeline_events = build_timeline_events

    respond_to do |format|
      format.html
      format.turbo_stream
      format.json { render json: pipeline_details_json }
    end
  end

  private

  def set_pipeline_execution
    @pipeline_execution = current_organization.pipeline_executions.find(params[:id])
  end

  def calculate_average_duration
    completed_pipelines = current_organization.pipeline_executions
                                             .successful
                                             .where("completed_at IS NOT NULL")
                                             .where("created_at >= ?", 7.days.ago)

    return 0 if completed_pipelines.empty?

    total_duration = completed_pipelines.sum { |p| p.duration_in_seconds || 0 }
    average_seconds = total_duration / completed_pipelines.count

    # Format as human-readable duration
    if average_seconds < 60
      "#{average_seconds}s"
    elsif average_seconds < 3600
      "#{(average_seconds / 60).round}m"
    else
      "#{(average_seconds / 3600.0).round(1)}h"
    end
  end

  def calculate_success_rate
    total = current_organization.pipeline_executions
                               .where("created_at >= ?", 24.hours.ago)
                               .where(status: [ "completed", "failed" ])
                               .count

    return 100 if total == 0

    successful = current_organization.pipeline_executions
                                    .successful
                                    .where("created_at >= ?", 24.hours.ago)
                                    .count

    ((successful.to_f / total) * 100).round(1)
  end

  def calculate_performance_by_type
    types = current_organization.pipeline_executions
                               .group(:pipeline_name)
                               .count

    performance = {}

    types.each do |pipeline_name, _count|
      pipelines = current_organization.pipeline_executions
                                     .where(pipeline_name: pipeline_name)
                                     .where("created_at >= ?", 7.days.ago)

      total = pipelines.count
      successful = pipelines.successful.count

      performance[pipeline_name] = {
        total: total,
        success_rate: total > 0 ? ((successful.to_f / total) * 100).round(1) : 0,
        average_duration: calculate_type_average_duration(pipelines)
      }
    end

    performance
  end

  def calculate_type_average_duration(pipelines)
    completed = pipelines.where(status: "completed").where("completed_at IS NOT NULL")
    return "N/A" if completed.empty?

    total_seconds = completed.sum { |p| p.duration_in_seconds || 0 }
    average = total_seconds / completed.count

    if average < 60
      "#{average}s"
    elsif average < 3600
      "#{(average / 60).round}m"
    else
      "#{(average / 3600.0).round(1)}h"
    end
  end

  def calculate_progress_details
    total_weight = @tasks.sum(:weight)
    completed_weight = @tasks.completed.sum(:weight)

    {
      percentage: total_weight > 0 ? ((completed_weight.to_f / total_weight) * 100).round : 0,
      completed_weight: completed_weight,
      total_weight: total_weight,
      critical_path_status: calculate_critical_path_status
    }
  end

  def calculate_critical_path_status
    critical_tasks = @tasks.where(on_critical_path: true)

    if critical_tasks.failed.any?
      "blocked"
    elsif critical_tasks.in_progress.any?
      "in_progress"
    elsif critical_tasks.completed.count == critical_tasks.count
      "completed"
    else
      "pending"
    end
  end

  def build_timeline_events
    events = []

    # Pipeline start
    events << {
      time: @pipeline_execution.started_at,
      type: "pipeline_start",
      title: "Pipeline Started",
      description: "#{@pipeline_execution.pipeline_name} execution began",
      icon: "play",
      color: "blue"
    }

    # Task events
    @tasks.each do |task|
      if task.started_at?
        events << {
          time: task.started_at,
          type: "task_start",
          title: "Task Started: #{task.name}",
          description: task.description,
          icon: "arrow-right",
          color: "gray"
        }
      end

      if task.completed_at?
        color = task.failed? ? "red" : "green"
        icon = task.failed? ? "x" : "check"

        events << {
          time: task.completed_at,
          type: "task_#{task.status}",
          title: "Task #{task.status.humanize}: #{task.name}",
          description: task.error_message || "Completed successfully",
          icon: icon,
          color: color
        }
      end
    end

    # Pipeline completion
    if @pipeline_execution.completed_at?
      events << {
        time: @pipeline_execution.completed_at,
        type: "pipeline_complete",
        title: "Pipeline Completed",
        description: "Total duration: #{@pipeline_execution.duration_formatted}",
        icon: "flag",
        color: @pipeline_execution.status == "failed" ? "red" : "green"
      }
    end

    events.sort_by { |e| e[:time] }
  end

  def pipeline_details_json
    {
      pipeline: @pipeline_execution.as_json(methods: [ :duration_formatted ]),
      tasks: @tasks.as_json(include: :assignee),
      statistics: @task_statistics,
      progress: @progress_details,
      timeline: @timeline_events
    }
  end

  def calculate_average_runtime_minutes
    executions = current_organization.pipeline_executions
                                   .where.not(completed_at: nil)
                                   .where("created_at >= ?", 24.hours.ago)

    return 0 if executions.empty?

    avg_seconds = executions.average("EXTRACT(EPOCH FROM (completed_at - started_at))")
    return 0 unless avg_seconds

    (avg_seconds / 60.0).round(1)
  end

  def calculate_data_throughput
    # Calculate total data processed in the last 24 hours
    executions = current_organization.pipeline_executions
                                   .where("created_at >= ?", 24.hours.ago)

    total_records = executions.sum { |e| e.processed_records || 0 }

    # Estimate data size (assuming average record size of 1KB)
    estimated_bytes = total_records * 1024

    # Return bytes per hour
    estimated_bytes
  end

  def calculate_error_rate
    total_executions = current_organization.pipeline_executions
                                         .where("created_at >= ?", 24.hours.ago)
                                         .count

    return 0 if total_executions == 0

    failed_executions = current_organization.pipeline_executions
                                          .failed
                                          .where("created_at >= ?", 24.hours.ago)
                                          .count

    ((failed_executions.to_f / total_executions) * 100).round(1)
  end
end
