import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { 
    processUrl: String, 
    suggestionsUrl: String 
  }
  
  static targets = [ 
    "queryInput", 
    "submitButton", 
    "submitText", 
    "loadingSpinner",
    "suggestionsDropdown", 
    "suggestionsList",
    "resultsContainer", 
    "resultsContent",
    "toastContainer"
  ]

  connect() {
    this.debounceTimer = null
    this.isProcessing = false
    
    // Close suggestions when clicking outside
    document.addEventListener('click', this.closeSuggestions.bind(this))
  }

  disconnect() {
    document.removeEventListener('click', this.closeSuggestions.bind(this))
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
  }

  submitQuery(event) {
    event.preventDefault()
    
    const query = this.queryInputTarget.value.trim()
    if (!query || this.isProcessing) return
    
    this.processQuery(query)
  }

  async processQuery(query) {
    if (this.isProcessing) return
    
    this.setLoadingState(true)
    this.hideSuggestions()
    
    try {
      const response = await fetch(this.processUrlValue, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCSRFToken()
        },
        body: JSON.stringify({ query: query })
      })
      
      const data = await response.json()
      
      if (data.success) {
        this.displayResults(data)
        this.showToast('Query processed successfully!', 'success')
      } else {
        this.showError(data.error || 'Failed to process query')
        this.showToast(data.error || 'Failed to process query', 'error')
      }
    } catch (error) {
      console.error('Query processing error:', error)
      this.showError('Network error occurred. Please try again.')
      this.showToast('Network error occurred. Please try again.', 'error')
    } finally {
      this.setLoadingState(false)
    }
  }

  handleInput(event) {
    const query = event.target.value.trim()
    
    // Clear previous timer
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
    
    // Debounce suggestions
    if (query.length >= 2) {
      this.debounceTimer = setTimeout(() => {
        this.loadSuggestions(query)
      }, 300)
    } else {
      this.hideSuggestions()
    }
  }

  async loadSuggestions(partialQuery) {
    try {
      const response = await fetch(`${this.suggestionsUrlValue}?q=${encodeURIComponent(partialQuery)}`, {
        headers: {
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      const data = await response.json()
      this.displaySuggestions(data.suggestions || [])
    } catch (error) {
      console.error('Error loading suggestions:', error)
    }
  }

  displaySuggestions(suggestions) {
    if (suggestions.length === 0) {
      this.hideSuggestions()
      return
    }
    
    this.suggestionsListTarget.innerHTML = suggestions.map(suggestion => `
      <button type="button" 
              class="w-full text-left px-4 py-3 hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors duration-150 border-b border-gray-100 dark:border-gray-600 last:border-b-0"
              data-action="click->ai-query#selectSuggestion"
              data-query="${this.escapeHtml(suggestion)}">
        <div class="flex items-center justify-between">
          <span class="text-sm text-gray-700 dark:text-gray-300">${this.escapeHtml(suggestion)}</span>
          <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
          </svg>
        </div>
      </button>
    `).join('')
    
    this.showSuggestions()
  }

  selectSuggestion(event) {
    const query = event.currentTarget.dataset.query
    this.queryInputTarget.value = query
    this.queryInputTarget.focus()
    this.hideSuggestions()
    
    // Auto-submit the selected suggestion
    setTimeout(() => {
      this.processQuery(query)
    }, 100)
  }

  showSuggestions() {
    this.suggestionsDropdownTarget.classList.remove('hidden')
  }

  hideSuggestions() {
    this.suggestionsDropdownTarget.classList.add('hidden')
  }

  closeSuggestions(event) {
    if (!this.element.contains(event.target)) {
      this.hideSuggestions()
    }
  }

  displayResults(data) {
    const results = data.result
    const query = data.query
    
    let html = `
      <div class="space-y-6">
        <!-- Query Summary -->
        <div class="bg-gradient-to-r from-indigo-50 to-blue-50 dark:from-indigo-900/20 dark:to-blue-900/20 rounded-xl p-6 border border-indigo-200 dark:border-indigo-800">
          <h4 class="text-lg font-semibold text-indigo-900 dark:text-indigo-100 mb-2">Query Analysis</h4>
          <p class="text-indigo-700 dark:text-indigo-300 text-sm mb-3">"${this.escapeHtml(query)}"</p>
          <div class="flex items-center space-x-4 text-sm">
            <div class="flex items-center text-green-600 dark:text-green-400">
              <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
              </svg>
              Processed successfully
            </div>
            <div class="text-gray-600 dark:text-gray-400">
              Confidence: ${Math.round((results.confidence || 0.8) * 100)}%
            </div>
            <div class="text-gray-600 dark:text-gray-400">
              ${data.processed_at ? new Date(data.processed_at).toLocaleTimeString() : 'Just now'}
            </div>
          </div>
        </div>
    `
    
    // Display AI Response
    if (results.response) {
      html += `
        <div class="bg-white dark:bg-gray-700 rounded-xl p-6 border border-gray-200 dark:border-gray-600">
          <h4 class="text-lg font-semibold text-gray-900 dark:text-white mb-3 flex items-center">
            <svg class="w-5 h-5 mr-2 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a9 9 0 117.072 0l-.548.547A3.374 3.374 0 0014.846 21H9.154a3.374 3.374 0 00-2.869-1.146l-.548-.547z"></path>
            </svg>
            AI Analysis
          </h4>
          <p class="text-gray-700 dark:text-gray-300 leading-relaxed">${this.escapeHtml(results.response)}</p>
        </div>
      `
    }
    
    // Display Results Data
    if (results.results) {
      html += this.formatResultsData(results.results)
    }
    
    // Display Visualizations Suggestions
    if (results.visualizations && results.visualizations.length > 0) {
      html += `
        <div class="bg-purple-50 dark:bg-purple-900/20 rounded-xl p-6 border border-purple-200 dark:border-purple-800">
          <h4 class="text-lg font-semibold text-purple-900 dark:text-purple-100 mb-3 flex items-center">
            <svg class="w-5 h-5 mr-2 text-purple-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 00-2-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v4"></path>
            </svg>
            Suggested Visualizations
          </h4>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
            ${results.visualizations.map(viz => `
              <div class="p-3 bg-white dark:bg-gray-800 rounded-lg border border-purple-200 dark:border-purple-700">
                <h5 class="font-medium text-purple-900 dark:text-purple-100 text-sm">${this.escapeHtml(viz.title)}</h5>
                <p class="text-purple-700 dark:text-purple-300 text-xs mt-1">${this.escapeHtml(viz.description)}</p>
                <span class="inline-block mt-2 px-2 py-1 text-xs bg-purple-100 dark:bg-purple-900/40 text-purple-700 dark:text-purple-300 rounded">${viz.type}</span>
              </div>
            `).join('')}
          </div>
        </div>
      `
    }
    
    html += '</div>'
    
    this.resultsContentTarget.innerHTML = html
    this.resultsContainerTarget.classList.remove('hidden')
    
    // Smooth scroll to results
    setTimeout(() => {
      this.resultsContainerTarget.scrollIntoView({ 
        behavior: 'smooth', 
        block: 'start' 
      })
    }, 100)
  }

  formatResultsData(results) {
    let html = ''
    
    if (results.count !== undefined) {
      html += `
        <div class="bg-green-50 dark:bg-green-900/20 rounded-xl p-6 border border-green-200 dark:border-green-800">
          <h4 class="text-lg font-semibold text-green-900 dark:text-green-100 mb-3 flex items-center">
            <svg class="w-5 h-5 mr-2 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
            </svg>
            Results Summary
          </h4>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div class="text-center p-4 bg-white dark:bg-gray-800 rounded-lg">
              <div class="text-2xl font-bold text-green-600 dark:text-green-400">${results.count}</div>
              <div class="text-sm text-gray-600 dark:text-gray-400">Total Results</div>
            </div>
            ${results.total_value ? `
              <div class="text-center p-4 bg-white dark:bg-gray-800 rounded-lg">
                <div class="text-2xl font-bold text-blue-600 dark:text-blue-400">$${this.formatNumber(results.total_value)}</div>
                <div class="text-sm text-gray-600 dark:text-gray-400">Total Value</div>
              </div>
            ` : ''}
            ${results.average_value ? `
              <div class="text-center p-4 bg-white dark:bg-gray-800 rounded-lg">
                <div class="text-2xl font-bold text-purple-600 dark:text-purple-400">$${this.formatNumber(results.average_value)}</div>
                <div class="text-sm text-gray-600 dark:text-gray-400">Average Value</div>
              </div>
            ` : ''}
          </div>
        </div>
      `
    }
    
    // Display detailed results if available
    if (results.customers || results.orders || results.products) {
      html += `
        <div class="bg-gray-50 dark:bg-gray-700 rounded-xl p-6 border border-gray-200 dark:border-gray-600">
          <h4 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">Detailed Results</h4>
          <div class="overflow-hidden">
            ${this.formatDetailedResults(results)}
          </div>
        </div>
      `
    }
    
    return html
  }

  formatDetailedResults(results) {
    let html = '<div class="space-y-4">'
    
    if (results.customers && results.customers.length > 0) {
      html += `
        <div>
          <h5 class="font-medium text-gray-900 dark:text-white mb-2">Customers</h5>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
            ${results.customers.slice(0, 6).map(customer => `
              <div class="p-3 bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-600">
                <div class="font-medium text-sm text-gray-900 dark:text-white">${this.escapeHtml(customer.name || customer.id)}</div>
                ${customer.email ? `<div class="text-xs text-gray-600 dark:text-gray-400">${this.escapeHtml(customer.email)}</div>` : ''}
                ${customer.total_spent ? `<div class="text-xs text-green-600 dark:text-green-400">$${this.formatNumber(customer.total_spent)}</div>` : ''}
              </div>
            `).join('')}
          </div>
          ${results.has_more ? '<p class="text-sm text-gray-500 dark:text-gray-400 mt-2">Showing first 6 results...</p>' : ''}
        </div>
      `
    }
    
    if (results.orders && results.orders.length > 0) {
      html += `
        <div>
          <h5 class="font-medium text-gray-900 dark:text-white mb-2">Orders</h5>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
            ${results.orders.slice(0, 6).map(order => `
              <div class="p-3 bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-600">
                <div class="font-medium text-sm text-gray-900 dark:text-white">Order #${this.escapeHtml(order.id)}</div>
                ${order.total ? `<div class="text-xs text-blue-600 dark:text-blue-400">$${this.formatNumber(order.total)}</div>` : ''}
                ${order.date ? `<div class="text-xs text-gray-600 dark:text-gray-400">${new Date(order.date).toLocaleDateString()}</div>` : ''}
              </div>
            `).join('')}
          </div>
          ${results.has_more ? '<p class="text-sm text-gray-500 dark:text-gray-400 mt-2">Showing first 6 results...</p>' : ''}
        </div>
      `
    }
    
    html += '</div>'
    return html
  }

  showError(message) {
    this.resultsContentTarget.innerHTML = `
      <div class="text-center py-8">
        <svg class="w-12 h-12 mx-auto text-red-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 15.5c-.77.833.192 2.5 1.732 2.5z"></path>
        </svg>
        <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-2">Query Processing Failed</h3>
        <p class="text-gray-600 dark:text-gray-400 mb-4">${this.escapeHtml(message)}</p>
        <button data-action="click->ai-query#clearResults" 
                class="inline-flex items-center px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white font-medium rounded-lg transition-colors duration-200">
          Try Again
        </button>
      </div>
    `
    this.resultsContainerTarget.classList.remove('hidden')
  }

  clearResults() {
    this.resultsContainerTarget.classList.add('hidden')
    this.queryInputTarget.focus()
  }

  setLoadingState(loading) {
    this.isProcessing = loading
    
    if (loading) {
      this.submitButtonTarget.disabled = true
      this.submitTextTarget.textContent = 'Processing...'
      this.loadingSpinnerTarget.classList.remove('hidden')
      this.queryInputTarget.disabled = true
    } else {
      this.submitButtonTarget.disabled = false
      this.submitTextTarget.textContent = 'Ask AI'
      this.loadingSpinnerTarget.classList.add('hidden')
      this.queryInputTarget.disabled = false
    }
  }

  showToast(message, type = 'info') {
    const toastId = 'toast-' + Date.now()
    const iconSvg = type === 'success' 
      ? '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>'
      : type === 'error'
      ? '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>'
      : '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>'
    
    const colorClasses = type === 'success' 
      ? 'bg-green-50 border-green-200 text-green-800'
      : type === 'error'
      ? 'bg-red-50 border-red-200 text-red-800'
      : 'bg-blue-50 border-blue-200 text-blue-800'
    
    const toast = document.createElement('div')
    toast.id = toastId
    toast.className = `${colorClasses} border rounded-lg p-4 shadow-lg transform transition-all duration-300 translate-x-full opacity-0`
    toast.style.pointerEvents = 'auto'
    toast.innerHTML = `
      <div class="flex items-center justify-between">
        <div class="flex items-center">
          <svg class="w-5 h-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            ${iconSvg}
          </svg>
          <span class="text-sm font-medium">${this.escapeHtml(message)}</span>
        </div>
        <button data-action="click->ai-query#closeToast" data-toast-id="${toastId}" class="ml-4 text-gray-400 hover:text-gray-600">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        </button>
      </div>
    `
    
    this.toastContainerTarget.appendChild(toast)
    
    // Animate in
    setTimeout(() => {
      toast.classList.remove('translate-x-full', 'opacity-0')
    }, 100)
    
    // Auto-remove after 5 seconds
    setTimeout(() => {
      this.removeToast(toastId)
    }, 5000)
  }

  closeToast(event) {
    const toastId = event.currentTarget.dataset.toastId
    this.removeToast(toastId)
  }

  removeToast(toastId) {
    const toast = document.getElementById(toastId)
    if (toast) {
      toast.classList.add('translate-x-full', 'opacity-0')
      setTimeout(() => {
        toast.remove()
      }, 300)
    }
  }

  // Utility methods
  getCSRFToken() {
    return document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  formatNumber(num) {
    if (num >= 1000000) {
      return (num / 1000000).toFixed(1) + 'M'
    } else if (num >= 1000) {
      return (num / 1000).toFixed(1) + 'K'
    } else {
      return num.toLocaleString()
    }
  }
}
