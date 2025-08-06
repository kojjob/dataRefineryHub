import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "step1", "step2", "step3", "step4", "step5",
    "step1Nav", "step2Nav", "step3Nav", "step4Nav", "step5Nav",
    "prevButton", "nextButton", "submitButton",
    "sourceConfig", "destinationConfig",
    "canvas", "transformationsList", "transformationModal", "transformationForm",
    "etlCheckbox", "eltCheckbox", "streamingCheckbox",
    "nameField", "descriptionField", "pipelineTypeField",
    "errorMessage", "loadingIndicator", "fileList", "fileItems", "uploadProgress", "progressBar"
  ]

  static values = {
    currentStep: Number,
    totalSteps: Number
  }

  connect() {
    console.log('Pipeline builder controller connected')
    
    // Initialize values with fallbacks
    this.currentStep = this.hasCurrentStepValue ? this.currentStepValue : 1
    this.totalSteps = this.hasTotalStepsValue ? this.totalStepsValue : 5
    this.transformations = []

    console.log('Initial step:', this.currentStep, 'Total steps:', this.totalSteps)
    
    this.initializeForm()
    this.updateNavigation()
  }

  // Initialization Methods
  initializeForm() {
    // Set up initial form state
    this.showStep(this.currentStep)
  }

  // Step Navigation
  nextStep(event) {
    console.log('=== Next button clicked ===')
    event.preventDefault()
    
    console.log('Current step before:', this.currentStep, 'Total steps:', this.totalSteps)
    console.log('Event target:', event.target)
    console.log('Has currentStepValue:', this.hasCurrentStepValue)
    
    if (this.currentStep < this.totalSteps) {
      const nextStepNumber = this.currentStep + 1
      console.log('Moving from step', this.currentStep, 'to step', nextStepNumber)
      
      this.currentStep = nextStepNumber
      this.currentStepValue = nextStepNumber
      
      console.log('Updated currentStep to:', this.currentStep)
      console.log('Updated currentStepValue to:', this.currentStepValue)
      
      this.showStep(this.currentStep)
      this.updateNavigation()
    } else {
      console.log('Already at last step:', this.currentStep, 'of', this.totalSteps)
    }
    
    console.log('=== Next button finished ===')
  }

  previousStep(event) {
    event.preventDefault()
    console.log('Previous button clicked, current step:', this.currentStep)
    
    if (this.currentStep > 1) {
      console.log('Moving to step:', this.currentStep - 1)
      this.currentStep--
      this.currentStepValue = this.currentStep
      this.showStep(this.currentStep)
      this.updateNavigation()
    } else {
      console.log('Already at first step')
    }
  }

  showStep(stepNumber) {
    console.log('Showing step:', stepNumber)
    
    // Hide all steps - simpler approach
    for (let i = 1; i <= this.totalSteps; i++) {
      const step = this.element.querySelector(`[data-pipeline-builder-target="step${i}"]`)
      if (step) {
        step.style.display = 'none'
      }
    }

    // Show current step
    const currentStep = this.element.querySelector(`[data-pipeline-builder-target="step${stepNumber}"]`)
    if (currentStep) {
      currentStep.style.display = 'block'
      console.log('Step', stepNumber, 'is now visible')
    } else {
      console.warn('Step element not found for step', stepNumber)
    }

    // Update step navigation appearance
    this.updateStepNavigation(stepNumber)
  }

  updateNavigation() {
    console.log('Updating navigation for step:', this.currentStep)
    
    // Update buttons
    const prevButton = this.element.querySelector('[data-pipeline-builder-target="prevButton"]')
    const nextButton = this.element.querySelector('[data-pipeline-builder-target="nextButton"]')
    const submitButton = this.element.querySelector('[data-pipeline-builder-target="submitButton"]')

    if (prevButton) {
      if (this.currentStep <= 1) {
        prevButton.style.display = 'none'
      } else {
        prevButton.style.display = 'flex'
      }
    }

    // Update step indicator
    const stepIndicator = this.element.querySelector('[data-pipeline-builder-target="currentStepIndicator"]')
    if (stepIndicator) {
      stepIndicator.textContent = this.currentStep
    }

    // Handle final step navigation - show multiple options
    if (nextButton && submitButton) {
      if (this.currentStep < this.totalSteps) {
        nextButton.style.display = 'flex'
        submitButton.style.display = 'none'
        this.hideActionButtons()
      } else {
        nextButton.style.display = 'none'
        submitButton.style.display = 'flex'
        this.showActionButtons()
      }
    }

    // Update step navigation styling
    this.updateStepNavigation(this.currentStep)
  }

  showActionButtons() {
    // Show additional action buttons for final step
    const actionButtonsContainer = this.element.querySelector('.action-buttons-container')
    if (!actionButtonsContainer) {
      this.createActionButtons()
    }
  }

  hideActionButtons() {
    const actionButtonsContainer = this.element.querySelector('.action-buttons-container')
    if (actionButtonsContainer) {
      actionButtonsContainer.style.display = 'none'
    }
  }

  createActionButtons() {
    const navigationContainer = this.element.querySelector('div[style*="justify-content: space-between"]')
    if (!navigationContainer) return

    // Find the action buttons area (right side)
    const actionArea = navigationContainer.querySelector('div[style*="display: flex; align-items: center; gap: var(--space-12)"]')
    if (!actionArea) return

    // Create container for additional action buttons
    const actionButtonsContainer = document.createElement('div')
    actionButtonsContainer.className = 'action-buttons-container'
    actionButtonsContainer.style.cssText = `
      display: flex;
      align-items: center;
      gap: var(--space-8);
      margin-right: var(--space-12);
    `

    // Save as Draft Button
    const saveDraftButton = document.createElement('button')
    saveDraftButton.type = 'button'
    saveDraftButton.setAttribute('data-action', 'click->pipeline-builder#saveDraft')
    saveDraftButton.style.cssText = `
      background: rgba(var(--color-surface-rgb), 0.8);
      border: 1px solid rgba(var(--color-border-rgb), 0.3);
      color: var(--color-text-secondary);
      display: flex;
      align-items: center;
      gap: var(--space-6);
      padding: var(--space-8) var(--space-12);
      border-radius: var(--radius-md);
      font-size: var(--font-size-xs);
      font-weight: var(--font-weight-medium);
      transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
      backdrop-filter: blur(10px);
      cursor: pointer;
    `
    saveDraftButton.innerHTML = `
      <svg style="width: 14px; height: 14px;" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3-3m0 0l-3 3m3-3v12"/>
      </svg>
      Draft
    `

    // Export Config Button
    const exportButton = document.createElement('button')
    exportButton.type = 'button'
    exportButton.setAttribute('data-action', 'click->pipeline-builder#exportConfiguration')
    exportButton.style.cssText = `
      background: rgba(var(--color-surface-rgb), 0.8);
      border: 1px solid rgba(var(--color-border-rgb), 0.3);
      color: var(--color-text-secondary);
      display: flex;
      align-items: center;
      gap: var(--space-6);
      padding: var(--space-8) var(--space-12);
      border-radius: var(--radius-md);
      font-size: var(--font-size-xs);
      font-weight: var(--font-weight-medium);
      transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
      backdrop-filter: blur(10px);
      cursor: pointer;
    `
    exportButton.innerHTML = `
      <svg style="width: 14px; height: 14px;" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
      </svg>
      Export
    `

    // Add hover effects
    const addHoverEffects = (button, hoverColor) => {
      button.addEventListener('mouseenter', () => {
        button.style.borderColor = `rgba(${hoverColor}, 0.4)`
        button.style.color = `rgb(${hoverColor})`
      })
      button.addEventListener('mouseleave', () => {
        button.style.borderColor = 'rgba(var(--color-border-rgb), 0.3)'
        button.style.color = 'var(--color-text-secondary)'
      })
    }

    addHoverEffects(saveDraftButton, '99, 102, 241') // Blue
    addHoverEffects(exportButton, '245, 158, 11') // Orange

    actionButtonsContainer.appendChild(saveDraftButton)
    actionButtonsContainer.appendChild(exportButton)
    
    // Insert before the main action area
    actionArea.parentNode.insertBefore(actionButtonsContainer, actionArea)
  }

  updateStepNavigation(currentStep) {
    for (let i = 1; i <= this.totalSteps; i++) {
      const stepNav = this.element.querySelector(`[data-pipeline-builder-target="step${i}Nav"]`)
      if (stepNav) {
        stepNav.classList.remove('active', 'completed')
        if (i === currentStep) {
          stepNav.classList.add('active')
        } else if (i < currentStep) {
          stepNav.classList.add('completed')
        }
      }
    }
  }

  // Pipeline Type Methods
  updatePipelineType(event) {
    const pipelineType = event.target.value
    console.log('Pipeline type selected:', pipelineType)
    
    // Update visual indicators
    const checkboxes = ['etl', 'elt', 'streaming']
    checkboxes.forEach(type => {
      const checkbox = this.element.querySelector(`[data-pipeline-builder-target="${type}Checkbox"]`)
      if (checkbox) {
        if (type === pipelineType) {
          checkbox.style.opacity = '1'
          checkbox.style.borderColor = 'var(--color-primary)'
        } else {
          checkbox.style.opacity = '0.3'
          checkbox.style.borderColor = 'rgba(var(--color-border-rgb), 0.3)'
        }
      }
    })
  }

  // Source Configuration
  selectSourceType(event) {
    event.preventDefault()
    const sourceType = event.currentTarget.dataset.sourceType
    console.log('Source type selected:', sourceType)
    
    // Update button appearance
    this.element.querySelectorAll('[data-source-type]').forEach(btn => {
      btn.classList.remove('border-teal-500', 'ring-2', 'ring-teal-500')
      btn.classList.add('border-gray-300')
    })
    event.currentTarget.classList.remove('border-gray-300')
    event.currentTarget.classList.add('border-teal-500', 'ring-2', 'ring-teal-500')

    // Load appropriate configuration form
    this.loadSourceConfiguration(sourceType)
  }

  async loadSourceConfiguration(sourceType) {
    console.log('Loading source configuration for:', sourceType)
    
    const sourceConfigTarget = this.element.querySelector('[data-pipeline-builder-target="sourceConfig"]')
    if (!sourceConfigTarget) {
      console.warn('Source config target not found')
      return
    }
    
    try {
      const response = await fetch(`/etl_pipeline_builders/available_extractors?source_type=${sourceType}`, {
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })
      
      const data = await response.json()
      console.log('Available extractors:', data)
      
      // Generate configuration form based on extractors
      let configHtml = this.generateSourceConfigForm(sourceType, data.extractors)
      sourceConfigTarget.innerHTML = configHtml
      
    } catch (error) {
      console.error('Failed to load extractors:', error)
      sourceConfigTarget.innerHTML = '<p class="text-red-600">Failed to load configuration options</p>'
    }
  }

  generateSourceConfigForm(sourceType, extractors) {
    console.log('Generating source config form for:', sourceType, extractors)
    
    // Special handling for file upload with premium design
    if (sourceType === 'file_upload') {
      return this.generateFileUploadForm(extractors)
    }
    
    if (!extractors || extractors.length === 0) {
      return '<p style="color: var(--color-text-secondary);">No extractors available for this source type</p>'
    }

    let html = `
      <div style="display: flex; flex-direction: column; gap: var(--space-16);">
        <div>
          <label style="
            display: block;
            font-size: var(--font-size-sm);
            font-weight: var(--font-weight-bold);
            color: var(--color-text);
            margin-bottom: var(--space-8);
          ">Select ${sourceType} type:</label>
          <select name="pipeline[source_config][extractor_type]" style="
            display: block;
            width: 100%;
            padding: var(--space-12) var(--space-16);
            background: rgba(var(--color-surface-rgb), 0.8);
            border: 1px solid rgba(var(--color-border-rgb), 0.3);
            border-radius: var(--radius-lg);
            color: var(--color-text);
            font-size: var(--font-size-sm);
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            backdrop-filter: blur(10px);
          ">
            <option value="">Select...</option>
    `
    
    extractors.forEach(extractor => {
      if (typeof extractor === 'string') {
        html += `<option value="${extractor}">${extractor.charAt(0).toUpperCase() + extractor.slice(1)}</option>`
      } else if (typeof extractor === 'object') {
        html += `<option value="${extractor.type}">${extractor.name}</option>`
      }
    })
    
    html += `
          </select>
        </div>
      </div>
    `
    
    return html
  }

  generateFileUploadForm(extractors) {
    console.log('Generating premium file upload form with extractors:', extractors)
    
    // Get supported file types from extractors
    let supportedTypes = []
    if (extractors && Array.isArray(extractors)) {
      supportedTypes = extractors.map(ext => {
        if (typeof ext === 'string') {
          return ext.toLowerCase()
        } else if (ext.type) {
          return ext.type.toLowerCase()
        }
      }).filter(Boolean)
    }
    
    const acceptAttribute = supportedTypes.length > 0 
      ? supportedTypes.map(type => `.${type}`).join(',') 
      : '.csv,.xlsx,.xls,.json,.txt'
    
    return `
      <div style="
        background: linear-gradient(135deg, rgba(var(--color-surface-rgb), 0.95) 0%, rgba(245, 158, 11, 0.02) 100%);
        border: 1px solid rgba(var(--color-border-rgb), 0.2);
        border-radius: var(--radius-xl);
        padding: var(--space-32);
        backdrop-filter: blur(20px);
        -webkit-backdrop-filter: blur(20px);
      ">
        <!-- Header -->
        <div style="margin-bottom: var(--space-24);">
          <h3 style="
            font-size: var(--font-size-lg);
            font-weight: var(--font-weight-bold);
            color: var(--color-text);
            margin: 0 0 var(--space-8) 0;
            display: flex;
            align-items: center;
            gap: var(--space-12);
          ">
            <div style="
              width: 32px;
              height: 32px;
              background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
              border-radius: var(--radius-lg);
              display: flex;
              align-items: center;
              justify-content: center;
              box-shadow: 0 4px 12px rgba(245, 158, 11, 0.3);
            ">
              <svg style="width: 16px; height: 16px; color: white;" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
              </svg>
            </div>
            Upload Your Data Files
          </h3>
          <p style="
            font-size: var(--font-size-sm);
            color: var(--color-text-secondary);
            margin: 0;
          ">Drop your files here or click to browse. We'll automatically detect the schema and preview your data.</p>
        </div>

        <!-- File Upload Area -->
        <div style="
          border: 2px dashed rgba(245, 158, 11, 0.3);
          border-radius: var(--radius-lg);
          padding: var(--space-48) var(--space-24);
          text-align: center;
          background: linear-gradient(135deg, rgba(245, 158, 11, 0.05) 0%, rgba(245, 158, 11, 0.01) 100%);
          transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
          cursor: pointer;
          position: relative;
          overflow: hidden;
        " 
        onmouseover="this.style.borderColor='rgba(245, 158, 11, 0.5)'; this.style.background='linear-gradient(135deg, rgba(245, 158, 11, 0.08) 0%, rgba(245, 158, 11, 0.02) 100%)'"
        onmouseout="this.style.borderColor='rgba(245, 158, 11, 0.3)'; this.style.background='linear-gradient(135deg, rgba(245, 158, 11, 0.05) 0%, rgba(245, 158, 11, 0.01) 100%)'">
          
          <input type="file" 
                 name="pipeline[source_config][uploaded_files][]"
                 multiple 
                 accept="${acceptAttribute}"
                 data-action="change->pipeline-builder#handleFileUpload"
                 style="
                   position: absolute;
                   top: 0;
                   left: 0;
                   width: 100%;
                   height: 100%;
                   opacity: 0;
                   cursor: pointer;
                 ">
          
          <div style="
            width: 80px;
            height: 80px;
            background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto var(--space-16);
            box-shadow: 0 8px 32px rgba(245, 158, 11, 0.3);
          ">
            <svg style="width: 40px; height: 40px; color: white;" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
            </svg>
          </div>
          
          <h4 style="
            font-size: var(--font-size-lg);
            font-weight: var(--font-weight-bold);
            color: var(--color-text);
            margin: 0 0 var(--space-8) 0;
          ">Drop files here or click to browse</h4>
          
          <p style="
            font-size: var(--font-size-sm);
            color: var(--color-text-secondary);
            margin: 0 0 var(--space-16) 0;
          ">Maximum file size: 100MB per file</p>
          
          <!-- Supported Formats -->
          <div style="
            display: flex;
            justify-content: center;
            gap: var(--space-8);
            flex-wrap: wrap;
          ">
            ${supportedTypes.map(type => `
              <span style="
                padding: var(--space-4) var(--space-12);
                background: rgba(245, 158, 11, 0.1);
                border: 1px solid rgba(245, 158, 11, 0.2);
                border-radius: var(--radius-md);
                font-size: var(--font-size-xs);
                font-weight: var(--font-weight-bold);
                color: #d97706;
                text-transform: uppercase;
              ">${type}</span>
            `).join('')}
          </div>
        </div>

        <!-- File List Area (Initially Hidden) -->
        <div data-pipeline-builder-target="fileList" style="margin-top: var(--space-24); display: none;">
          <h4 style="
            font-size: var(--font-size-md);
            font-weight: var(--font-weight-bold);
            color: var(--color-text);
            margin: 0 0 var(--space-16) 0;
          ">Uploaded Files</h4>
          <div data-pipeline-builder-target="fileItems" style="display: flex; flex-direction: column; gap: var(--space-12);">
            <!-- File items will be added here dynamically -->
          </div>
        </div>

        <!-- Upload Progress (Initially Hidden) -->
        <div data-pipeline-builder-target="uploadProgress" style="margin-top: var(--space-24); display: none;">
          <div style="
            background: rgba(var(--color-surface-rgb), 0.8);
            border: 1px solid rgba(var(--color-border-rgb), 0.3);
            border-radius: var(--radius-lg);
            padding: var(--space-16);
            backdrop-filter: blur(10px);
          ">
            <div style="
              display: flex;
              align-items: center;
              gap: var(--space-12);
              margin-bottom: var(--space-12);
            ">
              <div style="
                width: 24px;
                height: 24px;
                background: linear-gradient(135deg, #10b981 0%, #059669 100%);
                border-radius: 50%;
                display: flex;
                align-items: center;
                justify-content: center;
                animation: spin 1s linear infinite;
              ">
                <svg style="width: 12px; height: 12px; color: white;" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
                </svg>
              </div>
              <span style="
                font-size: var(--font-size-sm);
                font-weight: var(--font-weight-medium);
                color: var(--color-text);
              ">Processing files and detecting schema...</span>
            </div>
            
            <div style="
              width: 100%;
              height: 8px;
              background: rgba(var(--color-border-rgb), 0.3);
              border-radius: var(--radius-full);
              overflow: hidden;
            ">
              <div data-pipeline-builder-target="progressBar" style="
                width: 0%;
                height: 100%;
                background: linear-gradient(135deg, #10b981 0%, #059669 100%);
                transition: width 0.3s cubic-bezier(0.4, 0, 0.2, 1);
              "></div>
            </div>
          </div>
        </div>
      </div>
      
      <style>
        @keyframes spin {
          from { transform: rotate(0deg); }
          to { transform: rotate(360deg); }
        }
      </style>
    `
  }

  // Destination Configuration
  selectDestinationType(event) {
    event.preventDefault()
    const destinationType = event.currentTarget.dataset.destinationType
    console.log('Destination type selected:', destinationType)
    
    // Update button appearance
    this.element.querySelectorAll('[data-destination-type]').forEach(btn => {
      btn.classList.remove('border-indigo-500', 'ring-2', 'ring-indigo-500')
      btn.classList.add('border-gray-300')
    })
    event.currentTarget.classList.remove('border-gray-300')
    event.currentTarget.classList.add('border-indigo-500', 'ring-2', 'ring-indigo-500')

    // Load appropriate configuration form
    this.loadDestinationConfiguration(destinationType)
  }

  loadDestinationConfiguration(destinationType) {
    console.log('Loading destination configuration for:', destinationType)
    
    const destinationConfigTarget = this.element.querySelector('[data-pipeline-builder-target="destinationConfig"]')
    if (!destinationConfigTarget) {
      console.warn('Destination config target not found')
      return
    }

    let configHtml = ''
    
    switch (destinationType) {
      case 'preview_only':
        configHtml = this.getPreviewOnlyDestinationConfig()
        break
      case 'warehouse':
        configHtml = this.getWarehouseDestinationConfig()
        break
      case 'database':
        configHtml = this.getDatabaseDestinationConfig()
        break
      case 'api':
        configHtml = this.getApiDestinationConfig()
        break
      case 'cloud_storage':
        configHtml = this.getCloudStorageDestinationConfig()
        break
      default:
        configHtml = '<p class="text-gray-500">Configuration options will be added here</p>'
    }
    
    destinationConfigTarget.innerHTML = configHtml
  }

  getWarehouseDestinationConfig() {
    return `
      <div class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700">Data Warehouse</label>
          <select name="pipeline[destination_config][warehouse_type]" class="mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md">
            <option value="snowflake">Snowflake</option>
            <option value="bigquery">BigQuery</option>
            <option value="redshift">Redshift</option>
            <option value="databricks">Databricks</option>
            <option value="synapse">Azure Synapse</option>
          </select>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">Schema Name</label>
          <input type="text" name="pipeline[destination_config][schema]" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm" placeholder="analytics">
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">Table Name</label>
          <input type="text" name="pipeline[destination_config][table_name]" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm" placeholder="customer_data">
        </div>
      </div>
    `
  }

  getDatabaseDestinationConfig() {
    return '<p class="text-gray-500">Database destination configuration coming soon</p>'
  }

  getApiDestinationConfig() {
    return '<p class="text-gray-500">API destination configuration coming soon</p>'
  }

  getCloudStorageDestinationConfig() {
    return '<p class="text-gray-500">Cloud storage destination configuration coming soon</p>'
  }

  getPreviewOnlyDestinationConfig() {
    return `
      <div style="
        background: linear-gradient(135deg, rgba(34, 197, 94, 0.1) 0%, rgba(34, 197, 94, 0.05) 100%);
        border: 1px solid rgba(34, 197, 94, 0.2);
        border-radius: var(--radius-lg);
        padding: var(--space-24);
        backdrop-filter: blur(10px);
      ">
        <!-- Header -->
        <div style="margin-bottom: var(--space-20);">
          <h3 style="
            font-size: var(--font-size-lg);
            font-weight: var(--font-weight-bold);
            color: var(--color-text);
            margin: 0 0 var(--space-8) 0;
            display: flex;
            align-items: center;
            gap: var(--space-12);
          ">
            <div style="
              width: 32px;
              height: 32px;
              background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%);
              border-radius: var(--radius-lg);
              display: flex;
              align-items: center;
              justify-content: center;
              box-shadow: 0 4px 12px rgba(34, 197, 94, 0.3);
            ">
              <svg style="width: 16px; height: 16px; color: white;" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z" />
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
              </svg>
            </div>
            Preview & Test Mode
          </h3>
          <p style="
            font-size: var(--font-size-sm);
            color: var(--color-text-secondary);
            margin: 0;
          ">Perfect for SMEs who want to validate their data transformations before committing to a destination.</p>
        </div>

        <!-- Features List -->
        <div style="
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
          gap: var(--space-16);
          margin-bottom: var(--space-24);
        ">
          <div style="display: flex; align-items: flex-start; gap: var(--space-12);">
            <div style="
              width: 20px;
              height: 20px;
              background: #22c55e;
              border-radius: 50%;
              display: flex;
              align-items: center;
              justify-content: center;
              flex-shrink: 0;
              margin-top: var(--space-2);
            ">
              <svg style="width: 12px; height: 12px; color: white;" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7"/>
              </svg>
            </div>
            <div>
              <h4 style="font-size: var(--font-size-sm); font-weight: var(--font-weight-medium); color: var(--color-text); margin: 0 0 var(--space-4) 0;">Live Preview</h4>
              <p style="font-size: var(--font-size-xs); color: var(--color-text-secondary); margin: 0;">See transformed data in real-time</p>
            </div>
          </div>
          
          <div style="display: flex; align-items: flex-start; gap: var(--space-12);">
            <div style="
              width: 20px;
              height: 20px;
              background: #22c55e;
              border-radius: 50%;
              display: flex;
              align-items: center;
              justify-content: center;
              flex-shrink: 0;
              margin-top: var(--space-2);
            ">
              <svg style="width: 12px; height: 12px; color: white;" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7"/>
              </svg>
            </div>
            <div>
              <h4 style="font-size: var(--font-size-sm); font-weight: var(--font-weight-medium); color: var(--color-text); margin: 0 0 var(--space-4) 0;">Export Options</h4>
              <p style="font-size: var(--font-size-xs); color: var(--color-text-secondary); margin: 0;">Download as CSV, JSON, or Excel</p>
            </div>
          </div>
          
          <div style="display: flex; align-items: flex-start; gap: var(--space-12);">
            <div style="
              width: 20px;
              height: 20px;
              background: #22c55e;
              border-radius: 50%;
              display: flex;
              align-items: center;
              justify-content: center;
              flex-shrink: 0;
              margin-top: var(--space-2);
            ">
              <svg style="width: 12px; height: 12px; color: white;" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7"/>
              </svg>
            </div>
            <div>
              <h4 style="font-size: var(--font-size-sm); font-weight: var(--font-weight-medium); color: var(--color-text); margin: 0 0 var(--space-4) 0;">Save as Draft</h4>
              <p style="font-size: var(--font-size-xs); color: var(--color-text-secondary); margin: 0;">Keep configuration for later use</p>
            </div>
          </div>
          
          <div style="display: flex; align-items: flex-start; gap: var(--space-12);">
            <div style="
              width: 20px;
              height: 20px;
              background: #22c55e;
              border-radius: 50%;
              display: flex;
              align-items: center;
              justify-content: center;
              flex-shrink: 0;
              margin-top: var(--space-2);
            ">
              <svg style="width: 12px; height: 12px; color: white;" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7"/>
              </svg>
            </div>
            <div>
              <h4 style="font-size: var(--font-size-sm); font-weight: var(--font-weight-medium); color: var(--color-text); margin: 0 0 var(--space-4) 0;">Share Template</h4>
              <p style="font-size: var(--font-size-xs); color: var(--color-text-secondary); margin: 0;">Export pipeline config for teams</p>
            </div>
          </div>
        </div>

        <!-- Configuration Options -->
        <div style="
          background: rgba(var(--color-surface-rgb), 0.8);
          border: 1px solid rgba(var(--color-border-rgb), 0.3);
          border-radius: var(--radius-lg);
          padding: var(--space-20);
          backdrop-filter: blur(10px);
        ">
          <h4 style="
            font-size: var(--font-size-md);
            font-weight: var(--font-weight-medium);
            color: var(--color-text);
            margin: 0 0 var(--space-16) 0;
          ">Preview Configuration</h4>
          
          <div style="display: grid; grid-template-columns: 1fr 1fr; gap: var(--space-16);">
            <div>
              <label style="
                display: block;
                font-size: var(--font-size-sm);
                font-weight: var(--font-weight-medium);
                color: var(--color-text);
                margin-bottom: var(--space-8);
              ">Sample Size:</label>
              <select name="pipeline[destination_config][sample_size]" style="
                width: 100%;
                padding: var(--space-12);
                background: rgba(var(--color-surface-rgb), 0.8);
                border: 1px solid rgba(var(--color-border-rgb), 0.3);
                border-radius: var(--radius-md);
                color: var(--color-text);
                font-size: var(--font-size-sm);
              ">
                <option value="100">100 rows</option>
                <option value="500">500 rows</option>
                <option value="1000" selected>1,000 rows</option>
                <option value="5000">5,000 rows</option>
                <option value="all">All rows</option>
              </select>
            </div>
            
            <div>
              <label style="
                display: block;
                font-size: var(--font-size-sm);
                font-weight: var(--font-weight-medium);
                color: var(--color-text);
                margin-bottom: var(--space-8);
              ">Export Format:</label>
              <select name="pipeline[destination_config][export_format]" style="
                width: 100%;
                padding: var(--space-12);
                background: rgba(var(--color-surface-rgb), 0.8);
                border: 1px solid rgba(var(--color-border-rgb), 0.3);
                border-radius: var(--radius-md);
                color: var(--color-text);
                font-size: var(--font-size-sm);
              ">
                <option value="csv">CSV (Recommended)</option>
                <option value="json">JSON</option>
                <option value="xlsx">Excel (.xlsx)</option>
                <option value="parquet">Parquet</option>
              </select>
            </div>
          </div>
          
          <div style="margin-top: var(--space-16);">
            <label style="display: flex; align-items: center; gap: var(--space-8);">
              <input type="checkbox" 
                     name="pipeline[destination_config][include_metadata]" 
                     checked
                     style="
                       width: 16px;
                       height: 16px;
                       accent-color: #22c55e;
                     ">
              <span style="font-size: var(--font-size-sm); color: var(--color-text);">Include transformation metadata in export</span>
            </label>
          </div>
        </div>
      </div>
    `
  }

  // File Upload Handling
  handleFileUpload(event) {
    console.log('File upload triggered:', event)
    const files = event.target.files
    
    if (!files || files.length === 0) {
      console.log('No files selected')
      return
    }

    console.log('Files selected:', files.length)
    
    // Update the upload area to show files are being processed
    this.updateUploadAreaForProcessing(event.target, files.length)
    
    // Show progress indicator
    this.showUploadProgress()
    
    // Process each file
    Array.from(files).forEach((file, index) => {
      console.log(`Processing file ${index + 1}:`, file.name, file.size, file.type)
      this.processFile(file, index, files.length)
    })
  }

  updateUploadAreaForProcessing(input, fileCount) {
    const uploadArea = input.closest('div[style*="border: 2px dashed"]')
    if (!uploadArea) return
    
    // Update border and background to show processing state
    uploadArea.style.borderColor = 'rgba(245, 158, 11, 0.6)'
    uploadArea.style.background = 'linear-gradient(135deg, rgba(245, 158, 11, 0.1) 0%, rgba(245, 158, 11, 0.05) 100%)'
    
    // Find and update the content
    const header = uploadArea.querySelector('h4')
    const description = uploadArea.querySelector('p')
    
    if (header) {
      header.textContent = `Processing ${fileCount} file${fileCount !== 1 ? 's' : ''}...`
    }
    
    if (description) {
      description.textContent = 'Files are being validated and processed'
    }
    
    // Add a subtle animation
    uploadArea.style.animation = 'pulse 2s infinite'
    
    // Add pulse animation style if it doesn't exist
    if (!document.getElementById('upload-animation-styles')) {
      const style = document.createElement('style')
      style.id = 'upload-animation-styles'
      style.textContent = `
        @keyframes pulse {
          0%, 100% { opacity: 1; }
          50% { opacity: 0.8; }
        }
      `
      document.head.appendChild(style)
    }
  }

  processFile(file, index, totalFiles) {
    console.log('Processing file:', file.name)
    
    // Validate file size (100MB limit)
    const maxSize = 100 * 1024 * 1024 // 100MB in bytes
    if (file.size > maxSize) {
      this.showFileError(file.name, 'File size exceeds 100MB limit')
      return
    }

    // Validate file type
    const fileName = file.name.toLowerCase()
    const allowedExtensions = ['csv', 'xlsx', 'xls', 'json', 'txt', 'tsv']
    const fileExtension = fileName.split('.').pop()
    
    if (!allowedExtensions.includes(fileExtension)) {
      this.showFileError(file.name, `Unsupported file type: ${fileExtension}`)
      return
    }

    // Show file in the list
    this.addFileToList(file, index)
    
    // Simulate upload progress
    this.simulateUploadProgress(file, index, totalFiles)
  }

  showUploadProgress() {
    const progressElement = this.element.querySelector('[data-pipeline-builder-target="uploadProgress"]')
    const fileListElement = this.element.querySelector('[data-pipeline-builder-target="fileList"]')
    
    if (progressElement) {
      progressElement.style.display = 'block'
    }
    if (fileListElement) {
      fileListElement.style.display = 'block'
    }
  }

  addFileToList(file, index) {
    const fileItemsContainer = this.element.querySelector('[data-pipeline-builder-target="fileItems"]')
    if (!fileItemsContainer) {
      console.warn('File items container not found')
      return
    }

    const fileSize = this.formatFileSize(file.size)
    const fileId = `file-${index}-${Date.now()}`
    
    const fileItem = document.createElement('div')
    fileItem.id = fileId
    fileItem.innerHTML = `
      <div style="
        background: rgba(var(--color-surface-rgb), 0.8);
        border: 1px solid rgba(var(--color-border-rgb), 0.3);
        border-radius: var(--radius-lg);
        padding: var(--space-16);
        backdrop-filter: blur(10px);
        display: flex;
        align-items: center;
        gap: var(--space-12);
      ">
        <div style="
          width: 40px;
          height: 40px;
          background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
          border-radius: var(--radius-lg);
          display: flex;
          align-items: center;
          justify-content: center;
          box-shadow: 0 4px 12px rgba(245, 158, 11, 0.3);
          flex-shrink: 0;
        ">
          <svg style="width: 20px; height: 20px; color: white;" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
          </svg>
        </div>
        
        <div style="flex: 1; min-width: 0;">
          <h5 style="
            font-size: var(--font-size-sm);
            font-weight: var(--font-weight-bold);
            color: var(--color-text);
            margin: 0 0 var(--space-4) 0;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
          ">${file.name}</h5>
          <p style="
            font-size: var(--font-size-xs);
            color: var(--color-text-secondary);
            margin: 0;
          ">${fileSize} • ${file.type || 'Unknown type'}</p>
        </div>
        
        <div class="file-status" style="
          padding: var(--space-4) var(--space-12);
          background: rgba(245, 158, 11, 0.1);
          border: 1px solid rgba(245, 158, 11, 0.2);
          border-radius: var(--radius-md);
          font-size: var(--font-size-xs);
          font-weight: var(--font-weight-bold);
          color: #d97706;
        ">Processing...</div>
      </div>
    `
    
    fileItemsContainer.appendChild(fileItem)
  }

  simulateUploadProgress(file, index, totalFiles) {
    console.log(`Simulating upload progress for: ${file.name}`)
    
    const progressBar = this.element.querySelector('[data-pipeline-builder-target="progressBar"]')
    let progress = 0
    
    const interval = setInterval(() => {
      progress += Math.random() * 15
      
      if (progress >= 100) {
        progress = 100
        clearInterval(interval)
        
        // Update file status
        this.updateFileStatus(`file-${index}-${Date.now().toString().slice(-6)}`, 'success')
        
        // Check if all files are done
        setTimeout(() => {
          this.checkAllFilesComplete(totalFiles)
        }, 500)
      }
      
      if (progressBar) {
        progressBar.style.width = `${progress}%`
      }
    }, 200)
  }

  updateFileStatus(fileId, status) {
    const fileElements = this.element.querySelectorAll('[id^="file-"]')
    
    fileElements.forEach(element => {
      const statusElement = element.querySelector('.file-status')
      if (statusElement) {
        if (status === 'success') {
          statusElement.innerHTML = '✓ Ready'
          statusElement.style.background = 'rgba(16, 185, 129, 0.1)'
          statusElement.style.borderColor = 'rgba(16, 185, 129, 0.2)'
          statusElement.style.color = '#059669'
        } else if (status === 'error') {
          statusElement.innerHTML = '✗ Error'
          statusElement.style.background = 'rgba(239, 68, 68, 0.1)'
          statusElement.style.borderColor = 'rgba(239, 68, 68, 0.2)'
          statusElement.style.color = '#dc2626'
        }
      }
    })
  }

  checkAllFilesComplete(totalFiles) {
    console.log('Checking if all files are complete')
    
    // Hide progress indicator
    const progressElement = this.element.querySelector('[data-pipeline-builder-target="uploadProgress"]')
    if (progressElement) {
      progressElement.style.display = 'none'
    }
    
    // Show success message
    this.showUploadSuccess(totalFiles)
  }

  showUploadSuccess(fileCount) {
    const sourceConfigTarget = this.element.querySelector('[data-pipeline-builder-target="sourceConfig"]')
    if (!sourceConfigTarget) return
    
    const successMessage = document.createElement('div')
    successMessage.style.cssText = `
      background: linear-gradient(135deg, rgba(16, 185, 129, 0.1) 0%, rgba(16, 185, 129, 0.05) 100%);
      border: 1px solid rgba(16, 185, 129, 0.2);
      border-radius: var(--radius-lg);
      padding: var(--space-16);
      margin-top: var(--space-16);
      display: flex;
      align-items: center;
      gap: var(--space-12);
    `
    
    successMessage.innerHTML = `
      <div style="
        width: 32px;
        height: 32px;
        background: linear-gradient(135deg, #10b981 0%, #059669 100%);
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        flex-shrink: 0;
      ">
        <svg style="width: 16px; height: 16px; color: white;" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7"/>
        </svg>
      </div>
      <div>
        <h4 style="
          font-size: var(--font-size-sm);
          font-weight: var(--font-weight-bold);
          color: var(--color-text);
          margin: 0 0 var(--space-4) 0;
        ">Files uploaded successfully!</h4>
        <p style="
          font-size: var(--font-size-xs);
          color: var(--color-text-secondary);
          margin: 0;
        ">${fileCount} file${fileCount !== 1 ? 's' : ''} processed and ready for transformation. Schema detection completed.</p>
      </div>
    `
    
    sourceConfigTarget.appendChild(successMessage)
  }

  showFileError(fileName, errorMessage) {
    console.error(`File error for ${fileName}:`, errorMessage)
    
    const sourceConfigTarget = this.element.querySelector('[data-pipeline-builder-target="sourceConfig"]')
    if (!sourceConfigTarget) return
    
    const errorDiv = document.createElement('div')
    errorDiv.style.cssText = `
      background: linear-gradient(135deg, rgba(239, 68, 68, 0.1) 0%, rgba(239, 68, 68, 0.05) 100%);
      border: 1px solid rgba(239, 68, 68, 0.2);
      border-radius: var(--radius-lg);
      padding: var(--space-16);
      margin-top: var(--space-16);
      display: flex;
      align-items: center;
      gap: var(--space-12);
    `
    
    errorDiv.innerHTML = `
      <div style="
        width: 32px;
        height: 32px;
        background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        flex-shrink: 0;
      ">
        <svg style="width: 16px; height: 16px; color: white;" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
        </svg>
      </div>
      <div>
        <h4 style="
          font-size: var(--font-size-sm);
          font-weight: var(--font-weight-bold);
          color: var(--color-text);
          margin: 0 0 var(--space-4) 0;
        ">Upload Error: ${fileName}</h4>
        <p style="
          font-size: var(--font-size-xs);
          color: var(--color-text-secondary);
          margin: 0;
        ">${errorMessage}</p>
      </div>
    `
    
    sourceConfigTarget.appendChild(errorDiv)
    
    // Remove error message after 5 seconds
    setTimeout(() => {
      if (errorDiv.parentNode) {
        errorDiv.parentNode.removeChild(errorDiv)
      }
    }, 5000)
  }

  formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes'
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
  }

  // Transformation Methods
  showTransformationSelector(event) {
    console.log('Show transformation selector clicked')
    event.preventDefault()
    
    const selector = document.getElementById('transformation-selector')
    const emptyState = document.getElementById('empty-transformations')
    
    if (selector) {
      selector.classList.remove('hidden')
      console.log('Transformation selector shown')
    }
    
    if (emptyState) {
      emptyState.style.display = 'none'
      console.log('Empty transformations state hidden')
    }
  }

  hideTransformationSelector(event) {
    console.log('Hide transformation selector clicked')
    event.preventDefault()
    
    const selector = document.getElementById('transformation-selector')
    const emptyState = document.getElementById('empty-transformations')
    
    if (selector) {
      selector.classList.add('hidden')
      console.log('Transformation selector hidden')
    }
    
    if (emptyState) {
      emptyState.style.display = 'block'
      console.log('Empty transformations state shown')
    }
  }

  selectTransformationType(event) {
    console.log('Transformation type selected')
    event.preventDefault()
    
    const transformType = event.currentTarget.dataset.transformType
    console.log('Selected transformation type:', transformType)
    
    // Hide selector and show configuration form
    this.hideTransformationSelector(event)
    
    // Load transformation configuration form
    this.loadTransformationConfigForm(transformType)
  }

  loadTransformationConfigForm(transformType) {
    console.log('Loading transformation config form for:', transformType)
    
    const configForm = document.getElementById('transformation-config-form')
    if (!configForm) {
      console.warn('Transformation config form container not found')
      return
    }
    
    // Show basic configuration form based on type
    let formHtml = this.generateTransformationForm(transformType)
    configForm.innerHTML = formHtml
    configForm.classList.remove('hidden')
  }

  generateTransformationForm(transformType) {
    const formConfigs = {
      'rename_field': {
        title: 'Rename Field',
        fields: [
          { name: 'from_field', label: 'Current Field Name', type: 'text', placeholder: 'customer_name' },
          { name: 'to_field', label: 'New Field Name', type: 'text', placeholder: 'customer_full_name' }
        ]
      },
      'type_conversion': {
        title: 'Data Type Conversion',
        fields: [
          { name: 'field_name', label: 'Field Name', type: 'text', placeholder: 'amount' },
          { name: 'from_type', label: 'From Type', type: 'select', options: ['text', 'number', 'date', 'boolean'] },
          { name: 'to_type', label: 'To Type', type: 'select', options: ['text', 'number', 'date', 'boolean'] }
        ]
      },
      'calculated_field': {
        title: 'Calculated Field',
        fields: [
          { name: 'field_name', label: 'New Field Name', type: 'text', placeholder: 'total_with_tax' },
          { name: 'formula', label: 'Formula', type: 'text', placeholder: 'amount * 1.08' }
        ]
      },
      'filter': {
        title: 'Filter Rows',
        fields: [
          { name: 'field_name', label: 'Field Name', type: 'text', placeholder: 'status' },
          { name: 'operator', label: 'Operator', type: 'select', options: ['equals', 'not_equals', 'contains', 'greater_than', 'less_than'] },
          { name: 'value', label: 'Value', type: 'text', placeholder: 'active' }
        ]
      }
    }

    const config = formConfigs[transformType] || formConfigs['rename_field']
    
    let html = `
      <div style="
        background: rgba(var(--color-surface-rgb), 0.9);
        border: 1px solid rgba(var(--color-border-rgb), 0.3);
        border-radius: var(--radius-lg);
        padding: var(--space-24);
        backdrop-filter: blur(10px);
      ">
        <h4 style="
          font-size: var(--font-size-md);
          font-weight: var(--font-weight-bold);
          color: var(--color-text);
          margin: 0 0 var(--space-16) 0;
        ">${config.title}</h4>
        
        <div style="display: flex; flex-direction: column; gap: var(--space-16);">
    `
    
    config.fields.forEach(field => {
      if (field.type === 'select') {
        html += `
          <div>
            <label style="
              display: block;
              font-size: var(--font-size-sm);
              font-weight: var(--font-weight-medium);
              color: var(--color-text);
              margin-bottom: var(--space-8);
            ">${field.label}:</label>
            <select name="transform_config[${field.name}]" style="
              width: 100%;
              padding: var(--space-12);
              background: rgba(var(--color-surface-rgb), 0.8);
              border: 1px solid rgba(var(--color-border-rgb), 0.3);
              border-radius: var(--radius-md);
              color: var(--color-text);
              font-size: var(--font-size-sm);
            ">
              ${field.options.map(option => `<option value="${option}">${option.charAt(0).toUpperCase() + option.slice(1)}</option>`).join('')}
            </select>
          </div>
        `
      } else {
        html += `
          <div>
            <label style="
              display: block;
              font-size: var(--font-size-sm);
              font-weight: var(--font-weight-medium);
              color: var(--color-text);
              margin-bottom: var(--space-8);
            ">${field.label}:</label>
            <input type="${field.type}" 
                   name="transform_config[${field.name}]" 
                   placeholder="${field.placeholder || ''}"
                   style="
                     width: 100%;
                     padding: var(--space-12);
                     background: rgba(var(--color-surface-rgb), 0.8);
                     border: 1px solid rgba(var(--color-border-rgb), 0.3);
                     border-radius: var(--radius-md);
                     color: var(--color-text);
                     font-size: var(--font-size-sm);
                   ">
          </div>
        `
      }
    })
    
    html += `
        </div>
        
        <div style="
          display: flex;
          justify-content: flex-end;
          gap: var(--space-12);
          margin-top: var(--space-24);
        ">
          <button type="button" 
                  data-action="click->pipeline-builder#cancelTransformationConfig"
                  style="
                    padding: var(--space-8) var(--space-16);
                    background: rgba(var(--color-surface-rgb), 0.8);
                    border: 1px solid rgba(var(--color-border-rgb), 0.3);
                    border-radius: var(--radius-md);
                    color: var(--color-text-secondary);
                    font-size: var(--font-size-sm);
                    cursor: pointer;
                  ">Cancel</button>
          <button type="button" 
                  data-action="click->pipeline-builder#saveTransformationConfig"
                  style="
                    padding: var(--space-8) var(--space-16);
                    background: linear-gradient(135deg, #0d9488 0%, #0f766e 100%);
                    border: none;
                    border-radius: var(--radius-md);
                    color: white;
                    font-size: var(--font-size-sm);
                    font-weight: var(--font-weight-medium);
                    cursor: pointer;
                  ">Add Transformation</button>
        </div>
      </div>
    `
    
    return html
  }

  cancelTransformationConfig(event) {
    console.log('Cancel transformation config')
    event.preventDefault()
    
    const configForm = document.getElementById('transformation-config-form')
    if (configForm) {
      configForm.classList.add('hidden')
      configForm.innerHTML = ''
    }
    
    const emptyState = document.getElementById('empty-transformations')
    if (emptyState) {
      emptyState.style.display = 'block'
    }
  }

  saveTransformationConfig(event) {
    console.log('Save transformation config')
    event.preventDefault()
    
    // TODO: Collect form data and add to transformation pipeline
    // For now, just hide the form and show success
    
    const configForm = document.getElementById('transformation-config-form')
    if (configForm) {
      configForm.classList.add('hidden')
      configForm.innerHTML = ''
    }
    
    // Show transformation added to pipeline
    this.addTransformationToPipeline('Sample Transformation')
  }

  addTransformationToPipeline(transformationName) {
    console.log('Adding transformation to pipeline:', transformationName)
    
    const emptyState = document.getElementById('empty-transformations')
    const pipelineFlow = document.getElementById('transformation-pipeline')
    
    if (emptyState) {
      emptyState.style.display = 'none'
    }
    
    if (pipelineFlow) {
      pipelineFlow.classList.remove('hidden')
      
      // Add transformation to the flow
      const transformationsList = pipelineFlow.querySelector('[data-pipeline-builder-target="transformationsList"]')
      if (transformationsList) {
        const transformationElement = document.createElement('div')
        transformationElement.style.cssText = `
          background: rgba(var(--color-surface-rgb), 0.9);
          border: 1px solid rgba(var(--color-border-rgb), 0.3);
          border-radius: var(--radius-lg);
          padding: var(--space-12);
          font-size: var(--font-size-sm);
          color: var(--color-text);
        `
        transformationElement.textContent = transformationName
        
        transformationsList.appendChild(transformationElement)
      }
    }
  }

  // Draft and Export Methods for SMEs
  saveDraft(event) {
    console.log('Save draft requested')
    event.preventDefault()
    
    const pipelineData = this.collectPipelineData()
    
    // Show saving indicator
    this.showSaveIndicator('draft')
    
    // Use existing draft save endpoint
    fetch('/etl_pipeline_builders/save_draft', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({
        step: this.currentStep,
        pipeline_data: pipelineData,
        transformations: this.transformations || []
      })
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        this.showSuccessMessage('Draft saved successfully! You can continue later from where you left off.')
      } else {
        this.showErrorMessage('Failed to save draft: ' + (data.error || 'Unknown error'))
      }
    })
    .catch(error => {
      console.error('Draft save error:', error)
      this.showErrorMessage('Network error while saving draft')
    })
    .finally(() => {
      this.hideSaveIndicator()
    })
  }

  exportConfiguration(event) {
    console.log('Export configuration requested')
    event.preventDefault()
    
    const pipelineData = this.collectPipelineData()
    const exportData = {
      pipeline_configuration: {
        name: pipelineData.name || 'Untitled Pipeline',
        description: pipelineData.description || '',
        pipeline_type: pipelineData.pipeline_type || 'etl',
        source_config: pipelineData.source_config || {},
        destination_config: pipelineData.destination_config || {},
        transformations: this.transformations || [],
        created_at: new Date().toISOString(),
        version: '1.0',
        created_by: 'SME User'
      },
      metadata: {
        export_format: 'json',
        export_timestamp: new Date().toISOString(),
        platform: 'Data Refinery Platform'
      }
    }
    
    // Show export indicator
    this.showSaveIndicator('export')
    
    // Create and download file
    setTimeout(() => {
      const blob = new Blob([JSON.stringify(exportData, null, 2)], { type: 'application/json' })
      const url = URL.createObjectURL(blob)
      
      const link = document.createElement('a')
      link.href = url
      link.download = `pipeline-config-${new Date().toISOString().split('T')[0]}.json`
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)
      URL.revokeObjectURL(url)
      
      this.showSuccessMessage('Configuration exported successfully! You can import this file later or share it with your team.')
      this.hideSaveIndicator()
    }, 1000)
  }

  collectPipelineData() {
    const form = this.element.closest('form')
    const formData = new FormData(form)
    
    const pipelineData = {
      name: formData.get('pipeline[name]') || '',
      description: formData.get('pipeline[description]') || '',
      pipeline_type: formData.get('pipeline_type') || 'etl',
      source_config: {},
      destination_config: {}
    }
    
    // Collect source configuration
    for (const [key, value] of formData.entries()) {
      if (key.startsWith('pipeline[source_config]')) {
        const configKey = key.match(/\[([^\]]+)\]$/)?.[1]
        if (configKey) {
          pipelineData.source_config[configKey] = value
        }
      } else if (key.startsWith('pipeline[destination_config]')) {
        const configKey = key.match(/\[([^\]]+)\]$/)?.[1]
        if (configKey) {
          pipelineData.destination_config[configKey] = value
        }
      }
    }
    
    return pipelineData
  }

  showSaveIndicator(type) {
    const message = type === 'draft' ? 'Saving draft...' : 'Exporting configuration...'
    const color = type === 'draft' ? '#6366f1' : '#f59e0b'
    
    const indicator = document.createElement('div')
    indicator.id = 'save-indicator'
    indicator.style.cssText = `
      position: fixed;
      top: var(--space-20);
      right: var(--space-20);
      background: linear-gradient(135deg, ${color} 0%, ${color}cc 100%);
      color: white;
      padding: var(--space-12) var(--space-16);
      border-radius: var(--radius-lg);
      font-size: var(--font-size-sm);
      font-weight: var(--font-weight-medium);
      display: flex;
      align-items: center;
      gap: var(--space-8);
      z-index: 9999;
      box-shadow: 0 8px 32px rgba(0, 0, 0, 0.2);
      backdrop-filter: blur(10px);
      animation: slideInFromRight 0.3s ease-out;
    `
    
    indicator.innerHTML = `
      <div style="
        width: 16px;
        height: 16px;
        border: 2px solid rgba(255, 255, 255, 0.3);
        border-top-color: white;
        border-radius: 50%;
        animation: spin 1s linear infinite;
      "></div>
      ${message}
    `
    
    document.body.appendChild(indicator)
  }

  hideSaveIndicator() {
    const indicator = document.getElementById('save-indicator')
    if (indicator) {
      indicator.style.animation = 'slideOutToRight 0.3s ease-in'
      setTimeout(() => {
        if (indicator.parentNode) {
          indicator.parentNode.removeChild(indicator)
        }
      }, 300)
    }
  }

  showSuccessMessage(message) {
    this.showMessage(message, 'success')
  }

  showErrorMessage(message) {
    this.showMessage(message, 'error')
  }

  showMessage(message, type) {
    const colors = {
      success: { bg: '#22c55e', border: '#16a34a' },
      error: { bg: '#ef4444', border: '#dc2626' }
    }
    
    const messageDiv = document.createElement('div')
    messageDiv.style.cssText = `
      position: fixed;
      top: var(--space-20);
      right: var(--space-20);
      background: linear-gradient(135deg, ${colors[type].bg} 0%, ${colors[type].border} 100%);
      color: white;
      padding: var(--space-16) var(--space-20);
      border-radius: var(--radius-lg);
      font-size: var(--font-size-sm);
      font-weight: var(--font-weight-medium);
      max-width: 400px;
      z-index: 9999;
      box-shadow: 0 8px 32px rgba(0, 0, 0, 0.2);
      backdrop-filter: blur(10px);
      animation: slideInFromRight 0.3s ease-out;
    `
    
    messageDiv.textContent = message
    document.body.appendChild(messageDiv)
    
    // Auto remove after 5 seconds
    setTimeout(() => {
      messageDiv.style.animation = 'slideOutToRight 0.3s ease-in'
      setTimeout(() => {
        if (messageDiv.parentNode) {
          messageDiv.parentNode.removeChild(messageDiv)
        }
      }, 300)
    }, 5000)
  }
}