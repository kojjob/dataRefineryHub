# ManualTaskQueueService
# Manages the queue of manual tasks requiring human intervention
# Provides prioritization, assignment, and real-time updates
class ManualTaskQueueService
  include Singleton

  def initialize
    @logger = Rails.logger
  end

  # Get all pending manual tasks across pipelines
  def pending_tasks(options = {})
    scope = Task.for_manual_queue.includes(:pipeline_execution, :assignee)

    # Filter by assignee if specified
    scope = scope.where(assignee_id: options[:assignee_id]) if options[:assignee_id]

    # Filter by pipeline if specified
    if options[:pipeline_name]
      scope = scope.joins(:pipeline_execution)
                   .where(pipeline_executions: { pipeline_name: options[:pipeline_name] })
    end

    # Apply priority ordering
    scope.by_priority
  end

  # Get tasks grouped by priority
  def tasks_by_priority
    {
      high: Task.for_manual_queue.includes(:pipeline_execution, :assignee).where("priority >= ?", 7).by_priority,
      medium: Task.for_manual_queue.includes(:pipeline_execution, :assignee).where(priority: 4..6).by_priority,
      low: Task.for_manual_queue.includes(:pipeline_execution, :assignee).where("priority <= ?", 3).by_priority
    }
  end

  # Assign a task to a user
  def assign_task(task_id, user)
    task = Task.find(task_id)

    unless task.execution_mode == "manual" && task.status == "ready"
      raise "Task #{task_id} is not available for manual assignment"
    end

    task.assignee = user
    task.metadata = (task.metadata || {}).merge(
      assigned_at: Time.current,
      assigned_by: user.id
    )
    task.save!

    # Broadcast assignment
    broadcast_task_assignment(task, user)

    @logger.info "Task #{task_id} assigned to user #{user.id}"
    task
  end

  # Unassign a task
  def unassign_task(task_id)
    task = Task.find(task_id)
    previous_assignee = task.assignee

    task.assignee = nil
    task.metadata = (task.metadata || {}).merge(
      unassigned_at: Time.current
    )
    task.save!

    # Broadcast unassignment
    broadcast_task_unassignment(task, previous_assignee)

    @logger.info "Task #{task_id} unassigned"
    task
  end

  # Execute a manual task
  def execute_manual_task(task_id, user, execution_params = {})
    task = Task.find(task_id)

    # Verify task can be executed by this user
    unless task.assignee == user || user.admin?
      raise "User #{user.id} is not authorized to execute task #{task_id}"
    end

    unless task.can_execute?
      raise "Task #{task_id} cannot be executed in current state"
    end

    # Execute the task
    task.execute!(user)

    # Broadcast execution start
    broadcast_task_execution_started(task, user)

    @logger.info "Manual task #{task_id} execution started by user #{user.id}"
    task
  end

  # Get queue statistics
  def queue_statistics
    total_tasks = pending_tasks.count

    {
      total_pending: total_tasks,
      by_priority: {
        high: pending_tasks.where("priority >= ?", 7).count,
        medium: pending_tasks.where(priority: 4..6).count,
        low: pending_tasks.where("priority <= ?", 3).count
      },
      by_pipeline: Task.for_manual_queue
                       .joins(:pipeline_execution)
                       .group("pipeline_executions.pipeline_name")
                       .count,
      assigned: pending_tasks.where.not(assignee_id: nil).count,
      unassigned: pending_tasks.where(assignee_id: nil).count,
      average_wait_time: calculate_average_wait_time,
      oldest_task: pending_tasks.minimum(:created_at)
    }
  end

  # Get workload by user
  def workload_by_user
    User.joins(:assigned_tasks)
        .where(tasks: { status: [ "ready", "in_progress" ], execution_mode: "manual" })
        .group("users.id")
        .select("users.*, COUNT(tasks.id) as task_count")
        .order("task_count DESC")
  end

  # Auto-assign tasks based on workload
  def auto_assign_tasks(options = {})
    max_tasks_per_user = options[:max_tasks_per_user] || 5
    assigned_count = 0

    # Get users available for assignment
    available_users = User.where(active: true)
                          .where.not(role: "viewer")
                          .to_a

    return 0 if available_users.empty?

    # Get unassigned tasks
    unassigned_tasks = pending_tasks.where(assignee_id: nil)

    unassigned_tasks.each do |task|
      # Find user with least workload
      user = find_user_with_least_workload(available_users, max_tasks_per_user)

      if user
        assign_task(task.id, user)
        assigned_count += 1
      end
    end

    @logger.info "Auto-assigned #{assigned_count} tasks"
    assigned_count
  end

  # Clear stale assignments (tasks assigned but not started)
  def clear_stale_assignments(stale_after = 1.hour)
    stale_tasks = Task.where(
      execution_mode: "manual",
      status: "ready"
    ).where.not(assignee_id: nil)
     .where("updated_at < ?", stale_after.ago)

    cleared_count = 0

    stale_tasks.each do |task|
      unassign_task(task.id)
      cleared_count += 1
    end

    @logger.info "Cleared #{cleared_count} stale task assignments"
    cleared_count
  end

  # Cache queue metrics using Solid Cache
  def cached_metrics
    Rails.cache.fetch("manual_task_queue_metrics", expires_in: 1.minute) do
      {
        statistics: queue_statistics,
        workload: workload_by_user.map { |u| { user_id: u.id, name: u.name, task_count: u.task_count } },
        last_updated: Time.current
      }
    end
  end

  private

  def calculate_average_wait_time
    wait_times = pending_tasks.pluck(:created_at).map { |created_at| Time.current - created_at }
    return 0 if wait_times.empty?

    (wait_times.sum / wait_times.size).to_i
  end

  def find_user_with_least_workload(users, max_tasks)
    user_workloads = {}

    users.each do |user|
      current_tasks = user.assigned_tasks.where(
        status: [ "ready", "in_progress" ],
        execution_mode: "manual"
      ).count

      user_workloads[user] = current_tasks if current_tasks < max_tasks
    end

    return nil if user_workloads.empty?

    # Return user with least workload
    user_workloads.min_by { |_user, count| count }&.first
  end

  def broadcast_task_assignment(task, user)
    ActionCable.server.broadcast(
      "manual_task_queue",
      {
        type: "task_assigned",
        task: {
          id: task.id,
          name: task.name,
          assignee_id: user.id,
          assignee_name: user.name
        },
        timestamp: Time.current
      }
    )

    # Also broadcast to the specific user
    ActionCable.server.broadcast(
      "user_#{user.id}_tasks",
      {
        type: "new_task_assigned",
        task: task_summary(task),
        timestamp: Time.current
      }
    )
  end

  def broadcast_task_unassignment(task, previous_assignee)
    ActionCable.server.broadcast(
      "manual_task_queue",
      {
        type: "task_unassigned",
        task: {
          id: task.id,
          name: task.name
        },
        timestamp: Time.current
      }
    )

    # Notify previous assignee
    if previous_assignee
      ActionCable.server.broadcast(
        "user_#{previous_assignee.id}_tasks",
        {
          type: "task_unassigned",
          task_id: task.id,
          timestamp: Time.current
        }
      )
    end
  end

  def broadcast_task_execution_started(task, user)
    ActionCable.server.broadcast(
      "manual_task_queue",
      {
        type: "task_execution_started",
        task: {
          id: task.id,
          name: task.name,
          executed_by_id: user.id,
          executed_by_name: user.name
        },
        timestamp: Time.current
      }
    )
  end

  def task_summary(task)
    {
      id: task.id,
      name: task.name,
      description: task.description,
      priority: task.priority,
      pipeline_name: task.pipeline_execution.pipeline_name,
      created_at: task.created_at,
      configuration: task.configuration
    }
  end
end
