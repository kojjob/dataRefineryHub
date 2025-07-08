import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = [
    "totalDataSources", "connectedSources", "activeSyncs", "totalRecords",
    "recordsLastHour", "processingRate", "systemHealth", "successRate",
    "recentActivity", "systemStatus", "alerts", "statusIndicator", "statusText", 
    "uptime", "processingJobs", "storageUsed", "activityContainer"
  ]

  connect() {
    console.log("Real-time dashboard controller connected")
    this.setupWebSocketConnection()
    this.startMetricsPolling()
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    if (this.metricsInterval) {
      clearInterval(this.metricsInterval)
    }
    console.log("Real-time dashboard controller disconnected")
  }

  setupWebSocketConnection() {
    this.consumer = createConsumer()
    
    this.subscription = this.consumer.subscriptions.create("DashboardChannel", {
      connected: () => {
        console.log("Connected to dashboard channel")
        this.updateConnectionStatus("connected")
      },

      disconnected: () => {
        console.log("Disconnected from dashboard channel")
        this.updateConnectionStatus("disconnected")
      },

      received: (data) => {
        console.log("Received dashboard update:", data)
        this.handleRealtimeUpdate(data)
      }
    })
  }

  handleRealtimeUpdate(data) {
    switch (data.type) {
      case 'connection_established':
        this.updateConnectionStatus("connected")
        break
      
      case 'initial_data':
        this.updateDashboardData(data.data)
        break
      
      case 'live_metrics_update':
        this.updateLiveMetrics(data.metrics)
        break
      
      case 'job_status_change':
        this.handleJobStatusChange(data)
        break
      
      case 'system_alert':
        this.showAlert(data.alert)
        break
      
      case 'usage_warning':
        this.showUsageWarning(data.warning)
        break
      
      case 'records_processed':
        this.animateRecordsUpdate(data)
        break
    }
  }

  updateDashboardData(data) {
    // Update overview stats
    if (data.overview_stats) {
      this.updateTarget("totalDataSources", data.overview_stats.total_data_sources)
      this.updateTarget("connectedSources", data.overview_stats.connected_sources)
      this.updateTarget("activeSyncs", data.overview_stats.active_syncs)
      this.updateTarget("totalRecords", this.formatNumber(data.overview_stats.total_records))
    }

    // Update real-time metrics
    if (data.real_time_metrics) {
      this.updateTarget("recordsLastHour", data.real_time_metrics.records_last_hour)
      this.updateTarget("processingRate", `${data.real_time_metrics.processing_rate}/min`)
      this.updateTarget("successRate", `${data.real_time_metrics.sync_success_rate}%`)
      this.updateSystemHealth(data.real_time_metrics.system_health)
    }

    // Update recent activity
    if (data.recent_activity) {
      this.updateRecentActivity(data.recent_activity)
    }
  }

  updateLiveMetrics(metrics) {
    // Animate counter updates
    this.animateCounterUpdate("activeSyncs", metrics.active_jobs)
    this.animateCounterUpdate("recordsLastHour", metrics.records_processed_last_hour)
    
    // Update processing rate with animation
    if (this.hasProcessingRateTarget) {
      this.processingRateTarget.textContent = `${metrics.current_processing_rate}/min`
      this.flashElement(this.processingRateTarget, "text-blue-600")
    }

    // Update system health
    if (metrics.system_health) {
      this.updateSystemHealthDetailed(metrics.system_health)
    }

    // Update recent activity if provided
    if (metrics.recent_activity) {
      this.updateRecentActivity(metrics.recent_activity)
    }

    // Update timestamp
    this.updateLastUpdated()
  }

  handleJobStatusChange(data) {
    const { job, event_type } = data
    
    // Show notification for job events
    if (event_type === 'completed') {
      this.showJobNotification(`Sync completed for ${job.data_source_name}`, 'success')
    } else if (event_type === 'failed') {
      this.showJobNotification(`Sync failed for ${job.data_source_name}`, 'error')
    } else if (event_type === 'started') {
      this.showJobNotification(`Started syncing ${job.data_source_name}`, 'info')
    }

    // Update active syncs count
    this.requestMetricsUpdate()
  }

  updateTarget(targetName, value) {
    const target = this[`${targetName}Target`]
    if (target) {
      target.textContent = value
      this.flashElement(target, "text-blue-600")
    }
  }

  animateCounterUpdate(targetName, newValue) {
    const target = this[`${targetName}Target`]
    if (!target) return

    const currentValue = parseInt(target.textContent) || 0
    const difference = newValue - currentValue

    if (difference !== 0) {
      // Animate the counter
      this.animateCounter(target, currentValue, newValue, 1000)
      
      // Flash color based on change direction
      const flashColor = difference > 0 ? "text-green-600" : "text-red-600"
      this.flashElement(target, flashColor)
    }
  }

  animateCounter(element, start, end, duration) {
    const startTime = performance.now()
    const difference = end - start

    const step = (currentTime) => {
      const elapsed = currentTime - startTime
      const progress = Math.min(elapsed / duration, 1)
      
      // Easing function for smooth animation
      const easedProgress = this.easeInOutCubic(progress)
      const current = Math.round(start + (difference * easedProgress))
      
      element.textContent = this.formatNumber(current)
      
      if (progress < 1) {
        requestAnimationFrame(step)
      }
    }
    
    requestAnimationFrame(step)
  }

  easeInOutCubic(t) {
    return t < 0.5 ? 4 * t * t * t : (t - 1) * (2 * t - 2) * (2 * t - 2) + 1
  }

  flashElement(element, colorClass) {
    element.classList.add(colorClass)
    element.classList.add("transition-colors", "duration-300")
    
    setTimeout(() => {
      element.classList.remove(colorClass)
    }, 2000)
  }

  updateSystemHealth(health) {
    if (!this.hasSystemHealthTarget) return

    const healthConfig = {
      excellent: { color: "text-green-600", bg: "bg-green-100", icon: "✓" },
      good: { color: "text-blue-600", bg: "bg-blue-100", icon: "↑" },
      fair: { color: "text-yellow-600", bg: "bg-yellow-100", icon: "~" },
      poor: { color: "text-orange-600", bg: "bg-orange-100", icon: "↓" },
      critical: { color: "text-red-600", bg: "bg-red-100", icon: "!" }
    }

    const config = healthConfig[health] || healthConfig.fair
    
    this.systemHealthTarget.textContent = `${config.icon} ${health.charAt(0).toUpperCase() + health.slice(1)}`
    this.systemHealthTarget.className = `inline-flex items-center px-3 py-1 rounded-full text-sm font-semibold ${config.color} ${config.bg}`
  }

  updateSystemHealthDetailed(healthData) {
    if (!this.hasSystemHealthTarget) return

    const { status, score, success_rate } = healthData
    
    this.updateSystemHealth(status)
    
    // Update system status if target exists
    if (this.hasSystemStatusTarget) {
      this.systemStatusTarget.innerHTML = `
        <div class="flex items-center gap-2">
          <span class="font-semibold">Health Score: ${score}%</span>
          <span class="text-gray-500">•</span>
          <span>Success Rate: ${success_rate}%</span>
        </div>
      `
    }
  }

  updateRecentActivity(activities) {
    if (!this.hasRecentActivityTarget) return

    const activityHtml = activities.map(activity => {
      const statusColor = this.getStatusColor(activity.status)
      const timeAgo = this.timeAgo(new Date(activity.started_at || activity.updated_at))
      
      return `
        <div class="flex items-center justify-between py-2 border-b border-gray-100 last:border-b-0">
          <div class="flex items-center gap-3">
            <div class="w-2 h-2 rounded-full ${statusColor}"></div>
            <span class="text-sm font-medium">${activity.data_source_name}</span>
          </div>
          <div class="flex items-center gap-2 text-xs text-gray-500">
            <span>${activity.records_processed || 0} records</span>
            <span>•</span>
            <span>${timeAgo}</span>
          </div>
        </div>
      `
    }).join("")

    this.recentActivityTarget.innerHTML = activityHtml
  }

  getStatusColor(status) {
    const colors = {
      completed: "bg-green-500",
      running: "bg-blue-500",
      failed: "bg-red-500",
      queued: "bg-yellow-500",
      cancelled: "bg-gray-500"
    }
    return colors[status] || "bg-gray-400"
  }

  showAlert(alert) {
    const alertColor = alert.severity === 'critical' ? 'red' : 
                      alert.severity === 'warning' ? 'yellow' : 'blue'
    
    this.showNotification(alert.message, alertColor, 5000)
  }

  showUsageWarning(warning) {
    const color = warning.priority === 'error' ? 'red' : 'yellow'
    this.showNotification(warning.message, color, 8000)
  }

  showJobNotification(message, type) {
    const colors = {
      success: 'green',
      error: 'red',
      info: 'blue'
    }
    this.showNotification(message, colors[type] || 'blue', 3000)
  }

  showNotification(message, color, duration = 5000) {
    // Create notification element
    const notification = document.createElement('div')
    notification.className = `fixed top-4 right-4 z-50 p-4 rounded-lg shadow-lg bg-${color}-100 border border-${color}-200 text-${color}-800 transition-all duration-300 transform translate-x-full`
    notification.innerHTML = `
      <div class="flex items-center gap-3">
        <div class="flex-1 text-sm font-medium">${message}</div>
        <button class="text-${color}-600 hover:text-${color}-800" onclick="this.parentElement.parentElement.remove()">
          <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"></path>
          </svg>
        </button>
      </div>
    `

    document.body.appendChild(notification)

    // Animate in
    setTimeout(() => {
      notification.classList.remove('translate-x-full')
    }, 100)

    // Auto-remove
    setTimeout(() => {
      notification.classList.add('translate-x-full')
      setTimeout(() => notification.remove(), 300)
    }, duration)
  }

  updateConnectionStatus(status) {
    // Update connection indicator if it exists
    const indicator = document.querySelector('[data-connection-status]')
    if (indicator) {
      const isConnected = status === 'connected'
      indicator.classList.toggle('bg-green-500', isConnected)
      indicator.classList.toggle('bg-red-500', !isConnected)
      indicator.title = isConnected ? 'Connected to real-time updates' : 'Disconnected from real-time updates'
    }
  }

  animateRecordsUpdate(data) {
    // Animate the total records counter
    this.requestMetricsUpdate()
    
    // Show a subtle notification
    this.showNotification(
      `${data.count} new records from ${data.source_name}`,
      'green',
      2000
    )
  }

  requestMetricsUpdate() {
    if (this.subscription) {
      this.subscription.perform('request_metrics_update')
    }
  }

  startMetricsPolling() {
    // Fallback polling in case WebSocket connection fails
    this.metricsInterval = setInterval(() => {
      this.requestMetricsUpdate()
    }, 30000) // Every 30 seconds
  }

  formatNumber(num) {
    return new Intl.NumberFormat().format(num)
  }

  timeAgo(date) {
    const now = new Date()
    const diffMs = now - date
    const diffMins = Math.floor(diffMs / 60000)
    
    if (diffMins < 1) return 'just now'
    if (diffMins < 60) return `${diffMins}m ago`
    
    const diffHours = Math.floor(diffMins / 60)
    if (diffHours < 24) return `${diffHours}h ago`
    
    const diffDays = Math.floor(diffHours / 24)
    return `${diffDays}d ago`
  }

  updateLastUpdated() {
    const timestamp = document.querySelector('[data-last-updated]')
    if (timestamp) {
      timestamp.textContent = `Updated ${new Date().toLocaleTimeString()}`
    }
  }
};
