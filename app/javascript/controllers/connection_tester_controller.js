import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["testButton", "status", "result", "form"]
  static values = { 
    sourceType: String,
    testUrl: String,
    csrfToken: String
  }

  connect() {
    this.isTestingConnection = false
    this.testResults = null
  }

  async testConnection(event) {
    if (event) event.preventDefault()
    
    if (this.isTestingConnection) return

    const formData = this.collectFormData()
    if (!this.validateFormData(formData)) {
      this.showValidationErrors()
      return
    }

    this.isTestingConnection = true
    this.updateTestButton('testing')
    this.updateStatus('testing', 'Testing connection...')

    try {
      const response = await this.performConnectionTest(formData)
      this.handleTestResponse(response)
    } catch (error) {
      this.handleTestError(error)
    } finally {
      this.isTestingConnection = false
      this.updateTestButton('idle')
    }
  }

  collectFormData() {
    const formData = new FormData()
    
    // Add CSRF token
    formData.append('authenticity_token', this.csrfTokenValue)
    
    // Add source type
    formData.append('source_type', this.sourceTypeValue)
    
    // Collect configuration fields based on source type
    const configFields = this.getConfigurationFields()
    configFields.forEach(field => {
      if (field.value.trim()) {
        formData.append(field.name, field.value)
      }
    })

    return formData
  }

  getConfigurationFields() {
    const configSection = document.getElementById('configuration-section')
    if (!configSection) return []

    return Array.from(configSection.querySelectorAll('input, select, textarea'))
      .filter(field => field.name && !field.disabled)
  }

  validateFormData(formData) {
    const requiredFields = this.getRequiredFieldsForSourceType(this.sourceTypeValue)
    
    for (const fieldName of requiredFields) {
      if (!formData.get(fieldName)) {
        return false
      }
    }
    
    return true
  }

  getRequiredFieldsForSourceType(sourceType) {
    const requiredFields = {
      'shopify': ['data_source[config][shop_domain]', 'data_source[config][access_token]'],
      'woocommerce': ['data_source[config][site_url]', 'data_source[config][consumer_key]', 'data_source[config][consumer_secret]'],
      'amazon_seller_central': ['data_source[config][marketplace_id]', 'data_source[config][seller_id]', 'data_source[config][access_key_id]', 'data_source[config][secret_access_key]'],
      'stripe': ['data_source[config][api_key]'],
      'quickbooks': ['data_source[config][client_id]', 'data_source[config][client_secret]'],
      'custom_api': ['data_source[config][api_url]']
    }

    return requiredFields[sourceType] || []
  }

  async performConnectionTest(formData) {
    const testUrl = this.testUrlValue || '/data_sources/test_connection'
    
    const response = await fetch(testUrl, {
      method: 'POST',
      body: formData,
      headers: {
        'X-Requested-With': 'XMLHttpRequest'
      }
    })

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`)
    }

    return await response.json()
  }

  handleTestResponse(response) {
    this.testResults = response

    if (response.success) {
      this.updateStatus('success', response.message || 'Connection successful!')
      this.showConnectionDetails(response.details)
      this.enableFormSubmission()
    } else {
      this.updateStatus('error', response.message || 'Connection failed')
      this.showErrorDetails(response.errors)
    }
  }

  handleTestError(error) {
    console.error('Connection test error:', error)
    this.updateStatus('error', 'Connection test failed. Please check your configuration and try again.')
    this.showErrorDetails([error.message])
  }

  updateTestButton(state) {
    if (!this.hasTestButtonTarget) return

    const button = this.testButtonTarget
    const states = {
      'idle': {
        text: 'Test Connection',
        disabled: false,
        classes: 'bg-indigo-600 hover:bg-indigo-700 text-white',
        icon: `<svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                 <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"></path>
               </svg>`
      },
      'testing': {
        text: 'Testing...',
        disabled: true,
        classes: 'bg-gray-400 text-white cursor-not-allowed',
        icon: `<svg class="animate-spin w-4 h-4 mr-2" fill="none" viewBox="0 0 24 24">
                 <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                 <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
               </svg>`
      }
    }

    const stateConfig = states[state]
    button.disabled = stateConfig.disabled
    button.className = `inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 ${stateConfig.classes}`
    button.innerHTML = `${stateConfig.icon}${stateConfig.text}`
  }

  updateStatus(type, message) {
    if (!this.hasStatusTarget) return

    const statusConfig = {
      'testing': {
        classes: 'bg-blue-50 border-blue-200 text-blue-700',
        icon: `<svg class="animate-spin w-5 h-5" fill="none" viewBox="0 0 24 24">
                 <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                 <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
               </svg>`
      },
      'success': {
        classes: 'bg-green-50 border-green-200 text-green-700',
        icon: `<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                 <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
               </svg>`
      },
      'error': {
        classes: 'bg-red-50 border-red-200 text-red-700',
        icon: `<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                 <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L10 10.586l2.707-2.707a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"></path>
               </svg>`
      }
    }

    const config = statusConfig[type]
    this.statusTarget.className = `flex items-center p-4 border rounded-md ${config.classes}`
    this.statusTarget.innerHTML = `
      <div class="flex-shrink-0">
        ${config.icon}
      </div>
      <div class="ml-3">
        <p class="text-sm font-medium">${message}</p>
      </div>
    `
    this.statusTarget.classList.remove('hidden')
  }

  showConnectionDetails(details) {
    if (!this.hasResultTarget || !details) return

    let detailsHTML = '<div class="mt-4"><h4 class="text-sm font-medium text-green-800 mb-2">Connection Details:</h4><ul class="text-sm text-green-700 space-y-1">'
    
    Object.entries(details).forEach(([key, value]) => {
      const label = this.formatDetailLabel(key)
      detailsHTML += `<li><span class="font-medium">${label}:</span> ${value}</li>`
    })
    
    detailsHTML += '</ul></div>'
    this.resultTarget.innerHTML = detailsHTML
    this.resultTarget.classList.remove('hidden')
  }

  showErrorDetails(errors) {
    if (!this.hasResultTarget || !errors || errors.length === 0) return

    let errorsHTML = '<div class="mt-4"><h4 class="text-sm font-medium text-red-800 mb-2">Error Details:</h4><ul class="text-sm text-red-700 space-y-1">'
    
    errors.forEach(error => {
      errorsHTML += `<li>• ${error}</li>`
    })
    
    errorsHTML += '</ul></div>'
    this.resultTarget.innerHTML = errorsHTML
    this.resultTarget.classList.remove('hidden')
  }

  formatDetailLabel(key) {
    return key.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())
  }

  showValidationErrors() {
    const requiredFields = this.getRequiredFieldsForSourceType(this.sourceTypeValue)
    const configFields = this.getConfigurationFields()
    
    requiredFields.forEach(fieldName => {
      const field = configFields.find(f => f.name === fieldName)
      if (field && !field.value.trim()) {
        this.highlightFieldError(field)
      }
    })

    this.updateStatus('error', 'Please fill in all required fields before testing the connection.')
  }

  highlightFieldError(field) {
    field.classList.add('border-red-300', 'focus:border-red-500', 'focus:ring-red-500')
    field.classList.remove('border-gray-300', 'focus:border-indigo-500', 'focus:ring-indigo-500')
    
    // Remove error styling after user starts typing
    const removeErrorStyling = () => {
      field.classList.remove('border-red-300', 'focus:border-red-500', 'focus:ring-red-500')
      field.classList.add('border-gray-300', 'focus:border-indigo-500', 'focus:ring-indigo-500')
      field.removeEventListener('input', removeErrorStyling)
    }
    
    field.addEventListener('input', removeErrorStyling)
  }

  enableFormSubmission() {
    // Dispatch event to notify wizard that connection test passed
    this.dispatch('connectionTestPassed', { 
      detail: { 
        sourceType: this.sourceTypeValue, 
        testResults: this.testResults 
      } 
    })
  }

  // Reset the connection test state
  reset() {
    this.isTestingConnection = false
    this.testResults = null
    
    if (this.hasStatusTarget) {
      this.statusTarget.classList.add('hidden')
    }
    
    if (this.hasResultTarget) {
      this.resultTarget.classList.add('hidden')
    }
    
    this.updateTestButton('idle')
  }

  // Get test results for external access
  getTestResults() {
    return this.testResults
  }

  // Check if connection test has passed
  hasPassedTest() {
    return this.testResults && this.testResults.success
  }
}