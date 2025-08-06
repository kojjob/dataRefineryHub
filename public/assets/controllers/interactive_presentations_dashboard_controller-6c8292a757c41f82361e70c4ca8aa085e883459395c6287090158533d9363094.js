import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal"]

  connect() {
    console.log("Interactive Presentations Dashboard controller connected")
  }

  createPresentation(event) {
    event.preventDefault()
    this.showCreateModal('presentation')
  }

  createDashboard(event) {
    event.preventDefault()
    this.showCreateModal('dashboard')
  }

  createInteractive(event) {
    event.preventDefault()
    this.showCreateModal('interactive')
  }

  createDataStory(event) {
    event.preventDefault()
    this.showCreateModal('data_story')
  }

  createMonitoring(event) {
    event.preventDefault()
    this.showCreateModal('monitoring')
  }

  showCreateModal(type) {
    // Create modal content based on type
    const modalContent = this.generateModalContent(type)
    
    // Show modal
    this.modalTarget.innerHTML = modalContent
    this.modalTarget.classList.remove('hidden')
    this.modalTarget.classList.add('fixed', 'inset-0', 'z-50', 'overflow-y-auto')
    
    // Add backdrop
    document.body.classList.add('overflow-hidden')
  }

  closeModal(event) {
    if (event) event.preventDefault()
    
    this.modalTarget.classList.add('hidden')
    this.modalTarget.classList.remove('fixed', 'inset-0', 'z-50', 'overflow-y-auto')
    document.body.classList.remove('overflow-hidden')
  }

  generateModalContent(type) {
    const typeConfig = {
      presentation: {
        title: 'Create Interactive Presentation',
        description: 'Create an AI-powered presentation with live data integration',
        icon: 'M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z',
        color: 'purple'
      },
      dashboard: {
        title: 'Create Live Dashboard',
        description: 'Build a real-time monitoring dashboard with alerts',
        icon: 'M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z',
        color: 'indigo'
      },
      interactive: {
        title: 'Interactive Presentation',
        description: 'AI-powered presentation with audience interaction',
        icon: 'M13 10V3L4 14h7v7l9-11h-7z',
        color: 'purple'
      },
      data_story: {
        title: 'Data Story',
        description: 'Narrative-driven insights with compelling visualizations',
        icon: 'M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.746 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253',
        color: 'blue'
      },
      monitoring: {
        title: 'Monitoring Dashboard',
        description: 'Real-time system monitoring with automated alerts',
        icon: 'M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z',
        color: 'green'
      }
    }

    const config = typeConfig[type]
    
    return `
      <div class="bg-black bg-opacity-50 flex items-center justify-center p-4">
        <div class="bg-white rounded-lg max-w-md w-full max-h-screen overflow-y-auto">
          <div class="p-6">
            <div class="flex items-center justify-between mb-4">
              <div class="flex items-center gap-3">
                <div class="h-10 w-10 bg-${config.color}-100 rounded-lg flex items-center justify-center">
                  <svg class="h-5 w-5 text-${config.color}-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="${config.icon}"></path>
                  </svg>
                </div>
                <div>
                  <h3 class="text-lg font-semibold text-gray-900">${config.title}</h3>
                  <p class="text-sm text-gray-600">${config.description}</p>
                </div>
              </div>
              <button data-action="click->interactive-presentations-dashboard#closeModal" class="text-gray-400 hover:text-gray-600">
                <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                </svg>
              </button>
            </div>
            
            <form data-action="submit->interactive-presentations-dashboard#submitForm" data-type="${type}">
              <div class="space-y-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Title</label>
                  <input type="text" name="title" required class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-${config.color}-500 focus:border-transparent" placeholder="Enter presentation title">
                </div>
                
                ${this.generateTypeSpecificFields(type)}
                
                <div class="flex gap-3 pt-4">
                  <button type="submit" class="flex-1 bg-${config.color}-600 text-white py-2 px-4 rounded-lg hover:bg-${config.color}-700 transition-colors">
                    Create ${config.title}
                  </button>
                  <button type="button" data-action="click->interactive-presentations-dashboard#closeModal" class="px-4 py-2 text-gray-600 hover:text-gray-800 transition-colors">
                    Cancel
                  </button>
                </div>
              </div>
            </form>
          </div>
        </div>
      </div>
    `
  }

  generateTypeSpecificFields(type) {
    switch(type) {
      case 'presentation':
      case 'interactive':
        return `
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Presentation Type</label>
            <select name="presentation_type" class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500">
              <option value="business_review">Business Review</option>
              <option value="sales_report">Sales Report</option>
              <option value="financial_analysis">Financial Analysis</option>
              <option value="operational_metrics">Operational Metrics</option>
              <option value="custom">Custom</option>
            </select>
          </div>
          <div>
            <label class="flex items-center gap-2">
              <input type="checkbox" name="live_data_enabled" checked class="rounded border-gray-300 text-purple-600 focus:ring-purple-500">
              <span class="text-sm text-gray-700">Enable live data updates</span>
            </label>
          </div>
          <div>
            <label class="flex items-center gap-2">
              <input type="checkbox" name="audience_interaction" class="rounded border-gray-300 text-purple-600 focus:ring-purple-500">
              <span class="text-sm text-gray-700">Allow audience interaction</span>
            </label>
          </div>
        `
      case 'dashboard':
      case 'monitoring':
        return `
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Refresh Interval</label>
            <select name="refresh_interval" class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500">
              <option value="30">30 seconds</option>
              <option value="60" selected>1 minute</option>
              <option value="300">5 minutes</option>
              <option value="900">15 minutes</option>
            </select>
          </div>
          <div>
            <label class="flex items-center gap-2">
              <input type="checkbox" name="mobile_optimized" checked class="rounded border-gray-300 text-indigo-600 focus:ring-indigo-500">
              <span class="text-sm text-gray-700">Mobile optimized</span>
            </label>
          </div>
          <div>
            <label class="flex items-center gap-2">
              <input type="checkbox" name="sharing_enabled" class="rounded border-gray-300 text-indigo-600 focus:ring-indigo-500">
              <span class="text-sm text-gray-700">Enable sharing</span>
            </label>
          </div>
        `
      case 'data_story':
        return `
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Narrative Type</label>
            <select name="narrative_type" class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500">
              <option value="executive_summary">Executive Summary</option>
              <option value="detailed_analysis">Detailed Analysis</option>
              <option value="trend_story">Trend Story</option>
              <option value="comparative_analysis">Comparative Analysis</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Audience Level</label>
            <select name="audience_level" class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500">
              <option value="executive">Executive</option>
              <option value="management">Management</option>
              <option value="technical">Technical</option>
              <option value="general">General</option>
            </select>
          </div>
          <div>
            <label class="flex items-center gap-2">
              <input type="checkbox" name="ai_commentary" checked class="rounded border-gray-300 text-blue-600 focus:ring-blue-500">
              <span class="text-sm text-gray-700">Include AI commentary</span>
            </label>
          </div>
        `
      default:
        return ''
    }
  }

  async submitForm(event) {
    event.preventDefault()
    
    const form = event.target
    const formData = new FormData(form)
    const type = form.dataset.type
    
    // Convert FormData to object
    const data = {}
    for (let [key, value] of formData.entries()) {
      if (form.querySelector(`[name="${key}"]`).type === 'checkbox') {
        data[key] = form.querySelector(`[name="${key}"]`).checked
      } else {
        data[key] = value
      }
    }
    
    try {
      // Show loading state
      const submitButton = form.querySelector('button[type="submit"]')
      const originalText = submitButton.textContent
      submitButton.textContent = 'Creating...'
      submitButton.disabled = true
      
      // Determine endpoint based on type
      let endpoint
      switch(type) {
        case 'presentation':
        case 'interactive':
          endpoint = '/ai/interactive_presentations/create_interactive'
          break
        case 'dashboard':
        case 'monitoring':
          endpoint = '/ai/interactive_presentations/create_live_dashboard'
          break
        case 'data_story':
          endpoint = '/ai/interactive_presentations/create_data_story'
          break
        default:
          endpoint = '/ai/interactive_presentations/create_interactive'
      }
      
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify(data)
      })
      
      const result = await response.json()
      
      if (result.success) {
        // Show success message
        this.showSuccessMessage(result, type)
        this.closeModal()
        
        // Optionally refresh the page or update the UI
        setTimeout(() => {
          window.location.reload()
        }, 2000)
      } else {
        throw new Error(result.error || 'Failed to create presentation')
      }
    } catch (error) {
      console.error('Error creating presentation:', error)
      this.showErrorMessage(error.message)
    } finally {
      // Reset button state
      const submitButton = form.querySelector('button[type="submit"]')
      submitButton.textContent = originalText
      submitButton.disabled = false
    }
  }

  showSuccessMessage(result, type) {
    // Create and show success notification
    const notification = document.createElement('div')
    notification.className = 'fixed top-4 right-4 bg-green-500 text-white px-6 py-3 rounded-lg shadow-lg z-50'
    notification.innerHTML = `
      <div class="flex items-center gap-2">
        <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
        </svg>
        <span>${type.charAt(0).toUpperCase() + type.slice(1)} created successfully!</span>
      </div>
    `
    
    document.body.appendChild(notification)
    
    setTimeout(() => {
      notification.remove()
    }, 5000)
  }

  showErrorMessage(message) {
    // Create and show error notification
    const notification = document.createElement('div')
    notification.className = 'fixed top-4 right-4 bg-red-500 text-white px-6 py-3 rounded-lg shadow-lg z-50'
    notification.innerHTML = `
      <div class="flex items-center gap-2">
        <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
        </svg>
        <span>Error: ${message}</span>
      </div>
    `
    
    document.body.appendChild(notification)
    
    setTimeout(() => {
      notification.remove()
    }, 5000)
  }
};
