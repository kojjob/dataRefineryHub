import consumer from "./consumer"

// Subscribe to manual task queue updates
export function subscribeToManualTaskQueue(callbacks = {}) {
  return consumer.subscriptions.create(
    { channel: "ManualTaskQueueChannel" },
    {
      connected() {
        console.log("Connected to manual task queue")
        if (callbacks.onConnected) callbacks.onConnected()
      },

      disconnected() {
        console.log("Disconnected from manual task queue")
        if (callbacks.onDisconnected) callbacks.onDisconnected()
      },

      received(data) {
        console.log("Manual task queue update received:", data)
        
        switch (data.type) {
          case 'initial_queue_state':
            if (callbacks.onInitialState) callbacks.onInitialState(data)
            this.updateQueueStatistics(data.statistics)
            this.updateAssignedTasks(data.assigned_tasks)
            break
            
          case 'new_manual_task':
            if (callbacks.onNewTask) callbacks.onNewTask(data.task)
            this.showNewTaskNotification(data.task)
            break
            
          case 'task_assigned':
            if (callbacks.onTaskAssigned) callbacks.onTaskAssigned(data.task)
            this.updateTaskAssignment(data.task)
            break
            
          case 'task_unassigned':
            if (callbacks.onTaskUnassigned) callbacks.onTaskUnassigned(data.task)
            this.updateTaskAssignment(data.task, true)
            break
            
          case 'task_execution_started':
            if (callbacks.onTaskExecutionStarted) callbacks.onTaskExecutionStarted(data.task)
            this.removeTaskFromQueue(data.task.id)
            break
            
          case 'queue_refresh':
            if (callbacks.onQueueRefresh) callbacks.onQueueRefresh(data)
            this.updateQueueStatistics(data.statistics)
            this.updateAssignedTasks(data.assigned_tasks)
            break
            
          case 'workload_info':
            if (callbacks.onWorkloadInfo) callbacks.onWorkloadInfo(data.workload)
            this.updateWorkloadDisplay(data.workload)
            break
            
          case 'new_task_assigned':
            if (callbacks.onNewTaskAssigned) callbacks.onNewTaskAssigned(data.task)
            this.showAssignmentNotification(data.task)
            break
            
          case 'task_claimed':
          case 'task_released':
          case 'task_claim_failed':
          case 'task_release_failed':
            if (callbacks.onTaskAction) callbacks.onTaskAction(data)
            this.handleTaskActionResponse(data)
            break
            
          default:
            if (callbacks.onUpdate) callbacks.onUpdate(data)
        }
      },

      // Request queue refresh
      refreshQueue() {
        this.perform('refresh_queue')
      },

      // Claim a task
      claimTask(taskId) {
        this.perform('claim_task', { task_id: taskId })
      },

      // Release a task
      releaseTask(taskId) {
        this.perform('release_task', { task_id: taskId })
      },

      // Request workload information
      requestWorkloadInfo() {
        this.perform('workload_info')
      },

      // Update queue statistics in the UI
      updateQueueStatistics(statistics) {
        // Update total pending
        const totalPending = document.querySelector('[data-stat="total-pending"]')
        if (totalPending) totalPending.textContent = statistics.total_pending

        // Update priority counts
        Object.entries(statistics.by_priority).forEach(([priority, count]) => {
          const element = document.querySelector(`[data-stat="${priority}-priority"]`)
          if (element) element.textContent = count
        })

        // Update assigned/unassigned counts
        const assigned = document.querySelector('[data-stat="assigned"]')
        if (assigned) assigned.textContent = statistics.assigned

        const unassigned = document.querySelector('[data-stat="unassigned"]')
        if (unassigned) unassigned.textContent = statistics.unassigned

        // Update average wait time
        const avgWaitTime = document.querySelector('[data-stat="avg-wait-time"]')
        if (avgWaitTime) {
          avgWaitTime.textContent = this.formatDuration(statistics.average_wait_time)
        }
      },

      // Update assigned tasks list
      updateAssignedTasks(tasks) {
        const container = document.querySelector('[data-assigned-tasks-container]')
        if (!container) return

        if (tasks.length === 0) {
          container.innerHTML = '<p class="text-gray-500 text-sm">No tasks assigned to you</p>'
          return
        }

        const tasksHtml = tasks.map(task => `
          <div class="border rounded-lg p-4 hover:bg-gray-50" data-task-id="${task.id}">
            <div class="flex justify-between items-start">
              <div class="flex-1">
                <h4 class="font-medium">${task.name}</h4>
                <p class="text-sm text-gray-600">${task.pipeline_name}</p>
                <div class="flex gap-2 mt-2">
                  <span class="badge ${this.getPriorityClass(task.priority)}">
                    Priority: ${task.priority}
                  </span>
                  <span class="badge bg-gray-100 text-gray-800">
                    ${task.status}
                  </span>
                </div>
              </div>
              <div class="flex gap-2">
                <a href="/manual_tasks/${task.id}" class="btn btn-sm btn-primary">
                  View
                </a>
                <button onclick="manualTaskQueue.releaseTask(${task.id})" 
                        class="btn btn-sm btn-ghost">
                  Release
                </button>
              </div>
            </div>
          </div>
        `).join('')

        container.innerHTML = tasksHtml
      },

      // Show notification for new task
      showNewTaskNotification(task) {
        if ('Notification' in window && Notification.permission === 'granted') {
          new Notification('New Manual Task', {
            body: `${task.name} from ${task.pipeline_name}`,
            icon: '/favicon.ico',
            tag: `task-${task.id}`
          })
        }

        // Also show in-app notification
        this.showToast(`New manual task: ${task.name}`, 'info')
      },

      // Show assignment notification
      showAssignmentNotification(task) {
        if ('Notification' in window && Notification.permission === 'granted') {
          new Notification('Task Assigned to You', {
            body: `${task.name} from ${task.pipeline_name}`,
            icon: '/favicon.ico',
            tag: `task-${task.id}`
          })
        }

        this.showToast(`New task assigned: ${task.name}`, 'success')
      },

      // Update task assignment in UI
      updateTaskAssignment(task, unassigned = false) {
        const taskElement = document.querySelector(`[data-task-id="${task.id}"]`)
        if (!taskElement) return

        const assigneeElement = taskElement.querySelector('.task-assignee')
        if (assigneeElement) {
          if (unassigned) {
            assigneeElement.textContent = 'Unassigned'
            assigneeElement.className = 'task-assignee text-gray-500'
          } else {
            assigneeElement.textContent = task.assignee_name
            assigneeElement.className = 'task-assignee text-blue-600'
          }
        }
      },

      // Remove task from queue display
      removeTaskFromQueue(taskId) {
        const taskElement = document.querySelector(`[data-task-id="${taskId}"]`)
        if (taskElement) {
          taskElement.style.opacity = '0'
          setTimeout(() => taskElement.remove(), 300)
        }
      },

      // Handle task action responses
      handleTaskActionResponse(data) {
        if (data.success) {
          this.showToast(this.getSuccessMessage(data.type), 'success')
        } else {
          this.showToast(data.error || 'Action failed', 'error')
        }
      },

      // Update workload display
      updateWorkloadDisplay(workload) {
        const container = document.querySelector('[data-workload-container]')
        if (!container) return

        const workloadHtml = workload.map(user => `
          <div class="flex justify-between items-center py-2 ${user.is_current_user ? 'font-semibold' : ''}">
            <span>${user.name}</span>
            <span class="badge bg-gray-100 text-gray-800">${user.task_count} tasks</span>
          </div>
        `).join('')

        container.innerHTML = workloadHtml
      },

      // Helper methods
      formatDuration(seconds) {
        if (seconds < 60) return `${seconds}s`
        if (seconds < 3600) return `${Math.floor(seconds / 60)}m`
        return `${Math.floor(seconds / 3600)}h ${Math.floor((seconds % 3600) / 60)}m`
      },

      getPriorityClass(priority) {
        if (priority >= 7) return 'bg-red-100 text-red-800'
        if (priority >= 4) return 'bg-yellow-100 text-yellow-800'
        return 'bg-gray-100 text-gray-800'
      },

      getSuccessMessage(type) {
        const messages = {
          'task_claimed': 'Task successfully claimed',
          'task_released': 'Task successfully released'
        }
        return messages[type] || 'Action completed successfully'
      },

      showToast(message, type = 'info') {
        // Simple toast notification - you can replace with your preferred notification system
        const toast = document.createElement('div')
        toast.className = `fixed bottom-4 right-4 px-6 py-3 rounded-lg shadow-lg text-white z-50 ${
          type === 'success' ? 'bg-green-600' : 
          type === 'error' ? 'bg-red-600' : 
          'bg-blue-600'
        }`
        toast.textContent = message
        document.body.appendChild(toast)

        setTimeout(() => {
          toast.style.opacity = '0'
          setTimeout(() => toast.remove(), 300)
        }, 3000)
      }
    }
  )
}

// Export instance for global access
window.manualTaskQueue = subscribeToManualTaskQueue()