import { Controller } from "@hotwired/stimulus"
import { showNotification } from "../utils/notifications"

// Connects to data-controller="interactive-presentations"
export default class extends Controller {
  static targets = ["totalCount", "liveDashboards", "dataStories", "totalViews", "recentList", "lastUpdated"]
  static values = { 
    widgetExpanded: Boolean,
    refreshInterval: Number,
    organizationId: String
  }

  connect() {
    console.log("Interactive Presentations controller connected")
    this.refreshData()
    this.startAutoRefresh()
  }

  disconnect() {
    this.stopAutoRefresh()
  }

  // Toggle widget expanded/collapsed state
  toggleWidget() {
    this.widgetExpandedValue = !this.widgetExpandedValue
    const content = this.element.querySelector('[data-interactive-presentations-widget-expanded-value]')
    
    if (content) {
      if (this.widgetExpandedValue) {
        content.style.display = 'block'
        this.refreshData()
      } else {
        content.style.display = 'none'
      }
    }
  }

  // Create Interactive Presentation
  async createInteractive() {
    try {
      const response = await fetch('/ai/interactive_presentations/create_interactive', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCSRFToken()
        },
        body: JSON.stringify({
          title: `Executive Summary - ${new Date().toLocaleDateString()}`,
          presentation_type: 'executive_summary',
          live_data_enabled: true,
          real_time_updates: true,
          interactive_features: ['live_charts', 'real_time_metrics', 'drill_down_analytics']
        })
      })

      const result = await response.json()
      
