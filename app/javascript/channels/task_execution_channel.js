import consumer from "./consumer"

// Subscribe to task execution updates
export function subscribeToTaskExecution(taskId, callbacks = {}) {
  return consumer.subscriptions.create(
    { 
      channel: "TaskExecutionChannel", 
      task_id: taskId 
    },
    {
      connected() {
        console.log(`Connected to task ${taskId} execution channel`)
        if (callbacks.onConnected) callbacks.onConnected()
      },

      disconnected() {
        console.log(`Disconnected from task ${taskId} execution channel`)
        if (callbacks.onDisconnected) callbacks.onDisconnected()
      },

      received(data) {
        console.log("Task execution update received:", data)
        
        switch (data.type) {
          case 'initial_state':
            if (callbacks.onInitialState) callbacks.onInitialState(data.task)
            this.updateTaskDisplay(data.task)
            break
            
          case 'refresh':
            if (callbacks.onRefresh) callbacks.onRefresh(data.task)
            this.updateTaskDisplay(data.task)
            break
            
          case 'execution_started':
            if (callbacks.onExecutionStarted) callbacks.onExecutionStarted(data)
            this.showExecutionStarted()
            break
            
          case 'execution_failed':
            if (callbacks.onExecutionFailed) callbacks.onExecutionFailed(data)
            this.showError(data.error)
            break
            
          case 'execution_denied':
            if (callbacks.onExecutionDenied) callbacks.onExecutionDenied(data)
            this.showError(data.error)
            break
            
          case 'task_approved':
            if (callbacks.onTaskApproved) callbacks.onTaskApproved(data)
            this.showSuccess('Task approved successfully')
            break
            
          case 'approval_failed':
            if (callbacks.onApprovalFailed) callbacks.onApprovalFailed(data)
            this.showError(data.error)
            break
            
          case 'approval_denied':
            if (callbacks.onApprovalDenied) callbacks.onApprovalDenied(data)
            this.showError(data.error)
            break
            
          case 'task_rejected':
            if (callbacks.onTaskRejected) callbacks.onTaskRejected(data)
            this.showSuccess('Task rejected successfully')
            break
            
          case 'rejection_failed':
            if (callbacks.onRejectionFailed) callbacks.onRejectionFailed(data)
            this.showError(data.error)
            break
            
          case 'rejection_denied':
            if (callbacks.onRejectionDenied) callbacks.onRejectionDenied(data)
            this.showError(data.error)
            break
            
          case 'execution_progress':
            if (callbacks.onExecutionProgress) callbacks.onExecutionProgress(data)
            this.updateProgress(data)
            break
            
          case 'execution_completed':
            if (callbacks.onExecutionCompleted) callbacks.onExecutionCompleted(data)
            this.showExecutionCompleted(data)
            break
            
          case 'execution_error':
            if (callbacks.onExecutionError) callbacks.onExecutionError(data)
            this.showExecutionError(data)
            break
            
          default:
            if (callbacks.onUpdate) callbacks.onUpdate(data)
        }
      },

      // Request task refresh
      refresh() {
        this.perform('refresh')
      },

      // Execute the task
      executeTask() {
        this.perform('execute_task')
      },

      // Approve the task
      approveTask() {
        this.perform('approve_task')
      },

      // Reject the task
      rejectTask(reason) {
        this.perform('reject_task', { reason: reason })
      },

      // Update task display with latest data
      updateTaskDisplay(task) {
        // Update status
        const statusElement = document.querySelector('.task-status')
        if (statusElement) {
          statusElement.textContent = task.status.replace('_', ' ')
          statusElement.className = `task-status badge ${this.getStatusClass(task.status)}`
        }

        // Update execution mode
        const modeElement = document.querySelector('.task-execution-mode')
        if (modeElement) {
          modeElement.textContent = task.execution_mode.replace('_', ' ')
          modeElement.className = `task-execution-mode badge ${this.getModeClass(task.execution_mode)}`
        }

        // Update assignee
        const assigneeElement = document.querySelector('.task-assignee')
        if (assigneeElement) {
          if (task.assignee) {
            assigneeElement.innerHTML = `
              <span class="text-sm text-gray-600">Assigned to:</span>
              <span class="font-medium">${task.assignee.name}</span>
            `
          } else {
            assigneeElement.innerHTML = '<span class="text-gray-500">Unassigned</span>'
          }
        }

        // Update timestamps
        if (task.started_at) {
          const startedElement = document.querySelector('.task-started-at')
          if (startedElement) {
            startedElement.textContent = new Date(task.started_at).toLocaleString()
          }
        }

        if (task.completed_at) {
          const completedElement = document.querySelector('.task-completed-at')
          if (completedElement) {
            completedElement.textContent = new Date(task.completed_at).toLocaleString()
          }
        }

        // Update duration
        if (task.duration_seconds) {
          const durationElement = document.querySelector('.task-duration')
          if (durationElement) {
            durationElement.textContent = this.formatDuration(task.duration_seconds)
          }
        }

        // Update error message
        const errorElement = document.querySelector('.task-error-message')
        if (errorElement) {
          if (task.error_message) {
            errorElement.classList.remove('hidden')
            errorElement.querySelector('.error-text').textContent = task.error_message
          } else {
            errorElement.classList.add('hidden')
          }
        }

        // Update action buttons based on status
        this.updateActionButtons(task)

        // Update task executions list
        if (task.task_executions && task.task_executions.length > 0) {
          this.updateExecutionsList(task.task_executions)
        }
      },

      // Update action buttons based on task state
      updateActionButtons(task) {
        const executeBtn = document.querySelector('[data-action="execute"]')
        const approveBtn = document.querySelector('[data-action="approve"]')
        const rejectBtn = document.querySelector('[data-action="reject"]')

        // Hide all buttons by default
        [executeBtn, approveBtn, rejectBtn].forEach(btn => {
          if (btn) btn.classList.add('hidden')
        })

        // Show relevant buttons based on status and execution mode
        if (task.status === 'ready' && task.execution_mode === 'manual' && executeBtn) {
          executeBtn.classList.remove('hidden')
        }

        if (task.status === 'waiting_approval' && approveBtn && rejectBtn) {
          approveBtn.classList.remove('hidden')
          rejectBtn.classList.remove('hidden')
        }
      },

      // Update executions list
      updateExecutionsList(executions) {
        const container = document.querySelector('.task-executions-list')
        if (!container) return

        const executionsHtml = executions.map(execution => `
          <div class="border rounded p-3 ${execution.status === 'failed' ? 'border-red-200 bg-red-50' : ''}">
            <div class="flex justify-between items-start">
              <div>
                <span class="badge ${this.getStatusClass(execution.status)}">
                  ${execution.status}
                </span>
                <span class="text-sm text-gray-600 ml-2">
                  ${new Date(execution.started_at).toLocaleString()}
                </span>
              </div>
              <span class="text-sm text-gray-600">
                ${this.formatDuration(execution.duration_seconds)}
              </span>
            </div>
            ${execution.error_message ? `
              <div class="mt-2 text-sm text-red-600">
                ${execution.error_message}
              </div>
            ` : ''}
            ${execution.output ? `
              <div class="mt-2 text-sm">
                <strong>Output:</strong>
                <pre class="mt-1 p-2 bg-gray-100 rounded text-xs">${JSON.stringify(execution.output, null, 2)}</pre>
              </div>
            ` : ''}
          </div>
        `).join('')

        container.innerHTML = executionsHtml
      },

      // Show execution started
      showExecutionStarted() {
        this.showSuccess('Task execution started')
        
        // Update UI to show in-progress state
        const statusElement = document.querySelector('.task-status')
        if (statusElement) {
          statusElement.textContent = 'in progress'
          statusElement.className = 'task-status badge bg-blue-100 text-blue-800'
        }

        // Add loading indicator
        const container = document.querySelector('.task-execution-container')
        if (container) {
          const loader = document.createElement('div')
          loader.className = 'mt-4 text-center'
          loader.innerHTML = `
            <div class="inline-flex items-center">
              <svg class="animate-spin h-5 w-5 mr-3 text-blue-600" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              <span>Executing task...</span>
            </div>
          `
          container.appendChild(loader)
        }
      },

      // Show execution completed
      showExecutionCompleted(data) {
        this.showSuccess('Task completed successfully')
        
        // Remove loading indicator
        const loader = document.querySelector('.task-execution-container .animate-spin')
        if (loader) loader.parentElement.parentElement.remove()
        
        // Refresh the page after a short delay
        setTimeout(() => {
          window.location.reload()
        }, 1500)
      },

      // Show execution error
      showExecutionError(data) {
        this.showError(`Task execution failed: ${data.error}`)
        
        // Remove loading indicator
        const loader = document.querySelector('.task-execution-container .animate-spin')
        if (loader) loader.parentElement.parentElement.remove()
      },

      // Update progress display
      updateProgress(data) {
        const progressElement = document.querySelector('.task-progress')
        if (progressElement && data.progress) {
          progressElement.style.width = `${data.progress}%`
          progressElement.setAttribute('aria-valuenow', data.progress)
        }
      },

      // Helper methods
      getStatusClass(status) {
        const statusClasses = {
          'pending': 'bg-gray-100 text-gray-800',
          'ready': 'bg-yellow-100 text-yellow-800',
          'in_progress': 'bg-blue-100 text-blue-800',
          'completed': 'bg-green-100 text-green-800',
          'failed': 'bg-red-100 text-red-800',
          'cancelled': 'bg-gray-100 text-gray-800',
          'waiting_approval': 'bg-orange-100 text-orange-800',
          'skipped': 'bg-gray-100 text-gray-600'
        }
        return statusClasses[status] || 'bg-gray-100 text-gray-800'
      },

      getModeClass(mode) {
        const modeClasses = {
          'automated': 'bg-blue-100 text-blue-800',
          'manual': 'bg-yellow-100 text-yellow-800',
          'approval_required': 'bg-red-100 text-red-800',
          'hybrid': 'bg-purple-100 text-purple-800'
        }
        return modeClasses[mode] || 'bg-gray-100 text-gray-800'
      },

      formatDuration(seconds) {
        if (!seconds) return 'N/A'
        if (seconds < 60) return `${seconds}s`
        if (seconds < 3600) return `${Math.floor(seconds / 60)}m ${seconds % 60}s`
        return `${Math.floor(seconds / 3600)}h ${Math.floor((seconds % 3600) / 60)}m`
      },

      showSuccess(message) {
        this.showNotification(message, 'success')
      },

      showError(message) {
        this.showNotification(message, 'error')
      },

      showNotification(message, type = 'info') {
        const notification = document.createElement('div')
        notification.className = `fixed top-4 right-4 px-6 py-3 rounded-lg shadow-lg text-white z-50 ${
          type === 'success' ? 'bg-green-600' : 
          type === 'error' ? 'bg-red-600' : 
          'bg-blue-600'
        }`
        notification.textContent = message
        document.body.appendChild(notification)

        setTimeout(() => {
          notification.style.opacity = '0'
          setTimeout(() => notification.remove(), 300)
        }, 3000)
      }
    }
  )
}