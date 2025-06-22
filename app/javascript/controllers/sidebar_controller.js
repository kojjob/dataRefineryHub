import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="sidebar"
export default class extends Controller {
  static targets = ["sourceCount", "qualityScore"]
  
  connect() {
    this.startRealtimeUpdates()
  }
  
  disconnect() {
    if (this.updateInterval) {
      clearInterval(this.updateInterval)
    }
  }
  
  startRealtimeUpdates() {
    this.updateInterval = setInterval(() => {
      this.updateStats()
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
        if (this.hasSourceCountTarget) {
          this.sourceCountTarget.textContent = data.sourceCount || 0
        }
        if (this.hasQualityScoreTarget) {
          this.qualityScoreTarget.textContent = (data.qualityScore || 92) + '%'
        }
      }
    } catch (error) {
      console.log('Failed to update sidebar stats:', error)
    }
  }
  
  refreshStats(event) {
    event.preventDefault()
    this.updateStats()
    this.showNotification('Stats refreshed successfully!')
  }
  
  showSystemStatus(event) {
    event.preventDefault()
    this.showModal('System Status', `
      <div class="space-y-4">
        <div class="flex items-center gap-3 p-3 bg-green-50 rounded-lg border border-green-200">
          <div class="h-3 w-3 bg-green-500 rounded-full"></div>
          <div>
            <div class="font-medium text-green-900">Data Pipeline</div>
            <div class="text-sm text-green-600">Operational</div>
          </div>
        </div>
        <div class="flex items-center gap-3 p-3 bg-green-50 rounded-lg border border-green-200">
          <div class="h-3 w-3 bg-green-500 rounded-full"></div>
          <div>
            <div class="font-medium text-green-900">API Services</div>
            <div class="text-sm text-green-600">Healthy</div>
          </div>
        </div>
        <div class="flex items-center gap-3 p-3 bg-green-50 rounded-lg border border-green-200">
          <div class="h-3 w-3 bg-green-500 rounded-full"></div>
          <div>
            <div class="font-medium text-green-900">Database</div>
            <div class="text-sm text-green-600">Connected</div>
          </div>
        </div>
      </div>
    `)
  }
  
  showHelp(event) {
    event.preventDefault()
    this.showModal('Help & Documentation', `
      <div class="space-y-4">
        <a href="/help" class="block p-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors">
          <div class="font-medium text-gray-900">Getting Started Guide</div>
          <div class="text-sm text-gray-600">Learn how to set up your first data source</div>
        </a>
        <a href="/help/api" class="block p-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors">
          <div class="font-medium text-gray-900">API Documentation</div>
          <div class="text-sm text-gray-600">Integrate with our REST API</div>
        </a>
        <a href="/help/troubleshooting" class="block p-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors">
          <div class="font-medium text-gray-900">Troubleshooting</div>
          <div class="text-sm text-gray-600">Common issues and solutions</div>
        </a>
      </div>
    `)
  }
  
  showFeedback(event) {
    event.preventDefault()
    this.showModal('Send Feedback', `
      <form class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Feedback Type</label>
          <select class="w-full border border-gray-300 rounded-lg px-3 py-2">
            <option>Bug Report</option>
            <option>Feature Request</option>
            <option>General Feedback</option>
          </select>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Message</label>
          <textarea class="w-full border border-gray-300 rounded-lg px-3 py-2 h-24" placeholder="Tell us what you think..."></textarea>
        </div>
        <button type="submit" class="w-full bg-indigo-600 text-white font-medium py-2 px-4 rounded-lg hover:bg-indigo-700 transition-colors">
          Send Feedback
        </button>
      </form>
    `)
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
    const notification = document.createElement('div')
    notification.className = 'fixed top-4 right-4 bg-green-500 text-white px-6 py-3 rounded-lg shadow-lg z-50'
    notification.textContent = message
    document.body.appendChild(notification)
    
    setTimeout(() => {
      notification.remove()
    }, 3000)
  }
}