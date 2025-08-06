import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["metric", "chart", "status", "lastUpdate"]
  static values = { 
    refreshInterval: { type: Number, default: 5000 },
    endpoint: String
  }

  connect() {
    this.startPolling()
    this.updateStatus("connected")
  }

  disconnect() {
    this.stopPolling()
  }

  startPolling() {
    this.poll()
    this.pollInterval = setInterval(() => {
      this.poll()
    }, this.refreshIntervalValue)
  }

  stopPolling() {
    if (this.pollInterval) {
      clearInterval(this.pollInterval)
    }
  }

  async poll() {
    try {
      const response = await fetch(this.endpointValue || "/api/v1/realtime/metrics", {
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('[name="csrf-token"]').content
        }
      })

      if (!response.ok) throw new Error("Failed to fetch metrics")

      const data = await response.json()
      this.updateMetrics(data)
      this.updateLastUpdate()
      this.updateStatus("connected")
    } catch (error) {
      console.error("Real-time analytics error:", error)
      this.updateStatus("error")
    }
  }

  updateMetrics(data) {
    // Update metric values
    this.metricTargets.forEach(target => {
      const metricName = target.dataset.metric
      const value = data[metricName]
      
      if (value !== undefined) {
        const currentValue = parseFloat(target.textContent) || 0
        const newValue = parseFloat(value)
        
        // Animate the value change
        this.animateValue(target, currentValue, newValue, 500)
        
        // Add change indicator
        this.showChangeIndicator(target, currentValue, newValue)
      }
    })

    // Update charts if any
    if (this.hasChartTarget && data.chartData) {
      this.updateChart(data.chartData)
    }
  }

  animateValue(element, start, end, duration) {
    const range = end - start
    const startTime = performance.now()
    
    const update = (currentTime) => {
      const elapsed = currentTime - startTime
      const progress = Math.min(elapsed / duration, 1)
      
      // Easing function
      const easeOutQuart = 1 - Math.pow(1 - progress, 4)
      const current = start + (range * easeOutQuart)
      
      element.textContent = this.formatValue(current, element.dataset.format)
      
      if (progress < 1) {
        requestAnimationFrame(update)
      }
    }
    
    requestAnimationFrame(update)
  }

  formatValue(value, format) {
    switch (format) {
      case "currency":
        return `$${value.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
      case "percentage":
        return `${value.toFixed(1)}%`
      case "number":
        return value.toLocaleString('en-US')
      default:
        return value.toFixed(2)
    }
  }

  showChangeIndicator(element, oldValue, newValue) {
    const change = newValue - oldValue
    if (Math.abs(change) < 0.01) return

    const indicator = document.createElement("span")
    indicator.className = change > 0 ? "text-green-500" : "text-red-500"
    indicator.textContent = change > 0 ? " ↑" : " ↓"
    
    // Remove any existing indicator
    const existing = element.querySelector(".change-indicator")
    if (existing) existing.remove()
    
    indicator.classList.add("change-indicator", "text-xs", "ml-1")
    element.appendChild(indicator)
    
    // Fade out after 3 seconds
    setTimeout(() => {
      indicator.style.transition = "opacity 1s"
      indicator.style.opacity = "0"
      setTimeout(() => indicator.remove(), 1000)
    }, 3000)
  }

  updateChart(chartData) {
    // This would update a chart instance if using Chart.js
    // Implementation depends on your charting library
  }

  updateLastUpdate() {
    if (this.hasLastUpdateTarget) {
      const now = new Date()
      this.lastUpdateTarget.textContent = `Last updated: ${now.toLocaleTimeString()}`
    }
  }

  updateStatus(status) {
    if (!this.hasStatusTarget) return

    const statusClasses = {
      connected: "bg-green-500",
      error: "bg-red-500",
      loading: "bg-yellow-500"
    }

    this.statusTarget.className = `inline-block w-2 h-2 rounded-full ${statusClasses[status] || statusClasses.loading}`
    this.statusTarget.title = status.charAt(0).toUpperCase() + status.slice(1)
  }

  pause() {
    this.stopPolling()
    this.updateStatus("paused")
  }

  resume() {
    this.startPolling()
  }

  refresh() {
    this.poll()
  }
};
