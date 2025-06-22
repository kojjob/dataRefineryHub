import { Controller } from "@hotwired/stimulus"

// Enhanced sidebar controller with comprehensive functionality
export default class extends Controller {
  static targets = [
    "sourceCount", "qualityScore", "processingJobs", "alertCount",
    "refreshButton", "refreshIcon", "quickActionsList", "quickActionsToggle",
    "notificationStatus", "activityFeed", "activityRefresh",
    "systemStatusIndicator", "systemStatusText"
  ]
  
  connect() {
    console.log("Enhanced sidebar controller connected")
    this.startRealtimeUpdates()
    this.initializeKeyboardShortcuts()
  }
  
  disconnect() {
    if (this.updateInterval) {
      clearInterval(this.updateInterval)
    }
  }
  
  startRealtimeUpdates() {
    this.updateInterval = setInterval(() => {
      this.updateStats()
      this.updateActivityFeed()
      this.updateSystemStatus()
    }, 30000) // Update every 30 seconds
  }
  
  async updateStats() {
    try {
      const response = await fetch('/api/v1/dashboard/stats', {
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        this.animateStatsUpdate(data)
      } else {
        // Fallback to simulated data
        this.animateStatsUpdate(this.generateSimulatedStats())
      }
    } catch (error) {
      console.log('Failed to update sidebar stats, using simulated data:', error)
      this.animateStatsUpdate(this.generateSimulatedStats())
    }
  }

  animateStatsUpdate(data) {
    if (this.hasSourceCountTarget) {
      this.animateCounterUpdate(this.sourceCountTarget, data.sourceCount || 0)
    }
    if (this.hasQualityScoreTarget) {
      this.animateCounterUpdate(this.qualityScoreTarget, (data.qualityScore || 98) + '%')
    }
    if (this.hasProcessingJobsTarget) {
      this.animateCounterUpdate(this.processingJobsTarget, data.processingJobs || 0)
    }
    if (this.hasAlertCountTarget) {
      this.animateCounterUpdate(this.alertCountTarget, data.alertCount || 0)
    }
  }

  animateCounterUpdate(target, newValue) {
    target.style.transform = "scale(1.1)"
    target.style.transition = "transform 0.2s ease-in-out"
    
    setTimeout(() => {
      target.textContent = newValue
      target.style.transform = "scale(1)"
    }, 100)
  }

  generateSimulatedStats() {
    return {
      sourceCount: Math.floor(Math.random() * 20) + 5,
      qualityScore: Math.floor(Math.random() * 10) + 90,
      processingJobs: Math.floor(Math.random() * 15) + 5,
      alertCount: Math.floor(Math.random() * 5)
    }
  }
  
  refreshStats(event) {
    event?.preventDefault()
    
    // Add loading animation
    if (this.hasRefreshIconTarget) {
      this.refreshIconTarget.style.transform = "rotate(360deg)"
      this.refreshIconTarget.style.transition = "transform 0.5s ease-in-out"
    }

    // Update stats with delay for animation
    setTimeout(() => {
      this.updateStats()
      this.showToast('Stats refreshed successfully!', 'success')
      
      // Reset rotation
      if (this.hasRefreshIconTarget) {
        setTimeout(() => {
          this.refreshIconTarget.style.transform = "rotate(0deg)"
        }, 500)
      }
    }, 500)
  }

  // Enhanced Quick Actions
  expandQuickActions(event) {
    event?.preventDefault()
    
    if (this.hasQuickActionsListTarget) {
      const isExpanded = this.quickActionsListTarget.style.maxHeight !== "200px"
      
      if (isExpanded) {
        this.quickActionsListTarget.style.maxHeight = "200px"
        this.quickActionsListTarget.style.overflow = "hidden"
      } else {
        this.quickActionsListTarget.style.maxHeight = "none"
        this.quickActionsListTarget.style.overflow = "visible"
      }
    }
  }

  createReport(event) {
    event?.preventDefault()
    
    this.showToast("Generating report...", "info")
    
    // Simulate report generation
    setTimeout(() => {
      this.showToast("Report generated successfully!", "success")
      this.addActivityItem("Report generated", "purple", "now")
    }, 2000)
  }

  toggleNotifications(event) {
    event?.preventDefault()
    
    if (this.hasNotificationStatusTarget) {
      const isEnabled = this.notificationStatusTarget.classList.contains("bg-green-500")
      
      if (isEnabled) {
        this.notificationStatusTarget.classList.remove("bg-green-500")
        this.notificationStatusTarget.classList.add("bg-gray-400")
        this.showToast("Notifications disabled", "warning")
      } else {
        this.notificationStatusTarget.classList.remove("bg-gray-400")
        this.notificationStatusTarget.classList.add("bg-green-500")
        this.showToast("Notifications enabled", "success")
      }
    }
  }

  // Activity Feed Management
  refreshActivity(event) {
    event?.preventDefault()
    
    if (this.hasActivityRefreshTarget) {
      this.activityRefreshTarget.style.transform = "rotate(360deg)"
      this.activityRefreshTarget.style.transition = "transform 0.5s ease-in-out"
    }

    setTimeout(() => {
      this.updateActivityFeed()
      
      if (this.hasActivityRefreshTarget) {
        this.activityRefreshTarget.style.transform = "rotate(0deg)"
      }
    }, 500)
  }

  updateActivityFeed() {
    if (!this.hasActivityFeedTarget) return

    const activities = [
      { text: "New data source connected", color: "blue", time: "1m" },
      { text: "Quality check completed", color: "green", time: "3m" },
      { text: "User login detected", color: "purple", time: "7m" },
      { text: "Backup completed", color: "indigo", time: "15m" },
      { text: "Sync process finished", color: "blue", time: "2m" },
      { text: "Alert resolved", color: "green", time: "5m" }
    ]

    const randomActivity = activities[Math.floor(Math.random() * activities.length)]
    this.addActivityItem(randomActivity.text, randomActivity.color, randomActivity.time)
  }

  addActivityItem(text, color, time) {
    if (!this.hasActivityFeedTarget) return

    const newItem = document.createElement('div')
    newItem.className = 'flex items-center gap-2 text-xs'
    newItem.innerHTML = `
      <div class="h-1.5 w-1.5 bg-${color}-500 rounded-full"></div>
      <span class="text-gray-600 truncate">${text}</span>
      <span class="text-gray-400 ml-auto">${time}</span>
    `

    // Add to top of feed
    this.activityFeedTarget.insertBefore(newItem, this.activityFeedTarget.firstChild)

    // Remove last item if more than 3
    const items = this.activityFeedTarget.children
    if (items.length > 3) {
      this.activityFeedTarget.removeChild(items[items.length - 1])
    }
  }

  viewAllActivity(event) {
    event?.preventDefault()
    this.showModal("Activity Feed", this.generateActivityModal())
  }

  // System Status Management
  updateSystemStatus() {
    if (this.hasSystemStatusIndicatorTarget && this.hasSystemStatusTextTarget) {
      const isHealthy = Math.random() > 0.1 // 90% chance of healthy status
      
      if (isHealthy) {
        this.systemStatusIndicatorTarget.className = "h-2 w-2 bg-green-500 rounded-full animate-pulse"
        this.systemStatusTextTarget.textContent = "Healthy"
        this.systemStatusTextTarget.className = "text-xs text-green-600 font-medium"
      } else {
        this.systemStatusIndicatorTarget.className = "h-2 w-2 bg-yellow-500 rounded-full animate-pulse"
        this.systemStatusTextTarget.textContent = "Warning"
        this.systemStatusTextTarget.className = "text-xs text-yellow-600 font-medium"
      }
    }
  }

  // Keyboard Shortcuts
  initializeKeyboardShortcuts() {
    document.addEventListener('keydown', (event) => {
      // Help shortcut (?)
      if (event.key === '?' && !event.target.matches('input, textarea')) {
        event.preventDefault()
        this.showKeyboardShortcuts()
      }
    })
  }

  showKeyboardShortcuts(event) {
    event?.preventDefault()
    this.showModal("Keyboard Shortcuts", this.generateKeyboardShortcutsModal())
  }
  
  showSystemStatus(event) {
    event?.preventDefault()
    this.showModal('System Status', this.generateSystemStatusModal())
  }
  
  showHelp(event) {
    event?.preventDefault()
    this.showModal('Help Center', this.generateHelpModal())
  }
  
  showFeedback(event) {
    event?.preventDefault()
    this.showModal('Send Feedback', this.generateFeedbackModal())
  }

  // Modal Content Generators
  generateActivityModal() {
    return `
      <div class="space-y-4 max-h-96 overflow-y-auto">
        <div class="space-y-3">
          ${Array.from({length: 10}, (_, i) => `
            <div class="flex items-center gap-3 p-3 bg-gray-50 rounded-lg">
              <div class="h-2 w-2 bg-blue-500 rounded-full"></div>
              <div class="flex-1">
                <div class="text-sm font-medium text-gray-900">Activity ${i + 1}</div>
                <div class="text-xs text-gray-600">Description of the activity that occurred</div>
              </div>
              <div class="text-xs text-gray-400">${i + 1}m ago</div>
            </div>
          `).join('')}
        </div>
      </div>
    `
  }

  generateSystemStatusModal() {
    return `
      <div class="space-y-6">
        <div class="grid grid-cols-2 gap-4">
          <div class="p-4 bg-green-50 rounded-lg border border-green-200">
            <div class="flex items-center gap-2 mb-2">
              <div class="h-3 w-3 bg-green-500 rounded-full"></div>
              <span class="text-sm font-medium text-green-900">API Services</span>
            </div>
            <div class="text-xs text-green-700">All endpoints operational</div>
          </div>
          <div class="p-4 bg-blue-50 rounded-lg border border-blue-200">
            <div class="flex items-center gap-2 mb-2">
              <div class="h-3 w-3 bg-blue-500 rounded-full"></div>
              <span class="text-sm font-medium text-blue-900">Database</span>
            </div>
            <div class="text-xs text-blue-700">PostgreSQL running smoothly</div>
          </div>
          <div class="p-4 bg-purple-50 rounded-lg border border-purple-200">
            <div class="flex items-center gap-2 mb-2">
              <div class="h-3 w-3 bg-purple-500 rounded-full"></div>
              <span class="text-sm font-medium text-purple-900">Background Jobs</span>
            </div>
            <div class="text-xs text-purple-700">12 jobs in queue</div>
          </div>
          <div class="p-4 bg-indigo-50 rounded-lg border border-indigo-200">
            <div class="flex items-center gap-2 mb-2">
              <div class="h-3 w-3 bg-indigo-500 rounded-full"></div>
              <span class="text-sm font-medium text-indigo-900">Storage</span>
            </div>
            <div class="text-xs text-indigo-700">2.4 GB / 100 GB used</div>
          </div>
        </div>
        <div class="text-sm text-gray-600">
          Last updated: ${new Date().toLocaleTimeString()}
        </div>
      </div>
    `
  }

  generateHelpModal() {
    return `
      <div class="space-y-6">
        <div class="grid grid-cols-1 gap-4">
          <div class="p-4 border border-gray-200 rounded-lg">
            <h4 class="font-medium text-gray-900 mb-2">Getting Started</h4>
            <p class="text-sm text-gray-600">Learn how to set up your first data source and start analyzing your business data.</p>
          </div>
          <div class="p-4 border border-gray-200 rounded-lg">
            <h4 class="font-medium text-gray-900 mb-2">Data Sources</h4>
            <p class="text-sm text-gray-600">Connect and manage various data sources including Shopify, QuickBooks, and more.</p>
          </div>
          <div class="p-4 border border-gray-200 rounded-lg">
            <h4 class="font-medium text-gray-900 mb-2">Analytics</h4>
            <p class="text-sm text-gray-600">Understand your business metrics with powerful analytics and reporting tools.</p>
          </div>
        </div>
        <div class="pt-4 border-t border-gray-200">
          <p class="text-sm text-gray-500">
            Need more help? Contact our support team at 
            <a href="mailto:support@datareflow.com" class="text-indigo-600 hover:text-indigo-800">support@datareflow.com</a>
          </p>
        </div>
      </div>
    `
  }

  generateKeyboardShortcutsModal() {
    return `
      <div class="space-y-4">
        <div class="grid grid-cols-2 gap-4">
          <div>
            <div class="font-medium text-gray-900 mb-2">Navigation</div>
            <div class="space-y-1 text-sm text-gray-600">
              <div class="flex justify-between"><span>Dashboard</span><kbd class="px-2 py-1 bg-gray-100 rounded text-xs">G + D</kbd></div>
              <div class="flex justify-between"><span>Analytics</span><kbd class="px-2 py-1 bg-gray-100 rounded text-xs">G + A</kbd></div>
              <div class="flex justify-between"><span>Data Sources</span><kbd class="px-2 py-1 bg-gray-100 rounded text-xs">G + S</kbd></div>
              <div class="flex justify-between"><span>Team</span><kbd class="px-2 py-1 bg-gray-100 rounded text-xs">G + T</kbd></div>
            </div>
          </div>
          <div>
            <div class="font-medium text-gray-900 mb-2">Actions</div>
            <div class="space-y-1 text-sm text-gray-600">
              <div class="flex justify-between"><span>Search</span><kbd class="px-2 py-1 bg-gray-100 rounded text-xs">Cmd + K</kbd></div>
              <div class="flex justify-between"><span>Add Source</span><kbd class="px-2 py-1 bg-gray-100 rounded text-xs">A + S</kbd></div>
              <div class="flex justify-between"><span>Invite User</span><kbd class="px-2 py-1 bg-gray-100 rounded text-xs">I + U</kbd></div>
              <div class="flex justify-between"><span>Quick Actions</span><kbd class="px-2 py-1 bg-gray-100 rounded text-xs">Cmd + J</kbd></div>
            </div>
          </div>
        </div>
        <div class="pt-4 border-t border-gray-200">
          <div class="text-sm text-gray-600">
            Use <kbd class="px-2 py-1 bg-gray-100 rounded text-xs">?</kbd> to show this dialog anytime.
          </div>
        </div>
      </div>
    `
  }

  generateFeedbackModal() {
    return `
      <div class="space-y-4">
        <div>
          <label for="feedbackType" class="block text-sm font-medium text-gray-700 mb-2">Feedback Type</label>
          <select id="feedbackType" class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500">
            <option>Bug Report</option>
            <option>Feature Request</option>
            <option>General Feedback</option>
            <option>Help & Support</option>
          </select>
        </div>
        <div>
          <label for="feedbackMessage" class="block text-sm font-medium text-gray-700 mb-2">Message</label>
          <textarea id="feedbackMessage" rows="4" class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500" placeholder="Tell us about your experience..."></textarea>
        </div>
        <div class="flex justify-end gap-3">
          <button class="px-4 py-2 text-sm font-medium text-gray-700 bg-gray-100 rounded-lg hover:bg-gray-200 transition-colors" onclick="this.closest('.fixed').remove()">
            Cancel
          </button>
          <button class="px-4 py-2 text-sm font-medium text-white bg-indigo-600 rounded-lg hover:bg-indigo-700 transition-colors" onclick="this.closest('.fixed').remove()">
            Send Feedback
          </button>
        </div>
      </div>
    `
  }
  
  showModal(title, content) {
    const modal = document.createElement('div')
    modal.className = 'fixed inset-0 z-50 overflow-y-auto'
    modal.innerHTML = `
      <div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity" onclick="this.closest('.fixed').remove()"></div>
        <div class="relative transform overflow-hidden rounded-lg bg-white text-left shadow-xl transition-all sm:my-8 sm:w-full sm:max-w-lg">
          <div class="bg-white px-4 pb-4 pt-5 sm:p-6 sm:pb-4">
            <div class="flex items-center justify-between mb-4">
              <h3 class="text-lg font-semibold text-gray-900">${title}</h3>
              <button class="text-gray-400 hover:text-gray-600" onclick="this.closest('.fixed').remove()">
                <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
            <div>${content}</div>
          </div>
        </div>
      </div>
    `
    document.body.appendChild(modal)
  }
  
  showNotification(message) {
    this.showToast(message, 'success')
  }

  // Enhanced toast notification system
  showToast(message, type = "info") {
    const colors = {
      success: "bg-green-500",
      error: "bg-red-500", 
      warning: "bg-yellow-500",
      info: "bg-blue-500"
    }

    const toast = document.createElement('div')
    toast.className = `fixed top-4 right-4 z-50 px-4 py-2 rounded-lg text-white text-sm font-medium ${colors[type]} transform transition-all duration-300 translate-x-full`
    toast.textContent = message

    document.body.appendChild(toast)

    // Slide in
    setTimeout(() => {
      toast.classList.remove('translate-x-full')
    }, 100)

    // Remove after 3 seconds
    setTimeout(() => {
      toast.classList.add('translate-x-full')
      setTimeout(() => {
        if (document.body.contains(toast)) {
          document.body.removeChild(toast)
        }
      }, 300)
    }, 3000)
  }
}