      if (result.success) {
        showNotification('Interactive presentation created successfully!', 'success')
        this.refreshData()
        
        // Optional: redirect to edit the presentation
        if (result.edit_url) {
          window.location.href = result.edit_url
        }
      } else {
        showNotification(`Failed to create presentation: ${result.error}`, 'error')
      }
    } catch (error) {
      console.error('Error creating interactive presentation:', error)
      showNotification('Failed to create interactive presentation', 'error')
    }
  }

  // Create Live Dashboard
  async createLiveDashboard() {
    try {
      const response = await fetch('/ai/interactive_presentations/create_live_dashboard', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCSRFToken()
        },
        body: JSON.stringify({
          title: `Live Business Dashboard - ${new Date().toLocaleDateString()}`,
          refresh_interval: 30,
          panels: ['kpi', 'revenue', 'customers', 'operations'],
          mobile_optimized: true,
          sharing_enabled: false
        })
      })

      const result = await response.json()
      
      if (result.success) {
        showNotification('Live dashboard created successfully!', 'success')
        this.refreshData()
        
        // Optional: redirect to the live dashboard
        if (result.live_url) {
          window.open(result.live_url, '_blank')
        }
      } else {
        showNotification(`Failed to create dashboard: ${result.error}`, 'error')
      }
    } catch (error) {
      console.error('Error creating live dashboard:', error)
      showNotification('Failed to create live dashboard', 'error')
    }
  }

  // Create AI Data Story
  async createDataStory() {
    try {
      const response = await fetch('/ai/interactive_presentations/create_data_story', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCSRFToken()
        },
        body: JSON.stringify({
          title: `Business Data Story - ${new Date().toLocaleDateString()}`,
          narrative_type: 'business_journey',
          audience_level: 'executive',
          detail_depth: 'medium',
          focus_areas: ['revenue', 'growth', 'efficiency'],
          ai_commentary: true,
          interactive_elements: true
        })
      })

      const result = await response.json()
      
      if (result.success) {
        showNotification('AI data story created successfully!', 'success')
        this.refreshData()
        
        // Optional: redirect to view the story
        if (result.story_url) {
          window.location.href = result.story_url
        }
      } else {
        showNotification(`Failed to create data story: ${result.error}`, 'error')
      }
    } catch (error) {
      console.error('Error creating data story:', error)
      showNotification('Failed to create data story', 'error')
    }
  }

  // Refresh dashboard data
  async refreshData() {
    try {
      const response = await fetch('/ai/interactive_presentations/dashboard_stats', {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCSRFToken()
        }
      })

      const result = await response.json()
      
      if (result.success && result.stats) {
        this.updateDashboardStats(result.stats)
        this.updateLastRefreshTime()
      }
    } catch (error) {
      console.error('Error refreshing presentation data:', error)
    }
  }

  // Update dashboard statistics
  updateDashboardStats(stats) {
    if (this.hasTotalCountTarget) {
      this.totalCountTarget.textContent = stats.total_presentations || '0'
    }
    
    if (this.hasLiveDashboardsTarget) {
      this.liveDashboardsTarget.textContent = stats.live_dashboards || '0'
    }
    
    if (this.hasDataStoriesTarget) {
      this.dataStoriesTarget.textContent = stats.data_stories || '0'
    }
    
    if (this.hasTotalViewsTarget) {
      this.totalViewsTarget.textContent = stats.total_views || '0'
    }

    // Update recent presentations list if available
    if (stats.recent_presentations && this.hasRecentListTarget) {
      this.updateRecentPresentationsList(stats.recent_presentations)
    }
  }

  // Update recent presentations list
  updateRecentPresentationsList(presentations) {
    if (!this.hasRecentListTarget) return

    const html = presentations.map(presentation => `
      <div class="flex items-center justify-between p-4 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors">
        <div class="flex items-center gap-3">
          <div class="h-10 w-10 ${this.getPresentationTypeStyle(presentation.type)} rounded-lg flex items-center justify-center">
            ${this.getPresentationTypeIcon(presentation.type)}
          </div>
          <div>
            <h5 class="text-sm font-medium text-gray-900">${presentation.title}</h5>
            <p class="text-xs text-gray-500">${presentation.type.replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase())} • ${presentation.view_count} views • ${presentation.features}</p>
          </div>
        </div>
        <div class="flex items-center gap-2">
          <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium ${this.getStatusStyle(presentation.status)}">
            ${presentation.status.replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase())}
          </span>
          <button class="text-gray-400 hover:text-gray-600">
            <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
            </svg>
          </button>
        </div>
      </div>
    `).join('')

    this.recentListTarget.innerHTML = html
  }

  // Get presentation type styling
  getPresentationTypeStyle(type) {
    const styles = {
      'executive_summary': 'bg-blue-100',
      'live_dashboard': 'bg-green-100',
      'data_story': 'bg-purple-100',
      'monitoring_dashboard': 'bg-orange-100'
    }
    return styles[type] || 'bg-gray-100'
  }

  // Get presentation type icon
  getPresentationTypeIcon(type) {
    const icons = {
      'executive_summary': '<svg class="h-5 w-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path></svg>',
      'live_dashboard': '<div class="h-2 w-2 bg-green-600 rounded-full animate-pulse"></div>',
      'data_story': '<svg class="h-5 w-5 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"></path></svg>',
      'monitoring_dashboard': '<svg class="h-5 w-5 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"></path></svg>'
    }
    return icons[type] || '<svg class="h-5 w-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path></svg>'
  }

  // Get status styling
  getStatusStyle(status) {
    const styles = {
      'active': 'bg-green-100 text-green-800',
      'draft': 'bg-yellow-100 text-yellow-800',
      'archived': 'bg-gray-100 text-gray-800',
      'live': 'bg-green-100 text-green-800'
    }
    return styles[status] || 'bg-gray-100 text-gray-800'
  }

  // Update last refresh time
  updateLastRefreshTime() {
    if (this.hasLastUpdatedTarget) {
      const now = new Date()
      const timeString = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      this.lastUpdatedTarget.textContent = `Updated ${timeString}`
    }
  }

  // Start auto refresh
  startAutoRefresh() {
    const interval = this.refreshIntervalValue || 300000 // Default 5 minutes
    this.refreshTimer = setInterval(() => {
      if (this.widgetExpandedValue) {
        this.refreshData()
      }
    }, interval)
  }

  // Stop auto refresh
  stopAutoRefresh() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
      this.refreshTimer = null
    }
  }

  // Get CSRF token
  getCSRFToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.getAttribute('content') : ''
  }

  // Handle widget refresh button click
  handleRefresh(event) {
    event.preventDefault()
    this.refreshData()
    showNotification('Presentation data refreshed', 'info')
  }

  // Handle errors gracefully
  handleError(error, operation) {
    console.error(`Error during ${operation}:`, error)
    showNotification(`Failed to ${operation}. Please try again.`, 'error')
  }
}