import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "step1", "step2", "step3", "step4", "step5",
    "step1Nav", "step2Nav", "step3Nav", "step4Nav", "step5Nav",
    "prevButton", "nextButton", "submitButton",
    "sourceConfig", "destinationConfig",
    "canvas", "transformationsList", "transformationModal", "transformationForm"
  ]

  connect() {
    this.currentStep = 1
    this.transformations = []
    this.updateNavigation()
  }

  // Step Navigation
  nextStep(event) {
    event.preventDefault()
    if (this.validateCurrentStep()) {
      this.currentStep++
      this.showStep(this.currentStep)
      this.updateNavigation()
    }
  }

  previousStep(event) {
    event.preventDefault()
    this.currentStep--
    this.showStep(this.currentStep)
    this.updateNavigation()
  }

  showStep(stepNumber) {
    // Hide all steps
    this.step1Target.classList.add('hidden')
    this.step2Target.classList.add('hidden')
    this.step3Target.classList.add('hidden')
    this.step4Target.classList.add('hidden')
    this.step5Target.classList.add('hidden')

    // Show current step
    const stepTarget = this[`step${stepNumber}Target`]
    stepTarget.classList.remove('hidden')

    // Update step navigation appearance
    this.updateStepNavigation(stepNumber)
  }

  updateStepNavigation(currentStep) {
    const steps = [
      this.step1NavTarget,
      this.step2NavTarget,
      this.step3NavTarget,
      this.step4NavTarget,
      this.step5NavTarget
    ]

    steps.forEach((step, index) => {
      const stepNumber = index + 1
      const circle = step.querySelector('span:first-child')
      const label = step.querySelector('span:last-child')

      if (stepNumber < currentStep) {
        // Completed step
        circle.classList.remove('bg-gray-300', 'text-gray-500')
        circle.classList.add('bg-green-600', 'text-white')
        label.classList.remove('text-gray-500')
        label.classList.add('text-gray-900')
      } else if (stepNumber === currentStep) {
        // Current step
        circle.classList.remove('bg-gray-300', 'text-gray-500')
        circle.classList.add('bg-indigo-600', 'text-white')
        label.classList.remove('text-gray-500')
        label.classList.add('text-gray-900')
      } else {
        // Future step
        circle.classList.remove('bg-indigo-600', 'bg-green-600', 'text-white')
        circle.classList.add('bg-gray-300', 'text-gray-500')
        label.classList.remove('text-gray-900')
        label.classList.add('text-gray-500')
      }
    })
  }

  updateNavigation() {
    // Previous button
    if (this.currentStep === 1) {
      this.prevButtonTarget.disabled = true
    } else {
      this.prevButtonTarget.disabled = false
    }

    // Next/Submit button
    if (this.currentStep === 5) {
      this.nextButtonTarget.classList.add('hidden')
      this.submitButtonTarget.classList.remove('hidden')
    } else {
      this.nextButtonTarget.classList.remove('hidden')
      this.submitButtonTarget.classList.add('hidden')
    }
  }

  validateCurrentStep() {
    // Add validation logic for each step
    switch (this.currentStep) {
      case 1:
        return this.validateBasicInfo()
      case 2:
        return this.validateSource()
      case 3:
        return true // Transformations are optional
      case 4:
        return this.validateDestination()
      case 5:
        return true // Schedule is optional
      default:
        return true
    }
  }

  validateBasicInfo() {
    const name = this.element.querySelector('[name="pipeline_configuration[name]"]').value
    const pipelineType = this.element.querySelector('[name="pipeline_configuration[pipeline_type]"]:checked')
    
    if (!name || !pipelineType) {
      alert('Please fill in all required fields')
      return false
    }
    return true
  }

  validateSource() {
    // Add source validation logic
    return true
  }

  validateDestination() {
    // Add destination validation logic
    return true
  }

  // Pipeline Type Selection
  updatePipelineType(event) {
    const selectedType = event.target.value
    const radioButtons = this.element.querySelectorAll('[name="pipeline_configuration[pipeline_type]"]')
    
    radioButtons.forEach(radio => {
      const label = radio.closest('label')
      const checkmark = label.querySelector('svg')
      const border = label.querySelector('.pointer-events-none')
      
      if (radio.checked) {
        checkmark.classList.remove('hidden')
        border.classList.add('border-indigo-600')
      } else {
        checkmark.classList.add('hidden')
        border.classList.remove('border-indigo-600')
      }
    })

    // Update transformation step visibility based on type
    if (selectedType === 'elt') {
      // Show different transformation options for ELT
      this.updateTransformationOptions('elt')
    } else {
      this.updateTransformationOptions('etl')
    }
  }

  // Source Configuration
  selectSourceType(event) {
    event.preventDefault()
    const sourceType = event.currentTarget.dataset.sourceType
    
    // Update button appearance
    this.element.querySelectorAll('[data-source-type]').forEach(btn => {
      btn.classList.remove('border-indigo-500', 'ring-2', 'ring-indigo-500')
      btn.classList.add('border-gray-300')
    })
    event.currentTarget.classList.remove('border-gray-300')
    event.currentTarget.classList.add('border-indigo-500', 'ring-2', 'ring-indigo-500')

    // Load appropriate configuration form
    this.loadSourceConfiguration(sourceType)
  }

  async loadSourceConfiguration(sourceType) {
    // In a real implementation, this would fetch the configuration form from the server
    let configHtml = ''
    
    switch (sourceType) {
      case 'database':
        configHtml = this.getDatabaseSourceConfig()
        break
      case 'api':
        configHtml = this.getApiSourceConfig()
        break
      case 'cloud_storage':
        configHtml = this.getCloudStorageSourceConfig()
        break
      case 'streaming':
        configHtml = this.getStreamingSourceConfig()
        break
    }
    
    this.sourceConfigTarget.innerHTML = configHtml
  }

  getDatabaseSourceConfig() {
    return `
      <div class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700">Select Data Source</label>
          <select name="pipeline_configuration[source_config][data_source_id]" class="mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md">
            <option value="">Choose a database...</option>
            ${this.element.dataset.dataSources ? JSON.parse(this.element.dataset.dataSources).map(ds => 
              `<option value="${ds.id}">${ds.name} (${ds.source_type})</option>`
            ).join('') : ''}
          </select>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">Query</label>
          <textarea name="pipeline_configuration[source_config][query]" rows="4" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm" placeholder="SELECT * FROM users WHERE created_at > :last_sync"></textarea>
        </div>
      </div>
    `
  }

  getApiSourceConfig() {
    return `
      <div class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700">API Endpoint</label>
          <input type="text" name="pipeline_configuration[source_config][endpoint]" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm" placeholder="https://api.example.com/data">
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">Authentication Type</label>
          <select name="pipeline_configuration[source_config][auth_type]" class="mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md">
            <option value="none">No Authentication</option>
            <option value="api_key">API Key</option>
            <option value="oauth2">OAuth 2.0</option>
            <option value="basic">Basic Auth</option>
          </select>
        </div>
      </div>
    `
  }

  getCloudStorageSourceConfig() {
    return `
      <div class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700">Cloud Provider</label>
          <select name="pipeline_configuration[source_config][provider]" class="mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md">
            <option value="aws_s3">AWS S3</option>
            <option value="google_cloud_storage">Google Cloud Storage</option>
            <option value="azure_blob">Azure Blob Storage</option>
          </select>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">Bucket Name</label>
          <input type="text" name="pipeline_configuration[source_config][bucket]" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm" placeholder="my-data-bucket">
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">File Pattern</label>
          <input type="text" name="pipeline_configuration[source_config][pattern]" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm" placeholder="data/*.csv">
        </div>
      </div>
    `
  }

  getStreamingSourceConfig() {
    return `
      <div class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700">Streaming Platform</label>
          <select name="pipeline_configuration[source_config][platform]" class="mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md">
            <option value="kafka">Apache Kafka</option>
            <option value="kinesis">AWS Kinesis</option>
            <option value="pubsub">Google Pub/Sub</option>
          </select>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">Topic/Stream Name</label>
          <input type="text" name="pipeline_configuration[source_config][topic]" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm" placeholder="user-events">
        </div>
      </div>
    `
  }

  // Destination Configuration
  selectDestinationType(event) {
    event.preventDefault()
    const destinationType = event.currentTarget.dataset.destinationType
    
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

  async loadDestinationConfiguration(destinationType) {
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
    }
    
    this.destinationConfigTarget.innerHTML = configHtml
  }

  getWarehouseDestinationConfig() {
    return `
      <div class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700">Data Warehouse</label>
          <select name="pipeline_configuration[destination_config][warehouse_type]" class="mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md">
            <option value="snowflake">Snowflake</option>
            <option value="bigquery">BigQuery</option>
            <option value="redshift">Redshift</option>
            <option value="databricks">Databricks</option>
            <option value="synapse">Azure Synapse</option>
          </select>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">Schema Name</label>
          <input type="text" name="pipeline_configuration[destination_config][schema]" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm" placeholder="analytics">
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">Table Name</label>
          <input type="text" name="pipeline_configuration[destination_config][table_name]" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm" placeholder="customer_data">
        </div>
      </div>
    `
  }

  // Transformation Management
  addTransformation(event) {
    event.preventDefault()
    this.showTransformationModal()
  }

  showTransformationModal() {
    this.transformationModalTarget.classList.remove('hidden')
    this.loadTransformationForm()
  }

  closeTransformationModal(event) {
    event.preventDefault()
    this.transformationModalTarget.classList.add('hidden')
  }

  loadTransformationForm() {
    const formHtml = `
      <div class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700">Transformation Type</label>
          <select id="transformation_type" class="mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md" data-action="change->pipeline-builder#updateTransformationForm">
            <option value="">Select type...</option>
            <option value="field_mapping">Field Mapping</option>
            <option value="rename_field">Rename Field</option>
            <option value="type_conversion">Type Conversion</option>
            <option value="calculated_field">Calculated Field</option>
            <option value="filter">Filter</option>
            <option value="aggregate">Aggregate</option>
            <option value="join">Join</option>
            <option value="pivot">Pivot</option>
            <option value="validation">Validation</option>
          </select>
        </div>
        <div id="transformation_config">
          <!-- Dynamic configuration based on type -->
        </div>
      </div>
    `
    this.transformationFormTarget.innerHTML = formHtml
  }

  updateTransformationForm(event) {
    const type = event.target.value
    const configDiv = document.getElementById('transformation_config')
    
    switch (type) {
      case 'field_mapping':
        configDiv.innerHTML = this.getFieldMappingConfig()
        break
      case 'filter':
        configDiv.innerHTML = this.getFilterConfig()
        break
      case 'calculated_field':
        configDiv.innerHTML = this.getCalculatedFieldConfig()
        break
      // Add more transformation types as needed
    }
  }

  getFieldMappingConfig() {
    return `
      <div class="space-y-2">
        <label class="block text-sm font-medium text-gray-700">Field Mappings</label>
        <div class="space-y-2">
          <div class="flex space-x-2">
            <input type="text" placeholder="Source Field" class="flex-1 rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm">
            <span class="text-gray-500">→</span>
            <input type="text" placeholder="Target Field" class="flex-1 rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm">
          </div>
        </div>
        <button type="button" class="text-sm text-indigo-600 hover:text-indigo-500">+ Add mapping</button>
      </div>
    `
  }

  getFilterConfig() {
    return `
      <div class="space-y-2">
        <div>
          <label class="block text-sm font-medium text-gray-700">Field</label>
          <input type="text" id="filter_field" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm">
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">Operator</label>
          <select id="filter_operator" class="mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md">
            <option value="equals">Equals</option>
            <option value="not_equals">Not Equals</option>
            <option value="greater_than">Greater Than</option>
            <option value="less_than">Less Than</option>
            <option value="contains">Contains</option>
            <option value="is_null">Is Null</option>
            <option value="is_not_null">Is Not Null</option>
          </select>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">Value</label>
          <input type="text" id="filter_value" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm">
        </div>
      </div>
    `
  }

  getCalculatedFieldConfig() {
    return `
      <div class="space-y-2">
        <div>
          <label class="block text-sm font-medium text-gray-700">Field Name</label>
          <input type="text" id="calc_field_name" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm">
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">Expression</label>
          <textarea id="calc_expression" rows="3" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm" placeholder="price * quantity"></textarea>
          <p class="mt-1 text-xs text-gray-500">Use field names in your expression. Functions: upper(), lower(), concat(), etc.</p>
        </div>
      </div>
    `
  }

  saveTransformation(event) {
    event.preventDefault()
    
    const type = document.getElementById('transformation_type').value
    if (!type) return
    
    const transformation = {
      id: Date.now(),
      type: type,
      config: this.getTransformationConfig(type)
    }
    
    this.transformations.push(transformation)
    this.updateTransformationsList()
    this.updateCanvas()
    this.closeTransformationModal(event)
  }

  getTransformationConfig(type) {
    // Extract configuration based on type
    switch (type) {
      case 'filter':
        return {
          field: document.getElementById('filter_field').value,
          operator: document.getElementById('filter_operator').value,
          value: document.getElementById('filter_value').value
        }
      case 'calculated_field':
        return {
          field_name: document.getElementById('calc_field_name').value,
          expression: document.getElementById('calc_expression').value
        }
      // Add more cases as needed
    }
  }

  updateTransformationsList() {
    if (this.transformations.length === 0) {
      this.canvasTarget.querySelector('.text-center').classList.remove('hidden')
      this.transformationsListTarget.innerHTML = ''
      return
    }
    
    this.canvasTarget.querySelector('.text-center').classList.add('hidden')
    
    const listHtml = this.transformations.map((transform, index) => `
      <div class="bg-white p-4 rounded-lg border border-gray-200 shadow-sm">
        <div class="flex items-center justify-between">
          <div class="flex items-center">
            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-indigo-100 text-indigo-800">
              ${transform.type.replace(/_/g, ' ')}
            </span>
            <span class="ml-3 text-sm text-gray-700">${this.getTransformationSummary(transform)}</span>
          </div>
          <button type="button" data-action="click->pipeline-builder#removeTransformation" data-transformation-id="${transform.id}" class="text-gray-400 hover:text-gray-500">
            <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>
      </div>
    `).join('')
    
    this.transformationsListTarget.innerHTML = listHtml
  }

  getTransformationSummary(transform) {
    switch (transform.type) {
      case 'filter':
        return `${transform.config.field} ${transform.config.operator} ${transform.config.value}`
      case 'calculated_field':
        return `${transform.config.field_name} = ${transform.config.expression}`
      default:
        return JSON.stringify(transform.config)
    }
  }

  removeTransformation(event) {
    const id = parseInt(event.currentTarget.dataset.transformationId)
    this.transformations = this.transformations.filter(t => t.id !== id)
    this.updateTransformationsList()
    this.updateCanvas()
  }

  updateCanvas() {
    // Update visual pipeline representation
    // This could be enhanced with a proper visualization library
  }

  // Test Pipeline
  async testPipeline(event) {
    event.preventDefault()
    
    const testButton = event.currentTarget
    testButton.disabled = true
    testButton.innerHTML = '<svg class="animate-spin -ml-1 mr-2 h-5 w-5 text-white" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg> Testing...'
    
    try {
      const response = await fetch(`/etl_pipeline_builders/${this.element.dataset.pipelineId}/test`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({
          sample_size: 100,
          dry_run: true
        })
      })
      
      const result = await response.json()
      
      if (result.success) {
        alert('Pipeline test successful! Check the console for details.')
        console.log('Test Results:', result)
      } else {
        alert(`Pipeline test failed: ${result.error}`)
      }
    } catch (error) {
      alert('Failed to test pipeline: ' + error.message)
    } finally {
      testButton.disabled = false
      testButton.innerHTML = '<svg class="-ml-1 mr-2 h-5 w-5" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M9.75 3.104v5.714a2.25 2.25 0 01-.659 1.591L5 14.5M9.75 3.104c-.251.023-.501.05-.75.082m.75-.082a24.301 24.301 0 014.5 0m0 0v5.714c0 .597.237 1.17.659 1.591L19.8 15.3M14.25 3.104c.251.023.501.05.75.082M19.8 15.3l-1.57.393A9.065 9.065 0 0112 15a9.065 9.065 0 00-6.23-.693L5 14.5m14.8.8l1.402 1.402c1.232 1.232.65 3.318-1.067 3.611l-3.98.793a2.125 2.125 0 01-1.113-.825L12 15M8.25 12h4.5" /></svg> Test Pipeline'
    }
  }

  updateTransformationOptions(pipelineType) {
    // Update available transformation options based on pipeline type
    // For ELT, transformations happen after loading
  }
};
