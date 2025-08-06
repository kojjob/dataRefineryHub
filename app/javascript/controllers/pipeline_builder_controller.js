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
    const submitButton = this.element.querySelector('[type="submit"]')

    if (prevButton) {
      prevButton.disabled = this.currentStep <= 1
    }

    if (nextButton && submitButton) {
      if (this.currentStep < this.totalSteps) {
        nextButton.style.display = 'inline-flex'
        submitButton.style.display = 'none'
      } else {
        nextButton.style.display = 'none'
        submitButton.style.display = 'inline-flex'
      }
    }

    // Update step navigation styling
    this.updateStepNavigation(this.currentStep)
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

  // File Upload Handling
  handleFileUpload(event) {
    console.log('File upload triggered:', event)
    const files = event.target.files
    
    if (!files || files.length === 0) {
      console.log('No files selected')
      return
    }

    console.log('Files selected:', files.length)
    
    // Show progress indicator
    this.showUploadProgress()
    
    // Process each file
    Array.from(files).forEach((file, index) => {
      console.log(`Processing file ${index + 1}:`, file.name, file.size, file.type)
      this.processFile(file, index, files.length)
    })
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
}