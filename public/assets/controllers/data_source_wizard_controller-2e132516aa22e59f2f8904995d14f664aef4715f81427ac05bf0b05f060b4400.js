import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "step", "nextButton", "prevButton", "progressBar", "progressText",
    "stepIndicator", "form", "platformCard", "platformInput", "indicator", "checkmark",
    "nameField", "frequencyField", "nameError", "frequencyError", "stepError", 
    "platformConfig", "testSection", "configFields", "previewContainer", 
    "fileUploadSection", "apiPreviewSection", "launchButton", "saveDraftButton", 
    "loadingOverlay", "loadingText", "mobileStepIndicator", "mobileProgressBar", 
    "nextButtonText", "nextButtonIcon", "launchButtonText", "previewLoading", 
    "previewError", "previewSuccess", "previewErrorMessage", "previewTable", 
    "noPreview", "recordCount", "columnCount", "qualityScore", "estimatedSize", 
    "columnMapping", "columnMappingContent", "summaryPlatformIcon", "summaryPlatformName",
    "summaryPlatformType", "summaryDataSourceName", "summaryDataSourceDescription",
    "summarySyncFrequency", "summarySyncDescription", "summaryDataPreview",
    "summaryDataQuality", "initialSyncField", "autoSyncField", "estimatedSyncTime",
    "nextSyncTime"
  ]

  static values = {
    currentStep: Number,
    totalSteps: Number,
    autoSaveUrl: String,
    autoSaveEnabled: Boolean,
    autoSaveInterval: Number
  }

  connect() {
    this.currentStepValue = 1
    this.totalStepsValue = 4
    this.autoSaveEnabledValue = true
    this.autoSaveIntervalValue = 30000 // 30 seconds
    this.selectedPlatform = null
    this.formData = {}
    this.validationErrors = {}
    this.previewData = null
    
    this.updateDisplay()
    this.setupKeyboardNavigation()
    this.setupAutoSave()
    this.loadDraftData()
  }

  // Auto-save functionality
  setupAutoSave() {
    if (this.autoSaveEnabledValue && this.autoSaveUrlValue) {
      this.autoSaveTimer = setInterval(() => {
        this.performAutoSave()
      }, this.autoSaveIntervalValue)
      
      // Save on form changes
      this.element.addEventListener('input', this.debounce(() => {
        this.performAutoSave()
      }, 2000))
    }
  }

  async performAutoSave() {
    try {
      this.collectFormData()
      const response = await fetch(this.autoSaveUrlValue, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({
          data_source: this.formData,
          current_step: this.currentStepValue,
          draft: true
        })
      })
      
      if (response.ok) {
        this.updateAutoSaveStatus('saved')
      } else {
        this.updateAutoSaveStatus('error')
      }
    } catch (error) {
      console.error('Auto-save failed:', error)
      this.updateAutoSaveStatus('error')
    }
  }

  updateAutoSaveStatus(status) {
    const statusElement = this.element.querySelector('[data-auto-save-target="status"]')
    const timestampElement = this.element.querySelector('[data-auto-save-target="timestamp"]')
    
    if (statusElement && timestampElement) {
      const now = new Date().toLocaleTimeString()
      
      switch (status) {
        case 'saved':
          statusElement.textContent = 'Saved'
          statusElement.className = 'text-green-600 dark:text-green-400'
          break
        case 'saving':
          statusElement.textContent = 'Saving...'
          statusElement.className = 'text-yellow-600 dark:text-yellow-400'
          break
        case 'error':
          statusElement.textContent = 'Save failed'
          statusElement.className = 'text-red-600 dark:text-red-400'
          break
      }
      
      timestampElement.textContent = now
    }
  }

  async saveDraft() {
    this.updateAutoSaveStatus('saving')
    await this.performAutoSave()
  }

  async loadDraftData() {
    // Load any existing draft data from the server
    if (this.autoSaveUrlValue) {
      try {
        const response = await fetch(`${this.autoSaveUrlValue}?draft=true`)
        if (response.ok) {
          const data = await response.json()
          if (data.draft_data) {
            this.populateFormWithDraftData(data.draft_data)
            if (data.current_step) {
              this.currentStepValue = data.current_step
            }
          }
        }
      } catch (error) {
        console.error('Failed to load draft data:', error)
      }
    }
  }

  populateFormWithDraftData(draftData) {
    Object.keys(draftData).forEach(key => {
      const field = this.element.querySelector(`[name="data_source[${key}]"]`)
      if (field) {
        if (field.type === 'checkbox' || field.type === 'radio') {
          field.checked = draftData[key]
        } else {
          field.value = draftData[key]
        }
      }
    })
  }

  collectFormData() {
    const formData = new FormData(this.formTarget)
    this.formData = {}
    
    for (let [key, value] of formData.entries()) {
      if (key.startsWith('data_source[')) {
        const fieldName = key.replace('data_source[', '').replace(']', '')
        this.formData[fieldName] = value
      }
    }
    
    // Add selected platform
    if (this.selectedPlatform) {
      this.formData.source_type = this.selectedPlatform
    }
  }

  nextStep() {
    if (this.validateCurrentStep()) {
      if (this.currentStepValue < this.totalStepsValue) {
        this.currentStepValue++
        this.updateStepDisplay()
        this.updateButtons()
        this.scrollToTop()
        this.performAutoSave()
      }
    }
  }

  prevStep() {
    if (this.currentStepValue > 1) {
      this.currentStepValue--
      this.updateStepDisplay()
      this.updateButtons()
      this.scrollToTop()
    }
  }

  goToStep(event) {
    const targetStep = parseInt(event.currentTarget.dataset.step)
    if (targetStep <= this.currentStepValue || this.canNavigateToStep(targetStep)) {
      this.currentStepValue = targetStep
      this.updateStepDisplay()
      this.updateButtons()
      this.scrollToTop()
    }
  }

  updateStepDisplay() {
    // Hide all steps
    this.stepTargets.forEach((step, index) => {
      if (index + 1 === this.currentStepValue) {
        step.classList.remove('hidden')
        step.classList.add('animate-fade-in')
      } else {
        step.classList.add('hidden')
        step.classList.remove('animate-fade-in')
      }
    })

    // Update current step number display
    const currentStepNumberElement = document.querySelector('[data-data-source-wizard-target="currentStepNumber"]')
    if (currentStepNumberElement) {
      currentStepNumberElement.textContent = this.currentStepValue
    }
    
    // Update step title
    const stepTitleElement = document.querySelector('[data-data-source-wizard-target="stepTitle"]')
    if (stepTitleElement) {
      const stepTitles = ['Choose Data Source', 'Configure Connection', 'Preview Data', 'Review & Finalize']
      stepTitleElement.textContent = stepTitles[this.currentStepValue - 1] || 'Unknown Step'
    }

    // Update progress bar
    if (this.hasProgressBarTarget) {
      const progress = ((this.currentStepValue - 1) / (this.totalStepsValue - 1)) * 100
      this.progressBarTarget.style.width = `${progress}%`
    }
  }

  updateButtons() {
    // Previous button
    if (this.hasPrevButtonTarget) {
      if (this.currentStepValue === 1) {
        this.prevButtonTarget.classList.add('hidden')
      } else {
        this.prevButtonTarget.classList.remove('hidden')
      }
    }

    // Next button
    if (this.hasNextButtonTarget) {
      if (this.currentStepValue === this.totalStepsValue) {
        this.nextButtonTarget.classList.add('hidden')
      } else {
        this.nextButtonTarget.classList.remove('hidden')
      }
    }

    // Submit button
    if (this.hasSubmitButtonTarget) {
      if (this.currentStepValue === this.totalStepsValue) {
        this.submitButtonTarget.classList.remove('hidden')
      } else {
        this.submitButtonTarget.classList.add('hidden')
      }
    }
  }

  // Enhanced validation methods
  validateCurrentStep() {
    this.clearErrors()
    
    switch (this.currentStepValue) {
      case 1:
        return this.validateSourceSelection()
      case 2:
        return this.validateConfiguration()
      case 3:
        return this.validateDataPreview()
      case 4:
        return this.validateFinalSetup()
      default:
        return false
    }
  }

  clearErrors() {
    const currentStepElement = this.stepTargets[this.currentStepValue - 1]
    currentStepElement.querySelectorAll('.error-message').forEach(error => {
      error.remove()
    })
  }

  validateSourceSelection() {
    const selectedPlatform = this.element.querySelector('input[name="data_source[source_type]"]:checked')
    
    if (!selectedPlatform) {
      this.showStepError(1, 'Please select a data source platform')
      return false
    }
    
    this.selectedPlatform = selectedPlatform.value
    this.loadPlatformConfiguration(this.selectedPlatform)
    return true
  }

  validateConfiguration() {
    let isValid = true
    
    // Validate name field
    if (this.hasNameFieldTarget) {
      const name = this.nameFieldTarget.value.trim()
      if (!name) {
        this.showFieldError('nameError', 'Data source name is required')
        isValid = false
      } else if (name.length < 3) {
        this.showFieldError('nameError', 'Name must be at least 3 characters long')
        isValid = false
      }
    }
    
    // Validate sync frequency
    if (this.hasFrequencyFieldTarget) {
      const frequency = this.element.querySelector('input[name="data_source[sync_frequency]"]:checked')
      if (!frequency) {
        this.showFieldError('frequencyError', 'Please select a sync frequency')
        isValid = false
      }
    }
    
    // Validate platform-specific fields
    const platformFields = this.element.querySelectorAll('[data-platform-field][required]')
    platformFields.forEach(field => {
      if (!field.value.trim()) {
        this.showFieldError(`${field.name}Error`, `${field.dataset.label || field.name} is required`)
        isValid = false
      }
    })
    
    if (isValid) {
      this.showTestConnectionSection()
    }
    
    return isValid
  }

  validateDataPreview() {
    // For file uploads, ensure files are uploaded and valid
    if (this.selectedPlatform === 'csv_upload') {
      const fileInput = this.element.querySelector('input[type="file"]')
      if (!fileInput || !fileInput.files.length) {
        this.showStepError(3, 'Please upload at least one file')
        return false
      }
    }
    
    // For API connections, ensure preview data is loaded
    if (this.previewData === null && this.selectedPlatform !== 'csv_upload') {
      this.loadPreviewData()
      return false // Will be validated again after preview loads
    }
    
    return true
  }

  validateFinalSetup() {
    // Update summary with current form data
    this.updateConfigurationSummary()
    return true
  }



  // Platform selection and configuration
  selectPlatform(event) {
    const platformCard = event.currentTarget
    const platformType = platformCard.dataset.platform
    
    // Clear previous selections
    this.platformCardTargets.forEach(card => {
      card.classList.remove('ring-2', 'ring-indigo-500', 'border-indigo-500')
      card.classList.add('border-gray-200', 'dark:border-gray-600')
    })
    
    // Clear all checkmarks
    this.checkmarkTargets.forEach(checkmark => {
      checkmark.classList.remove('scale-100')
      checkmark.classList.add('scale-0')
    })
    
    // Update visual selection for clicked card
    platformCard.classList.remove('border-gray-200', 'dark:border-gray-600')
    platformCard.classList.add('ring-2', 'ring-indigo-500', 'border-indigo-500')
    
    // Show checkmark for selected platform
    const checkmark = this.element.querySelector(`[data-data-source-wizard-target="checkmark"][data-platform="${platformType}"]`)
    if (checkmark) {
      checkmark.classList.remove('scale-0')
      checkmark.classList.add('scale-100')
    }
    
    // Update form data
    const hiddenInput = this.element.querySelector(`input[value="${platformType}"]`)
    if (hiddenInput) {
      hiddenInput.checked = true
    }
    
    this.selectedPlatform = platformType
    this.loadPlatformConfiguration(platformType)
    
    // Enable next button
    if (this.hasNextButtonTarget) {
      this.nextButtonTarget.disabled = false
    }
  }

  loadPlatformConfiguration(platformType) {
    const configContainer = this.element.querySelector('[data-platform-config]')
    if (!configContainer) return
    
    // Show loading state
    configContainer.innerHTML = '<div class="animate-pulse">Loading configuration...</div>'
    
    // Fetch platform-specific configuration form
    fetch(`/data_sources/platform_config?platform=${platformType}`, {
      headers: {
        'Accept': 'text/html',
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    .then(response => response.text())
    .then(html => {
      configContainer.innerHTML = html
      this.initializePlatformFields()
    })
    .catch(error => {
      console.error('Error loading platform configuration:', error)
      configContainer.innerHTML = '<div class="text-red-600">Error loading configuration. Please try again.</div>'
    })
  }

  initializePlatformFields() {
    // Initialize any special field behaviors for the platform
    const platformFields = this.element.querySelectorAll('[data-platform-field]')
    platformFields.forEach(field => {
      field.addEventListener('input', () => {
        this.performAutoSave()
        this.validateField(field)
      })
    })
  }

  validateField(field) {
    const errorContainer = this.element.querySelector(`#${field.name}Error`)
    if (!errorContainer) return
    
    let isValid = true
    let message = ''
    
    if (field.required && !field.value.trim()) {
      isValid = false
      message = `${field.dataset.label || field.name} is required`
    } else if (field.type === 'email' && field.value && !this.isValidEmail(field.value)) {
      isValid = false
      message = 'Please enter a valid email address'
    } else if (field.type === 'url' && field.value && !this.isValidUrl(field.value)) {
      isValid = false
      message = 'Please enter a valid URL'
    }
    
    if (isValid) {
      errorContainer.textContent = ''
      field.classList.remove('border-red-300')
      field.classList.add('border-gray-300')
    } else {
      errorContainer.textContent = message
      field.classList.remove('border-gray-300')
      field.classList.add('border-red-300')
    }
    
    return isValid
  }

  // Test connection functionality
  testConnection() {
    if (!this.hasTestButtonTarget) return
    
    const formData = this.collectFormData()
    
    this.testButtonTarget.disabled = true
    this.testButtonTarget.textContent = 'Testing...'
    
    if (this.hasTestResultsTarget) {
      this.testResultsTarget.innerHTML = '<div class="animate-pulse">Testing connection...</div>'
    }
    
    fetch('/data_sources/test_connection', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({ data_source: formData })
    })
    .then(response => response.json())
    .then(data => {
      this.displayTestResults(data)
    })
    .catch(error => {
      console.error('Connection test failed:', error)
      this.displayTestResults({ success: false, message: 'Connection test failed' })
    })
    .finally(() => {
      this.testButtonTarget.disabled = false
      this.testButtonTarget.textContent = 'Test Connection'
    })
  }

  displayTestResults(results) {
    if (!this.hasTestResultsTarget) return
    
    const resultClass = results.success ? 'bg-green-50 border-green-200 text-green-700' : 'bg-red-50 border-red-200 text-red-700'
    const icon = results.success ? '✓' : '✗'
    
    this.testResultsTarget.innerHTML = `
      <div class="${resultClass} border px-4 py-3 rounded">
        <div class="flex items-center">
          <span class="mr-2">${icon}</span>
          <span>${results.message}</span>
        </div>
        ${results.details ? `<div class="mt-2 text-sm">${results.details}</div>` : ''}
      </div>
    `
    
    if (results.success && this.hasNextButtonTarget) {
      this.nextButtonTarget.disabled = false
    }
  }

  showTestConnectionSection() {
    const testSection = this.element.querySelector('[data-test-connection]')
    if (testSection) {
      testSection.classList.remove('hidden')
    }
  }

  // Data preview functionality
  loadPreviewData() {
    if (!this.selectedPlatform) return
    
    const formData = this.collectFormData()
    
    // Show loading state
    this.showPreviewLoading()
    
    fetch('/data_sources/preview', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({ data_source: formData })
    })
    .then(response => response.json())
    .then(data => {
      this.previewData = data
      this.displayPreviewData(data)
    })
    .catch(error => {
      console.error('Preview loading failed:', error)
      this.showPreviewError('Failed to load data preview')
    })
  }

  showPreviewLoading() {
    const previewContainer = this.element.querySelector('[data-preview-container]')
    if (previewContainer) {
      previewContainer.innerHTML = `
        <div class="flex items-center justify-center py-12">
          <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
          <span class="ml-3">Loading data preview...</span>
        </div>
      `
    }
  }

  displayPreviewData(data) {
    const previewContainer = this.element.querySelector('[data-preview-container]')
    if (!previewContainer) return
    
    if (data.success) {
      previewContainer.innerHTML = this.buildPreviewHTML(data)
      this.updateDataQualityInsights(data.insights)
    } else {
      this.showPreviewError(data.message || 'Failed to load preview')
    }
  }

  buildPreviewHTML(data) {
    const rows = data.preview_data || []
    const columns = data.columns || []
    
    if (rows.length === 0) {
      return '<div class="text-center py-8 text-gray-500">No data available for preview</div>'
    }
    
    let html = `
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
    `
    
    columns.forEach(column => {
      html += `<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">${column.name}</th>`
    })
    
    html += `
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
    `
    
    rows.slice(0, 10).forEach((row, index) => {
      html += `<tr class="${index % 2 === 0 ? 'bg-white' : 'bg-gray-50'}">`
      columns.forEach(column => {
        const value = row[column.name] || ''
        html += `<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">${this.escapeHtml(value)}</td>`
      })
      html += '</tr>'
    })
    
    html += `
          </tbody>
        </table>
      </div>
    `
    
    if (rows.length > 10) {
      html += `<div class="text-center py-2 text-sm text-gray-500">Showing first 10 of ${rows.length} rows</div>`
    }
    
    return html
  }

  updateDataQualityInsights(insights) {
    if (!insights) return
    
    const insightsContainer = this.element.querySelector('[data-quality-insights]')
    if (insightsContainer) {
      insightsContainer.innerHTML = `
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div class="bg-blue-50 p-4 rounded-lg">
            <div class="text-sm font-medium text-blue-900">Total Columns</div>
            <div class="text-2xl font-bold text-blue-600">${insights.column_count || 0}</div>
          </div>
          <div class="bg-green-50 p-4 rounded-lg">
            <div class="text-sm font-medium text-green-900">Data Quality</div>
            <div class="text-2xl font-bold text-green-600">${insights.quality_score || 0}%</div>
          </div>
          <div class="bg-purple-50 p-4 rounded-lg">
            <div class="text-sm font-medium text-purple-900">Estimated Size</div>
            <div class="text-2xl font-bold text-purple-600">${insights.estimated_size || 'Unknown'}</div>
          </div>
        </div>
      `
    }
  }

  showPreviewError(message) {
    const previewContainer = this.element.querySelector('[data-preview-container]')
    if (previewContainer) {
      previewContainer.innerHTML = `
        <div class="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded">
          <div class="flex items-center">
            <span class="mr-2">⚠️</span>
            <span>${message}</span>
          </div>
          <button class="mt-2 text-sm underline" onclick="this.closest('[data-controller]').dispatchEvent(new CustomEvent('retry-preview'))">Try Again</button>
        </div>
      `
    }
  }

  // Configuration summary updates
  updateConfigurationSummary() {
    const formData = this.collectFormData()
    
    // Update platform summary
    this.updateSummaryField('summaryPlatformIcon', this.getPlatformIcon(this.selectedPlatform))
    this.updateSummaryField('summaryPlatformName', this.getPlatformName(this.selectedPlatform))
    
    // Update data source summary
    this.updateSummaryField('summaryDataSourceName', formData.name || 'Unnamed Data Source')
    this.updateSummaryField('summaryDataSourceDescription', formData.description || 'No description')
    
    // Update sync settings summary
    this.updateSummaryField('summarySyncFrequency', this.getFrequencyLabel(formData.sync_frequency))
    this.updateSummaryField('summaryAutoSync', formData.auto_sync_enabled ? 'Enabled' : 'Disabled')
    
    // Update data preview summary
    if (this.previewData && this.previewData.success) {
      this.updateSummaryField('summaryDataPreview', `${this.previewData.row_count || 0} rows, ${this.previewData.column_count || 0} columns`)
    }
  }

  updateSummaryField(targetName, value) {
    const target = this[`${targetName}Target`]
    if (target) {
      if (targetName.includes('Icon')) {
        target.innerHTML = value
      } else {
        target.textContent = value
      }
    }
  }

  // Utility methods
  isValidEmail(email) {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    return emailRegex.test(email)
  }

  isValidUrl(url) {
    try {
      new URL(url)
      return true
    } catch {
      return false
    }
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  getPlatformIcon(platform) {
    const icons = {
      postgresql: '🐘',
      mysql: '🐬',
      salesforce: '☁️',
      hubspot: '🧡',
      csv_upload: '📄',
      api_endpoint: '🔗'
    }
    return icons[platform] || '📊'
  }

  getPlatformName(platform) {
    const names = {
      postgresql: 'PostgreSQL',
      mysql: 'MySQL',
      salesforce: 'Salesforce',
      hubspot: 'HubSpot',
      csv_upload: 'CSV Upload',
      api_endpoint: 'API Endpoint'
    }
    return names[platform] || platform
  }

  getFrequencyLabel(frequency) {
    const labels = {
      manual: 'Manual',
      hourly: 'Every Hour',
      daily: 'Daily',
      weekly: 'Weekly',
      monthly: 'Monthly'
    }
    return labels[frequency] || frequency
  }

  showFieldError(fieldName, message) {
    const errorContainer = this.element.querySelector(`#${fieldName}`)
    if (errorContainer) {
      errorContainer.textContent = message
      errorContainer.classList.remove('hidden')
    }
  }

  showStepError(stepNumber, message) {
    const currentStep = this.stepTargets[stepNumber - 1]
    if (currentStep) {
      const errorDiv = document.createElement('div')
      errorDiv.className = 'error-message bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded mb-4'
      errorDiv.textContent = message
      currentStep.insertBefore(errorDiv, currentStep.firstChild)
    }
  }

  clearErrors() {
    this.element.querySelectorAll('.error-message').forEach(error => {
      error.remove()
    })
    
    // Clear field-specific errors
    this.element.querySelectorAll('[id$="Error"]').forEach(errorContainer => {
      errorContainer.textContent = ''
      errorContainer.classList.add('hidden')
    })
  }

  // File upload handling
  handleFileUpload(event) {
    const files = event.target.files
    if (files.length === 0) return
    
    // Validate file types
    const allowedTypes = ['text/csv', 'application/vnd.ms-excel', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']
    const invalidFiles = Array.from(files).filter(file => !allowedTypes.includes(file.type))
    
    if (invalidFiles.length > 0) {
      this.showFieldError('fileError', 'Please upload only CSV or Excel files')
      return
    }
    
    // Process files
    this.processUploadedFiles(files)
  }

  processUploadedFiles(files) {
    const formData = new FormData()
    Array.from(files).forEach(file => {
      formData.append('files[]', file)
    })
    
    fetch('/data_sources/process_files', {
      method: 'POST',
      headers: {
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: formData
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        this.previewData = data
        this.displayPreviewData(data)
      } else {
        this.showFieldError('fileError', data.message || 'File processing failed')
      }
    })
    .catch(error => {
      console.error('File upload failed:', error)
      this.showFieldError('fileError', 'File upload failed')
    })
  }

  // Launch data source
  launchDataSource() {
    if (!this.validateCurrentStep()) return
    
    const formData = this.collectFormData()
    
    if (this.hasLaunchButtonTarget) {
      this.launchButtonTarget.disabled = true
      this.launchButtonTarget.textContent = 'Launching...'
    }
    
    fetch('/data_sources', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({ data_source: formData })
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        window.location.href = data.redirect_url || '/data_sources'
      } else {
        this.showStepError(4, data.message || 'Failed to create data source')
      }
    })
    .catch(error => {
      console.error('Launch failed:', error)
      this.showStepError(4, 'Failed to create data source')
    })
    .finally(() => {
      if (this.hasLaunchButtonTarget) {
        this.launchButtonTarget.disabled = false
        this.launchButtonTarget.textContent = 'Launch Data Source'
      }
    })
  }

  // Event handlers for retry actions
  retryPreview() {
    this.loadPreviewData()
  }

  retryConnection() {
    this.testConnection()
  }

  // Keyboard navigation
  handleKeydown(event) {
    if (event.key === 'Enter' && event.ctrlKey) {
      // Ctrl+Enter to proceed to next step
      event.preventDefault()
      this.nextStep()
    } else if (event.key === 'Escape') {
      // Escape to go back
      event.preventDefault()
      this.previousStep()
    }
  }

  // Cleanup on disconnect
  disconnect() {
    if (this.autoSaveTimer) {
      clearInterval(this.autoSaveTimer)
    }
  }

  canNavigateToStep(targetStep) {
    // Allow navigation to previous steps or next step if current is valid
    return targetStep <= this.currentStepValue || (targetStep === this.currentStepValue + 1 && this.validateCurrentStep())
  }

  scrollToTop() {
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  // Handle form submission
  submitForm(event) {
    if (!this.validateCurrentStep()) {
      event.preventDefault()
      return false
    }

    // Show loading state
    const submitButton = event.target
    const originalText = submitButton.textContent
    submitButton.disabled = true
    submitButton.innerHTML = `
      <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      Creating Data Source...
    `

    // Reset button after 30 seconds as fallback
    setTimeout(() => {
      submitButton.disabled = false
      submitButton.textContent = originalText
    }, 30000)
  }
};
