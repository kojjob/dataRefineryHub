import consumer from "./consumer"

// Subscribe to pipeline updates
export function subscribeToPipeline(pipelineId, callbacks = {}) {
  return consumer.subscriptions.create(
    { 
      channel: "PipelineChannel", 
      pipeline_id: pipelineId 
    },
    {
      connected() {
        console.log(`Connected to pipeline ${pipelineId}`)
        if (callbacks.onConnected) callbacks.onConnected()
      },

      disconnected() {
        console.log(`Disconnected from pipeline ${pipelineId}`)
        if (callbacks.onDisconnected) callbacks.onDisconnected()
      },

      received(data) {
        console.log("Pipeline update received:", data)
        
        switch (data.type) {
          case 'initial_state':
            if (callbacks.onInitialState) callbacks.onInitialState(data)
            break
          case 'task_status_update':
            if (callbacks.onTaskStatusUpdate) callbacks.onTaskStatusUpdate(data)
            this.updateTaskUI(data)
            break
          case 'pipeline_status_update':
            if (callbacks.onPipelineStatusUpdate) callbacks.onPipelineStatusUpdate(data)
            this.updatePipelineUI(data)
            break
          case 'refresh':
            if (callbacks.onRefresh) callbacks.onRefresh(data)
            break
          case 'task_details':
            if (callbacks.onTaskDetails) callbacks.onTaskDetails(data)
            break
          default:
            if (callbacks.onUpdate) callbacks.onUpdate(data)
        }
      },

      // Request a refresh of pipeline data
      refresh() {
        this.perform('refresh')
      },

      // Request task details
      requestTaskDetails(taskId) {
        this.perform('task_details', { task_id: taskId })
      },

      // Update task UI elements
      updateTaskUI(data) {
        const taskElement = document.querySelector(`[data-task-id="${data.task_id}"]`)
        if (taskElement) {
          // Update status badge
          const statusBadge = taskElement.querySelector('.task-status')
          if (statusBadge) {
            statusBadge.textContent = data.status
            statusBadge.className = `task-status badge ${this.getStatusClass(data.status)}`
          }

          // Update progress indicator
          const progressIndicator = taskElement.querySelector('.task-progress')
          if (progressIndicator && data.status === 'in_progress') {
            progressIndicator.classList.add('animate-pulse')
          } else if (progressIndicator) {
            progressIndicator.classList.remove('animate-pulse')
          }
        }
      },

      // Update pipeline UI elements
      updatePipelineUI(data) {
        // Update progress bar
        const progressBar = document.querySelector('.pipeline-progress-bar')
        if (progressBar && data.progress_percentage !== undefined) {
          progressBar.style.width = `${data.progress_percentage}%`
          progressBar.setAttribute('aria-valuenow', data.progress_percentage)
        }

        // Update status
        const statusElement = document.querySelector('.pipeline-status')
        if (statusElement && data.status) {
          statusElement.textContent = data.status
          statusElement.className = `pipeline-status badge ${this.getStatusClass(data.status)}`
        }

        // Update counters
        if (data.completed_tasks !== undefined) {
          const completedElement = document.querySelector('.completed-tasks-count')
          if (completedElement) completedElement.textContent = data.completed_tasks
        }

        if (data.failed_tasks !== undefined) {
          const failedElement = document.querySelector('.failed-tasks-count')
          if (failedElement) failedElement.textContent = data.failed_tasks
        }
      },

      getStatusClass(status) {
        const statusClasses = {
          'pending': 'bg-gray-100 text-gray-800',
          'ready': 'bg-yellow-100 text-yellow-800',
          'in_progress': 'bg-blue-100 text-blue-800',
          'completed': 'bg-green-100 text-green-800',
          'failed': 'bg-red-100 text-red-800',
          'cancelled': 'bg-gray-100 text-gray-800',
          'waiting_approval': 'bg-orange-100 text-orange-800'
        }
        return statusClasses[status] || 'bg-gray-100 text-gray-800'
      }
    }
  )
}

// Subscribe to organization-wide pipeline updates
export function subscribeToOrganizationPipelines(organizationId, callbacks = {}) {
  return consumer.subscriptions.create(
    { 
      channel: "PipelineChannel", 
      organization_id: organizationId 
    },
    {
      connected() {
        console.log(`Connected to organization ${organizationId} pipelines`)
        if (callbacks.onConnected) callbacks.onConnected()
      },

      disconnected() {
        console.log(`Disconnected from organization ${organizationId} pipelines`)
        if (callbacks.onDisconnected) callbacks.onDisconnected()
      },

      received(data) {
        console.log("Organization pipeline update received:", data)
        if (callbacks.onUpdate) callbacks.onUpdate(data)
      }
    }
  )
}