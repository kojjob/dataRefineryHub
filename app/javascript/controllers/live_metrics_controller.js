import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["revenue", "users", "timestamp"]

  connect() {
    console.log("Live Metrics controller connected")
    this.startMetricsUpdates()
  }

  disconnect() {
    this.stopMetricsUpdates()
  }

  startMetricsUpdates() {
    // Initial load
    this.updateTimestamp()
    
    // Set up periodic updates every 30 seconds
    this.updateInterval = setInterval(() => {
      this.simulateMetricsUpdate()
      this.updateTimestamp()
    }, 30000)

    // Set up timestamp updates every 5 seconds
    this.timestampInterval = setInterval(() => {
      this.updateTimestamp()
    }, 5000)
  }

  stopMetricsUpdates() {
    if (this.updateInterval) {
      clearInterval(this.updateInterval)
    }
    if (this.timestampInterval) {
      clearInterval(this.timestampInterval)
    }
  }

  simulateMetricsUpdate() {
    // Simulate realistic metric variations
    if (this.hasRevenueTarget) {
      this.updateRevenue()
    }
    
    if (this.hasUsersTarget) {
      this.updateUsers()
    }
  }

  updateRevenue() {
    const currentRevenue = this.getCurrentRevenue()
    const variation = this.calculateRevenueVariation(currentRevenue)
    const newRevenue = Math.max(currentRevenue + variation, 500)
    
    this.animateMetricChange(this.revenueTarget, `$${newRevenue}`, 'revenue')
  }

  updateUsers() {
    const currentUsers = this.getCurrentUsers()
    const variation = this.calculateUsersVariation(currentUsers)
    const newUsers = Math.max(currentUsers + variation, 20)
    
    this.animateMetricChange(this.usersTarget, newUsers, 'users')
  }

  getCurrentRevenue() {
    const text = this.revenueTarget.textContent.replace(/[^0-9]/g, '')
    return parseInt(text) || 1247
  }

  getCurrentUsers() {
    const text = this.usersTarget.textContent.replace(/[^0-9]/g, '')
    return parseInt(text) || 156
  }

  calculateRevenueVariation(current) {
    // More realistic revenue variations based on time of day
    const hour = new Date().getHours()
    const isBusinessHours = hour >= 9 && hour <= 17
    const baseVariation = isBusinessHours ? 50 : 20
    
    return Math.floor(Math.random() * baseVariation * 2) - baseVariation
  }

  calculateUsersVariation(current) {
    // User count variations
    const hour = new Date().getHours()
    const isPeakHours = (hour >= 10 && hour <= 12) || (hour >= 14 && hour <= 16)
    const baseVariation = isPeakHours ? 10 : 5
    
    return Math.floor(Math.random() * baseVariation * 2) - baseVariation
  }

  animateMetricChange(element, newValue, metricType) {
    // Add highlight effect
    element.style.transition = 'all 0.3s ease'
    element.style.transform = 'scale(1.05)'
    
    // Determine color based on change
    const isPositive = this.isPositiveChange(element, newValue, metricType)
    element.style.color = isPositive ? '#10b981' : '#ef4444' // green or red
    
    setTimeout(() => {
      element.textContent = newValue
      element.style.transform = 'scale(1)'
      
      setTimeout(() => {
        element.style.color = '' // Reset to original color
      }, 1000)
    }, 150)
  }

  isPositiveChange(element, newValue, metricType) {
    if (metricType === 'revenue') {
      const oldValue = parseInt(element.textContent.replace(/[^0-9]/g, ''))
      const numericNewValue = parseInt(newValue.replace(/[^0-9]/g, ''))
      return numericNewValue > oldValue
    } else if (metricType === 'users') {
      const oldValue = parseInt(element.textContent)
      return newValue > oldValue
    }
    return true
  }

  updateTimestamp() {
    if (this.hasTimestampTarget) {
      const now = new Date()
      const timeString = now.toLocaleTimeString([], { 
        hour: '2-digit', 
        minute: '2-digit',
        second: '2-digit'
      })
      this.timestampTarget.textContent = timeString
    }
  }

  // Manual refresh trigger
  refresh() {
    this.simulateMetricsUpdate()
    this.updateTimestamp()
    
    // Show brief loading state
    if (this.hasTimestampTarget) {
      const originalText = this.timestampTarget.textContent
      this.timestampTarget.textContent = 'Updating...'
      
      setTimeout(() => {
        this.updateTimestamp()
      }, 500)
    }
  }
}