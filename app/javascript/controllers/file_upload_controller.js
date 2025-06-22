import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "input", "dropZone", "fileList", "preview", "previewContent", 
    "progressContainer", "batchProgress", "uploadStatus", "dataPreview",
    "columnMapping", "dataQuality", "dataInsights", "totalRows", "totalColumns",
    "qualityScore", "completeness", "qualityIssues", "suggestedTransformations",
    "columnAnalysisTable"
  ]
  static values = { 
    maxSize: Number, 
    acceptedTypes: Array,
    uploadUrl: String,
    previewUrl: String,
    csrfToken: String
  }

  connect() {
    this.maxSizeValue = this.maxSizeValue || 52428800 // 50MB default
    this.acceptedTypesValue = this.acceptedTypesValue || [
      'text/csv',
      'application/vnd.ms-excel',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'application/json',
      'text/plain',
      'application/xml',
      'text/xml',
      'application/octet-stream', // For Parquet files
      'text/tab-separated-values',
      'application/x-yaml',
      'text/yaml'
    ]
    this.files = []
    this.uploadProgress = new Map()
    this.processedFiles = new Map()
    this.isUploading = false
  }

  handleFiles(event) {
    const files = Array.from(event.target ? event.target.files : event)
    
    files.forEach(file => {
      if (this.validateFile(file)) {
        this.addFile(file)
      }
    })
    
    this.updateFileList()
  }

  // Enhanced drag and drop events
  dragOver(event) {
    event.preventDefault()
    event.stopPropagation()
    this.dropZoneTarget.classList.add('border-indigo-500', 'bg-indigo-50', 'border-2')
    this.dropZoneTarget.classList.remove('border-gray-300', 'border-dashed')
    
    // Add visual feedback
    const dropText = this.dropZoneTarget.querySelector('.drop-text')
    if (dropText) {
      dropText.textContent = 'Drop files here to upload'
    }
  }

  dragEnter(event) {
    event.preventDefault()
    event.stopPropagation()
  }

  dragLeave(event) {
    event.preventDefault()
    event.stopPropagation()
    
    // Only remove styling if we're leaving the drop zone entirely
    if (!this.dropZoneTarget.contains(event.relatedTarget)) {
      this.dropZoneTarget.classList.remove('border-indigo-500', 'bg-indigo-50', 'border-2')
      this.dropZoneTarget.classList.add('border-gray-300', 'border-dashed')
      
      const dropText = this.dropZoneTarget.querySelector('.drop-text')
      if (dropText) {
        dropText.textContent = 'Drag and drop files here, or click to select'
      }
    }
  }

  drop(event) {
    event.preventDefault()
    event.stopPropagation()
    
    this.dropZoneTarget.classList.remove('border-indigo-500', 'bg-indigo-50', 'border-2')
    this.dropZoneTarget.classList.add('border-gray-300', 'border-dashed')
    
    const dropText = this.dropZoneTarget.querySelector('.drop-text')
    if (dropText) {
      dropText.textContent = 'Drag and drop files here, or click to select'
    }
    
    const files = Array.from(event.dataTransfer.files)
    this.handleFiles(files)
  }

  validateFile(file) {
    // Check file size
    if (file.size > this.maxSizeValue) {
      this.showError(`${file.name} is too large. Maximum file size is 50MB.`)
      return false
    }

    // Check file type (enhanced validation)
    if (!this.isFileTypeSupported(file)) {
      this.showError(`${file.name} is not a supported file type. Please upload CSV, Excel, JSON, XML, Parquet, YAML, or text files.`)
      return false
    }

    // Check if file already selected
    if (this.files.some(f => f.name === file.name && f.size === file.size)) {
      this.showError(`${file.name} has already been selected.`)
      return false
    }

    return true
  }

  addFile(file) {
    const fileData = {
      file: file,
      name: file.name,
      size: file.size,
      type: file.type,
      id: this.generateFileId()
    }
    
    this.files.push(fileData)
  }

  removeFile(event) {
    const fileId = event.target.closest('[data-file-id]').dataset.fileId
    this.files = this.files.filter(f => f.id !== fileId)
    this.updateFileList()
    this.updateFileInput()
  }

  previewFile(event) {
    const fileId = event.target.closest('[data-file-id]').dataset.fileId
    const fileData = this.files.find(f => f.id === fileId)
    
    if (!fileData) return

    this.showFilePreview(fileData)
  }

  updateFileList() {
    const listContainer = this.fileListTarget
    if (!listContainer) return

    if (this.files.length === 0) {
      listContainer.innerHTML = ''
      return
    }

    const filesHTML = this.files.map(fileData => {
      return `
        <div class="flex items-center justify-between p-4 bg-white border border-gray-200 rounded-lg shadow-sm" data-file-id="${fileData.id}">
          <div class="flex items-center space-x-3">
            <div class="flex-shrink-0">
              ${this.getFileIcon(fileData.type)}
            </div>
            <div class="flex-1 min-w-0">
              <p class="text-sm font-medium text-gray-900 truncate">${fileData.name}</p>
              <p class="text-sm text-gray-500">${this.formatFileSize(fileData.size)} • ${this.getFileTypeLabel(fileData.type)}</p>
            </div>
          </div>
          <div class="flex items-center space-x-2">
            <button type="button" class="inline-flex items-center px-2.5 py-1.5 border border-gray-300 shadow-sm text-xs font-medium rounded text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500" data-action="click->file-upload#previewFile">
              <svg class="h-3 w-3 mr-1" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z" />
                <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
              </svg>
              Preview
            </button>
            <button type="button" class="inline-flex items-center px-2.5 py-1.5 border border-red-300 shadow-sm text-xs font-medium rounded text-red-700 bg-white hover:bg-red-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500" data-action="click->file-upload#removeFile">
              <svg class="h-3 w-3 mr-1" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" />
              </svg>
              Remove
            </button>
          </div>
        </div>
      `
    }).join('')

    listContainer.innerHTML = `
      <div class="space-y-2">
        <h4 class="text-sm font-medium text-gray-900">Selected Files (${this.files.length})</h4>
        ${filesHTML}
      </div>
    `
  }

  updateFileInput() {
    // Create a new DataTransfer object to update the file input
    const dt = new DataTransfer()
    
    this.files.forEach(fileData => {
      dt.items.add(fileData.file)
    })
    
    if (this.inputTarget) {
      this.inputTarget.files = dt.files
    }
  }

  showFilePreview(fileData) {
    // Create a modal or preview area to show file contents
    this.createPreviewModal(fileData)
  }

  createPreviewModal(fileData) {
    const modal = document.createElement('div')
    modal.className = 'fixed inset-0 z-50 overflow-y-auto'
    modal.innerHTML = `
      <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"></div>
        <div class="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-4xl sm:w-full">
          <div class="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
            <div class="flex items-center justify-between mb-4">
              <h3 class="text-lg font-medium text-gray-900">File Preview: ${fileData.name}</h3>
              <button type="button" class="close-preview text-gray-400 hover:text-gray-600">
                <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
            <div class="preview-content">
              <div class="text-center py-8">
                <div class="animate-spin inline-block w-6 h-6 border-[3px] border-current border-t-transparent text-blue-600 rounded-full"></div>
                <p class="mt-2 text-sm text-gray-500">Loading preview...</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    `

    document.body.appendChild(modal)

    // Close modal functionality
    modal.querySelector('.close-preview').addEventListener('click', () => {
      document.body.removeChild(modal)
    })

    modal.addEventListener('click', (e) => {
      if (e.target === modal) {
        document.body.removeChild(modal)
      }
    })

    // Load file preview
    this.loadFilePreview(fileData, modal.querySelector('.preview-content'))
  }

  loadFilePreview(fileData, container) {
    const reader = new FileReader()
    
    reader.onload = (e) => {
      const content = e.target.result
      let previewHTML = ''

      switch (fileData.type) {
        case 'text/csv':
          previewHTML = this.renderCSVPreview(content)
          break
        case 'application/json':
          previewHTML = this.renderJSONPreview(content)
          break
        case 'text/plain':
          previewHTML = this.renderTextPreview(content)
          break
        default:
          previewHTML = '<p class="text-gray-500">Preview not available for this file type.</p>'
      }

      container.innerHTML = previewHTML
    }

    reader.onerror = () => {
      container.innerHTML = '<p class="text-red-500">Error loading file preview.</p>'
    }

    reader.readAsText(fileData.file)
  }

  renderCSVPreview(content) {
    const lines = content.split('\n').slice(0, 10) // Show first 10 rows
    const rows = lines.map(line => line.split(','))
    
    if (rows.length === 0) return '<p class="text-gray-500">Empty file</p>'

    const tableHTML = `
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              ${rows[0].map(header => `<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">${header.trim()}</th>`).join('')}
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            ${rows.slice(1).map(row => `
              <tr>
                ${row.map(cell => `<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">${cell.trim()}</td>`).join('')}
              </tr>
            `).join('')}
          </tbody>
        </table>
      </div>
      <p class="mt-4 text-sm text-gray-500">Showing first 10 rows</p>
    `

    return tableHTML
  }

  renderJSONPreview(content) {
    try {
      const jsonData = JSON.parse(content)
      const formatted = JSON.stringify(jsonData, null, 2)
      
      return `
        <pre class="bg-gray-50 p-4 rounded-md overflow-x-auto text-sm"><code>${this.escapeHtml(formatted)}</code></pre>
        <p class="mt-4 text-sm text-gray-500">JSON data structure preview</p>
      `
    } catch (e) {
      return '<p class="text-red-500">Invalid JSON format</p>'
    }
  }

  renderTextPreview(content) {
    const lines = content.split('\n').slice(0, 20) // Show first 20 lines
    
    return `
      <pre class="bg-gray-50 p-4 rounded-md overflow-x-auto text-sm whitespace-pre-wrap">${this.escapeHtml(lines.join('\n'))}</pre>
      <p class="mt-4 text-sm text-gray-500">Showing first 20 lines</p>
    `
  }

  // Helper methods
  generateFileId() {
    return Date.now().toString(36) + Math.random().toString(36).substr(2)
  }

  formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes'
    
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
  }

  getFileIcon(type) {
    const icons = {
      'text/csv': `
        <div class="flex h-8 w-8 items-center justify-center rounded bg-green-100">
          <span class="text-xs font-medium text-green-700">CSV</span>
        </div>
      `,
      'application/vnd.ms-excel': `
        <div class="flex h-8 w-8 items-center justify-center rounded bg-green-100">
          <span class="text-xs font-medium text-green-700">XLS</span>
        </div>
      `,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': `
        <div class="flex h-8 w-8 items-center justify-center rounded bg-green-100">
          <span class="text-xs font-medium text-green-700">XLSX</span>
        </div>
      `,
      'application/json': `
        <div class="flex h-8 w-8 items-center justify-center rounded bg-blue-100">
          <span class="text-xs font-medium text-blue-700">JSON</span>
        </div>
      `,
      'text/plain': `
        <div class="flex h-8 w-8 items-center justify-center rounded bg-gray-100">
          <span class="text-xs font-medium text-gray-700">TXT</span>
        </div>
      `,
      'application/xml': `
        <div class="flex h-8 w-8 items-center justify-center rounded bg-orange-100">
          <span class="text-xs font-medium text-orange-700">XML</span>
        </div>
      `,
      'text/xml': `
        <div class="flex h-8 w-8 items-center justify-center rounded bg-orange-100">
          <span class="text-xs font-medium text-orange-700">XML</span>
        </div>
      `,
      'application/octet-stream': `
        <div class="flex h-8 w-8 items-center justify-center rounded bg-purple-100">
          <span class="text-xs font-medium text-purple-700">PQT</span>
        </div>
      `,
      'text/tab-separated-values': `
        <div class="flex h-8 w-8 items-center justify-center rounded bg-teal-100">
          <span class="text-xs font-medium text-teal-700">TSV</span>
        </div>
      `,
      'application/x-yaml': `
        <div class="flex h-8 w-8 items-center justify-center rounded bg-indigo-100">
          <span class="text-xs font-medium text-indigo-700">YAML</span>
        </div>
      `,
      'text/yaml': `
        <div class="flex h-8 w-8 items-center justify-center rounded bg-indigo-100">
          <span class="text-xs font-medium text-indigo-700">YAML</span>
        </div>
      `
    }

    return icons[type] || `
      <div class="flex h-8 w-8 items-center justify-center rounded bg-gray-100">
        <span class="text-xs font-medium text-gray-700">FILE</span>
      </div>
    `
  }

  getFileTypeLabel(type) {
    const labels = {
      'text/csv': 'CSV File',
      'application/vnd.ms-excel': 'Excel File (XLS)',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': 'Excel File (XLSX)',
      'application/json': 'JSON File',
      'text/plain': 'Text File',
      'application/xml': 'XML File',
      'text/xml': 'XML File',
      'application/octet-stream': 'Parquet File',
      'text/tab-separated-values': 'TSV File',
      'application/x-yaml': 'YAML File',
      'text/yaml': 'YAML File'
    }

    return labels[type] || 'Unknown File Type'
  }

  isFileTypeSupported(file) {
    // Check MIME type
    if (this.acceptedTypesValue.includes(file.type)) {
      return true
    }
    
    // Check file extension for cases where MIME type might not be detected correctly
    const extension = file.name.split('.').pop().toLowerCase()
    const supportedExtensions = [
      'csv', 'xls', 'xlsx', 'json', 'txt', 'text',
      'xml', 'parquet', 'tsv', 'tab', 'yaml', 'yml'
    ]
    
    return supportedExtensions.includes(extension)
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  showError(message) {
    // Create a temporary error message
    const errorDiv = document.createElement('div')
    errorDiv.className = 'fixed top-4 right-4 bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded z-50'
    errorDiv.textContent = message

    document.body.appendChild(errorDiv)

    // Remove after 5 seconds
    setTimeout(() => {
      if (errorDiv.parentNode) {
        document.body.removeChild(errorDiv)
      }
    }, 5000)
  }

  // Enhanced file processing with progress tracking
  async processFiles() {
    if (this.isUploading || this.files.length === 0) return

    this.isUploading = true
    this.showBatchProgress()
    
    try {
      for (let i = 0; i < this.files.length; i++) {
        const fileData = this.files[i]
        await this.processFile(fileData, i)
        this.updateBatchProgress((i + 1) / this.files.length * 100)
      }
      
      this.showUploadSuccess()
      this.dispatch('filesProcessed', { detail: { files: this.processedFiles } })
    } catch (error) {
      this.showUploadError(error.message)
    } finally {
      this.isUploading = false
      this.hideBatchProgress()
    }
  }

  async processFile(fileData, index) {
    const progressId = `file-progress-${fileData.id}`
    this.showFileProgress(fileData, progressId)
    
    try {
      // Analyze file structure
      const analysis = await this.analyzeFileStructure(fileData.file)
      
      // Update progress
      this.updateFileProgress(progressId, 50, 'Analyzing structure...')
      
      // Process file data
      const processedData = await this.extractFileData(fileData.file, analysis)
      
      // Update progress
      this.updateFileProgress(progressId, 100, 'Complete')
      
      // Store processed data
      this.processedFiles.set(fileData.id, {
        ...fileData,
        analysis,
        data: processedData,
        status: 'processed'
      })
      
      // Show data preview if available
      this.showDataPreview(fileData.id, processedData, analysis)
      
    } catch (error) {
      this.updateFileProgress(progressId, 0, `Error: ${error.message}`, 'error')
      throw error
    }
  }

  async analyzeFileStructure(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader()
      
      reader.onload = (e) => {
        try {
          const content = e.target.result
          const analysis = this.performStructureAnalysis(file, content)
          resolve(analysis)
        } catch (error) {
          reject(error)
        }
      }
      
      reader.onerror = () => reject(new Error('Failed to read file'))
      reader.readAsText(file)
    })
  }

  performStructureAnalysis(file, content) {
    const analysis = {
      fileName: file.name,
      fileSize: file.size,
      fileType: file.type,
      detectedType: this.detectFileType(file.name, content),
      encoding: 'UTF-8',
      lineCount: 0,
      columnCount: 0,
      headers: [],
      dataTypes: {},
      sampleData: [],
      quality: {
        hasHeaders: false,
        emptyRows: 0,
        duplicateRows: 0,
        missingValues: 0
      }
    }

    if (analysis.detectedType === 'csv') {
      this.analyzeCsvStructure(content, analysis)
    } else if (analysis.detectedType === 'json') {
      this.analyzeJsonStructure(content, analysis)
    } else if (analysis.detectedType === 'xml') {
      this.analyzeXmlStructure(content, analysis)
    } else if (analysis.detectedType === 'tsv') {
      this.analyzeTsvStructure(content, analysis)
    } else if (analysis.detectedType === 'yaml') {
      this.analyzeYamlStructure(content, analysis)
    } else if (analysis.detectedType === 'text') {
      this.analyzeTextStructure(content, analysis)
    }

    return analysis
  }

  detectFileType(fileName, content) {
    const extension = fileName.split('.').pop().toLowerCase()
    
    if (extension === 'csv') return 'csv'
    if (['xls', 'xlsx'].includes(extension)) return 'excel'
    if (extension === 'json') return 'json'
    if (['txt', 'text'].includes(extension)) return 'text'
    if (['xml'].includes(extension)) return 'xml'
    if (['parquet'].includes(extension)) return 'parquet'
    if (['tsv', 'tab'].includes(extension)) return 'tsv'
    if (['yaml', 'yml'].includes(extension)) return 'yaml'
    
    // Try to detect from content
    try {
      JSON.parse(content)
      return 'json'
    } catch {}
    
    if (content.trim().startsWith('<') && content.trim().endsWith('>')) return 'xml'
    if (content.includes('\t') && content.includes('\n')) return 'tsv'
    if (content.includes(',') && content.includes('\n')) return 'csv'
    return 'text'
  }

  analyzeCsvStructure(content, analysis) {
    const lines = content.split('\n').filter(line => line.trim())
    analysis.lineCount = lines.length
    
    if (lines.length === 0) return
    
    // Parse first few lines to detect structure
    const firstLine = lines[0]
    const delimiter = this.detectCsvDelimiter(firstLine)
    const headers = firstLine.split(delimiter).map(h => h.trim().replace(/"/g, ''))
    
    analysis.columnCount = headers.length
    analysis.headers = headers
    analysis.quality.hasHeaders = this.detectHeaders(headers)
    
    // Analyze data types and quality
    const sampleSize = Math.min(10, lines.length - 1)
    for (let i = 1; i <= sampleSize; i++) {
      if (lines[i]) {
        const row = lines[i].split(delimiter).map(cell => cell.trim().replace(/"/g, ''))
        analysis.sampleData.push(row)
      }
    }
    
    // Detect data types
    headers.forEach((header, index) => {
      analysis.dataTypes[header] = this.detectColumnDataType(analysis.sampleData, index)
    })
  }

  analyzeJsonStructure(content, analysis) {
    try {
      const data = JSON.parse(content)
      
      if (Array.isArray(data) && data.length > 0) {
        analysis.lineCount = data.length
        const firstItem = data[0]
        
        if (typeof firstItem === 'object') {
          analysis.headers = Object.keys(firstItem)
          analysis.columnCount = analysis.headers.length
          analysis.quality.hasHeaders = true
          
          // Sample data
          analysis.sampleData = data.slice(0, 10).map(item => 
            analysis.headers.map(header => item[header])
          )
          
          // Detect data types
          analysis.headers.forEach((header, index) => {
            analysis.dataTypes[header] = this.detectColumnDataType(analysis.sampleData, index)
          })
        }
      }
    } catch (error) {
      throw new Error('Invalid JSON format')
    }
  }

  analyzeTextStructure(content, analysis) {
    const lines = content.split('\n')
    analysis.lineCount = lines.length
    analysis.sampleData = lines.slice(0, 20)
  }

  analyzeXmlStructure(content, analysis) {
    try {
      const parser = new DOMParser()
      const xmlDoc = parser.parseFromString(content, 'text/xml')
      
      if (xmlDoc.getElementsByTagName('parsererror').length > 0) {
        throw new Error('Invalid XML format')
      }
      
      const rootElement = xmlDoc.documentElement
      analysis.rootElement = rootElement.tagName
      analysis.xmlNamespace = rootElement.namespaceURI
      
      // Extract structure information
      const elements = Array.from(rootElement.children)
      if (elements.length > 0) {
        analysis.headers = Array.from(elements[0].children).map(child => child.tagName)
        analysis.columnCount = analysis.headers.length
        analysis.lineCount = elements.length
        
        // Sample data
        analysis.sampleData = elements.slice(0, 10).map(element => 
          analysis.headers.map(header => {
            const child = element.getElementsByTagName(header)[0]
            return child ? child.textContent : ''
          })
        )
      }
    } catch (error) {
      throw new Error('Invalid XML format')
    }
  }

  analyzeTsvStructure(content, analysis) {
    const lines = content.split('\n').filter(line => line.trim())
    analysis.lineCount = lines.length
    
    if (lines.length === 0) return
    
    // Parse first line as headers
    const headers = lines[0].split('\t').map(h => h.trim())
    analysis.columnCount = headers.length
    analysis.headers = headers
    analysis.quality.hasHeaders = this.detectHeaders(headers)
    
    // Sample data
    const sampleSize = Math.min(10, lines.length - 1)
    for (let i = 1; i <= sampleSize; i++) {
      if (lines[i]) {
        const row = lines[i].split('\t').map(cell => cell.trim())
        analysis.sampleData.push(row)
      }
    }
    
    // Detect data types
    headers.forEach((header, index) => {
      analysis.dataTypes[header] = this.detectColumnDataType(analysis.sampleData, index)
    })
  }

  analyzeYamlStructure(content, analysis) {
    try {
      // Basic YAML parsing (would need js-yaml library for full support)
      const lines = content.split('\n').filter(line => line.trim() && !line.trim().startsWith('#'))
      analysis.lineCount = lines.length
      
      // Extract keys (simplified)
      const keys = lines
        .filter(line => line.includes(':'))
        .map(line => line.split(':')[0].trim().replace(/^-\s*/, ''))
        .filter(key => key && !key.includes(' '))
      
      analysis.headers = [...new Set(keys)]
      analysis.columnCount = analysis.headers.length
      analysis.sampleData = lines.slice(0, 20)
    } catch (error) {
      throw new Error('Invalid YAML format')
    }
  }

  detectCsvDelimiter(line) {
    const delimiters = [',', ';', '\t', '|']
    let maxCount = 0
    let bestDelimiter = ','
    
    delimiters.forEach(delimiter => {
      const count = (line.match(new RegExp(delimiter, 'g')) || []).length
      if (count > maxCount) {
        maxCount = count
        bestDelimiter = delimiter
      }
    })
    
    return bestDelimiter
  }

  detectHeaders(headers) {
    // Simple heuristic: if headers contain mostly text and few numbers
    const textHeaders = headers.filter(header => isNaN(header)).length
    return textHeaders / headers.length > 0.7
  }

  detectColumnDataType(sampleData, columnIndex) {
    const values = sampleData.map(row => row[columnIndex]).filter(val => val !== '' && val != null)
    
    if (values.length === 0) return 'text'
    
    const numericCount = values.filter(val => !isNaN(val) && !isNaN(parseFloat(val))).length
    const dateCount = values.filter(val => !isNaN(Date.parse(val))).length
    
    if (numericCount / values.length > 0.8) return 'number'
    if (dateCount / values.length > 0.8) return 'date'
    return 'text'
  }

  async extractFileData(file, analysis) {
    // For now, return the analysis. In a real implementation,
    // this would extract and transform the actual data
    return {
      preview: analysis.sampleData,
      structure: analysis,
      totalRows: analysis.lineCount,
      columns: analysis.headers
    }
  }

  // UI Helper Methods for Progress and Preview
  showBatchProgress() {
    if (this.hasProgressContainerTarget) {
      this.progressContainerTarget.classList.remove('hidden')
    }
  }

  hideBatchProgress() {
    if (this.hasProgressContainerTarget) {
      this.progressContainerTarget.classList.add('hidden')
    }
  }

  updateBatchProgress(percentage) {
    if (this.hasBatchProgressTarget) {
      this.batchProgressTarget.style.width = `${percentage}%`
      this.batchProgressTarget.setAttribute('aria-valuenow', percentage)
    }
  }

  showFileProgress(fileData, progressId) {
    const progressHTML = `
      <div id="${progressId}" class="mt-2 p-3 bg-gray-50 rounded-md">
        <div class="flex items-center justify-between mb-2">
          <span class="text-sm font-medium text-gray-700">${fileData.name}</span>
          <span class="text-sm text-gray-500">0%</span>
        </div>
        <div class="w-full bg-gray-200 rounded-full h-2">
          <div class="bg-blue-600 h-2 rounded-full transition-all duration-300" style="width: 0%"></div>
        </div>
        <div class="mt-1 text-xs text-gray-500">Starting...</div>
      </div>
    `
    
    const fileElement = document.querySelector(`[data-file-id="${fileData.id}"]`)
    if (fileElement) {
      fileElement.insertAdjacentHTML('beforeend', progressHTML)
    }
  }

  updateFileProgress(progressId, percentage, status, type = 'info') {
    const progressElement = document.getElementById(progressId)
    if (!progressElement) return

    const progressBar = progressElement.querySelector('.bg-blue-600, .bg-green-600, .bg-red-600')
    const percentageSpan = progressElement.querySelector('.text-gray-500')
    const statusDiv = progressElement.querySelector('.text-xs')

    if (progressBar) {
      progressBar.style.width = `${percentage}%`
      
      // Update color based on type
      progressBar.className = progressBar.className.replace(/bg-(blue|green|red)-600/, 
        type === 'error' ? 'bg-red-600' : type === 'success' ? 'bg-green-600' : 'bg-blue-600'
      )
    }

    if (percentageSpan) {
      percentageSpan.textContent = `${Math.round(percentage)}%`
    }

    if (statusDiv) {
      statusDiv.textContent = status
      statusDiv.className = `mt-1 text-xs ${
        type === 'error' ? 'text-red-600' : 
        type === 'success' ? 'text-green-600' : 'text-gray-500'
      }`
    }
  }

  showDataPreview(fileId, processedData, analysis) {
    if (!this.hasDataPreviewTarget) return

    const previewHTML = `
      <div class="mt-4 p-4 bg-white border border-gray-200 rounded-lg" data-file-preview="${fileId}">
        <div class="flex items-center justify-between mb-3">
          <h4 class="text-sm font-medium text-gray-900">Data Preview: ${analysis.fileName}</h4>
          <button type="button" class="text-indigo-600 hover:text-indigo-500 text-sm" 
                  data-action="click->file-upload#togglePreview" data-file-id="${fileId}">
            View Details
          </button>
        </div>
        
        <div class="grid grid-cols-3 gap-4 mb-3 text-sm">
          <div>
            <span class="text-gray-500">Rows:</span>
            <span class="font-medium">${analysis.lineCount.toLocaleString()}</span>
          </div>
          <div>
            <span class="text-gray-500">Columns:</span>
            <span class="font-medium">${analysis.columnCount}</span>
          </div>
          <div>
            <span class="text-gray-500">Type:</span>
            <span class="font-medium capitalize">${analysis.detectedType}</span>
          </div>
        </div>
        
        ${this.renderDataTable(processedData.preview, analysis.headers)}
        
        <div class="mt-3 text-xs text-gray-500">
          Showing first ${Math.min(processedData.preview.length, 10)} rows
        </div>
      </div>
    `

    this.dataPreviewTarget.insertAdjacentHTML('beforeend', previewHTML)
    
    // Show enhanced data insights
    this.showEnhancedDataInsights(analysis, processedData)
  }

  showEnhancedDataInsights(analysis, processedData) {
    if (!this.hasDataInsightsTarget) return

    // Calculate enhanced metrics
    const qualityScore = this.calculateQualityScore(analysis)
    const completeness = this.calculateCompleteness(analysis)
    const issues = this.identifyQualityIssues(analysis)
    const transformations = this.suggestTransformations(analysis)

    // Update quick stats
    this.updateQuickStats(analysis, qualityScore, completeness)
    
    // Show quality issues
    this.displayQualityIssues(issues)
    
    // Show suggested transformations
    this.displaySuggestedTransformations(transformations)
    
    // Show column analysis
    this.displayColumnAnalysis(analysis)
    
    // Show the insights panel
    this.dataInsightsTarget.classList.remove('hidden')
  }

  updateQuickStats(analysis, qualityScore, completeness) {
    if (this.hasTotalRowsTarget) this.totalRowsTarget.textContent = analysis.lineCount.toLocaleString()
    if (this.hasTotalColumnsTarget) this.totalColumnsTarget.textContent = analysis.columnCount
    if (this.hasQualityScoreTarget) this.qualityScoreTarget.textContent = `${qualityScore}%`
    if (this.hasCompletenessTarget) this.completenessTarget.textContent = `${completeness}%`
  }

  calculateQualityScore(analysis) {
    let score = 100
    
    // Deduct points for missing headers
    if (!analysis.quality.hasHeaders) score -= 20
    
    // Deduct points for empty rows (max 20 points)
    const emptyRowsPenalty = Math.min(20, (analysis.quality.emptyRows / analysis.lineCount) * 100)
    score -= emptyRowsPenalty
    
    // Deduct points for missing values (max 30 points)
    const missingValuesPenalty = Math.min(30, (analysis.quality.missingValues / (analysis.lineCount * analysis.columnCount)) * 100)
    score -= missingValuesPenalty
    
    return Math.max(0, Math.round(score))
  }

  calculateCompleteness(analysis) {
    const totalCells = analysis.lineCount * analysis.columnCount
    const filledCells = totalCells - analysis.quality.missingValues
    return Math.round((filledCells / totalCells) * 100)
  }

  identifyQualityIssues(analysis) {
    const issues = []
    
    if (!analysis.quality.hasHeaders) {
      issues.push({
        type: 'warning',
        title: 'Missing Headers',
        description: 'First row may not contain column headers',
        severity: 'medium'
      })
    }
    
    if (analysis.quality.emptyRows > 0) {
      issues.push({
        type: 'warning',
        title: 'Empty Rows',
        description: `Found ${analysis.quality.emptyRows} empty rows that should be removed`,
        severity: 'low'
      })
    }
    
    if (analysis.quality.missingValues > 0) {
      const percentage = ((analysis.quality.missingValues / (analysis.lineCount * analysis.columnCount)) * 100).toFixed(1)
      issues.push({
        type: 'info',
        title: 'Missing Values',
        description: `${analysis.quality.missingValues} missing values (${percentage}% of data)`,
        severity: percentage > 10 ? 'high' : 'low'
      })
    }
    
    if (analysis.quality.duplicateRows > 0) {
      issues.push({
        type: 'warning',
        title: 'Duplicate Rows',
        description: `Found ${analysis.quality.duplicateRows} duplicate rows`,
        severity: 'medium'
      })
    }
    
    return issues
  }

  suggestTransformations(analysis) {
    const transformations = []
    
    // Suggest header normalization
    if (analysis.headers.some(h => h.includes(' ') || h.includes('-'))) {
      transformations.push({
        type: 'normalize_headers',
        title: 'Normalize Column Names',
        description: 'Convert column names to snake_case format for better data processing',
        impact: 'low'
      })
    }
    
    // Suggest data type conversions
    Object.entries(analysis.dataTypes).forEach(([column, type]) => {
      if (type === 'text' && column.toLowerCase().includes('date')) {
        transformations.push({
          type: 'convert_date',
          title: `Convert '${column}' to Date`,
          description: 'This column appears to contain date values',
          impact: 'medium'
        })
      }
      
      if (type === 'text' && column.toLowerCase().includes('price', 'amount', 'cost', 'revenue')) {
        transformations.push({
          type: 'convert_number',
          title: `Convert '${column}' to Number`,
          description: 'This column appears to contain numeric values',
          impact: 'medium'
        })
      }
    })
    
    // Suggest removing empty rows
    if (analysis.quality.emptyRows > 0) {
      transformations.push({
        type: 'remove_empty_rows',
        title: 'Remove Empty Rows',
        description: `Clean up ${analysis.quality.emptyRows} empty rows`,
        impact: 'low'
      })
    }
    
    return transformations
  }

  displayQualityIssues(issues) {
    if (!this.hasQualityIssuesTarget) return
    
    if (issues.length === 0) {
      this.qualityIssuesTarget.innerHTML = `
        <div class="flex items-center p-3 bg-green-50 border border-green-200 rounded-lg">
          <svg class="w-5 h-5 text-green-600 mr-3" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
          </svg>
          <span class="text-sm font-medium text-green-800">No data quality issues detected!</span>
        </div>
      `
      return
    }
    
    const issuesHTML = issues.map(issue => {
      const colors = {
        warning: { bg: 'bg-yellow-50', border: 'border-yellow-200', text: 'text-yellow-800', icon: 'text-yellow-600' },
        info: { bg: 'bg-blue-50', border: 'border-blue-200', text: 'text-blue-800', icon: 'text-blue-600' },
        error: { bg: 'bg-red-50', border: 'border-red-200', text: 'text-red-800', icon: 'text-red-600' }
      }
      
      const color = colors[issue.type] || colors.info
      
      return `
        <div class="flex items-start p-3 ${color.bg} border ${color.border} rounded-lg">
          <svg class="w-5 h-5 ${color.icon} mr-3 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"></path>
          </svg>
          <div>
            <div class="text-sm font-medium ${color.text}">${issue.title}</div>
            <div class="text-sm ${color.text} opacity-80">${issue.description}</div>
          </div>
          <span class="ml-auto text-xs px-2 py-1 bg-white rounded-full ${color.text} font-medium">${issue.severity}</span>
        </div>
      `
    }).join('')
    
    this.qualityIssuesTarget.innerHTML = issuesHTML
  }

  displaySuggestedTransformations(transformations) {
    if (!this.hasSuggestedTransformationsTarget) return
    
    if (transformations.length === 0) {
      this.suggestedTransformationsTarget.innerHTML = `
        <div class="text-sm text-gray-500 italic">No transformations suggested. Your data looks good!</div>
      `
      return
    }
    
    const transformationsHTML = transformations.map(transformation => `
      <div class="flex items-center justify-between p-3 bg-gray-50 border border-gray-200 rounded-lg">
        <div>
          <div class="text-sm font-medium text-gray-900">${transformation.title}</div>
          <div class="text-sm text-gray-600">${transformation.description}</div>
        </div>
        <div class="flex items-center space-x-2">
          <span class="text-xs px-2 py-1 bg-white rounded-full text-gray-600 font-medium">${transformation.impact} impact</span>
          <button type="button" class="text-xs px-3 py-1 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 transition-colors">
            Apply
          </button>
        </div>
      </div>
    `).join('')
    
    this.suggestedTransformationsTarget.innerHTML = transformationsHTML
  }

  displayColumnAnalysis(analysis) {
    if (!this.hasColumnAnalysisTableTarget) return
    
    const tbody = this.columnAnalysisTableTarget.querySelector('tbody')
    if (!tbody) return
    
    const rowsHTML = analysis.headers.map((header, index) => {
      const dataType = analysis.dataTypes[header] || 'unknown'
      const sampleValues = analysis.sampleData.map(row => row[index]).filter(val => val !== '' && val != null)
      const uniqueValues = [...new Set(sampleValues)].length
      const completeness = Math.round((sampleValues.length / analysis.lineCount) * 100)
      
      return `
        <tr>
          <td class="px-4 py-2 text-sm font-medium text-gray-900">${this.escapeHtml(header)}</td>
          <td class="px-4 py-2 text-sm text-gray-600">
            <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium ${this.getDataTypeColor(dataType)}">
              ${dataType}
            </span>
          </td>
          <td class="px-4 py-2 text-sm text-gray-600">${completeness}%</td>
          <td class="px-4 py-2 text-sm text-gray-600">${uniqueValues.toLocaleString()}</td>
          <td class="px-4 py-2 text-sm">
            <button type="button" class="text-indigo-600 hover:text-indigo-500 text-xs font-medium">
              Transform
            </button>
          </td>
        </tr>
      `
    }).join('')
    
    tbody.innerHTML = rowsHTML
  }

  getDataTypeColor(dataType) {
    const colors = {
      'text': 'bg-gray-100 text-gray-800',
      'number': 'bg-blue-100 text-blue-800',
      'date': 'bg-green-100 text-green-800',
      'boolean': 'bg-purple-100 text-purple-800',
      'unknown': 'bg-red-100 text-red-800'
    }
    return colors[dataType] || colors.unknown
  }

  renderDataTable(data, headers) {
    if (!data || data.length === 0) return '<p class="text-gray-500 text-sm">No data to preview</p>'

    const headerRow = headers.map(header => 
      `<th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">${this.escapeHtml(header)}</th>`
    ).join('')

    const dataRows = data.slice(0, 5).map(row => {
      const cells = row.map(cell => 
        `<td class="px-3 py-2 text-sm text-gray-900">${this.escapeHtml(String(cell || ''))}</td>`
      ).join('')
      return `<tr class="border-t border-gray-200">${cells}</tr>`
    }).join('')

    return `
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>${headerRow}</tr>
          </thead>
          <tbody class="bg-white">
            ${dataRows}
          </tbody>
        </table>
      </div>
    `
  }

  showUploadSuccess() {
    if (this.hasUploadStatusTarget) {
      this.uploadStatusTarget.innerHTML = `
        <div class="flex items-center p-4 bg-green-50 border border-green-200 rounded-md">
          <svg class="w-5 h-5 text-green-600 mr-3" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
          </svg>
          <span class="text-sm font-medium text-green-800">All files processed successfully!</span>
        </div>
      `
      this.uploadStatusTarget.classList.remove('hidden')
    }
  }

  showUploadError(message) {
    if (this.hasUploadStatusTarget) {
      this.uploadStatusTarget.innerHTML = `
        <div class="flex items-center p-4 bg-red-50 border border-red-200 rounded-md">
          <svg class="w-5 h-5 text-red-600 mr-3" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L10 10.586l2.707-2.707a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"></path>
          </svg>
          <span class="text-sm font-medium text-red-800">Error: ${message}</span>
        </div>
      `
      this.uploadStatusTarget.classList.remove('hidden')
    }
  }

  togglePreview(event) {
    const fileId = event.target.dataset.fileId
    const previewElement = document.querySelector(`[data-file-preview="${fileId}"]`)
    
    if (previewElement) {
      const isExpanded = previewElement.classList.contains('expanded')
      
      if (isExpanded) {
        previewElement.classList.remove('expanded')
        event.target.textContent = 'View Details'
      } else {
        previewElement.classList.add('expanded')
        event.target.textContent = 'Hide Details'
        this.showDetailedPreview(fileId)
      }
    }
  }

  showDetailedPreview(fileId) {
    const processedFile = this.processedFiles.get(fileId)
    if (!processedFile) return

    const previewElement = document.querySelector(`[data-file-preview="${fileId}"]`)
    if (!previewElement) return

    const detailsHTML = `
      <div class="mt-4 border-t border-gray-200 pt-4">
        <div class="grid grid-cols-2 gap-4 mb-4">
          <div>
            <h5 class="text-sm font-medium text-gray-900 mb-2">Data Quality</h5>
            <ul class="text-sm text-gray-600 space-y-1">
              <li>Has Headers: ${processedFile.analysis.quality.hasHeaders ? 'Yes' : 'No'}</li>
              <li>Empty Rows: ${processedFile.analysis.quality.emptyRows}</li>
              <li>Missing Values: ${processedFile.analysis.quality.missingValues}</li>
            </ul>
          </div>
          <div>
            <h5 class="text-sm font-medium text-gray-900 mb-2">Column Types</h5>
            <ul class="text-sm text-gray-600 space-y-1">
              ${Object.entries(processedFile.analysis.dataTypes).slice(0, 5).map(([col, type]) => 
                `<li>${col}: <span class="font-medium">${type}</span></li>`
              ).join('')}
            </ul>
          </div>
        </div>
      </div>
    `

    previewElement.insertAdjacentHTML('beforeend', detailsHTML)
  }

  // Public methods for external access
  getProcessedFiles() {
    return Array.from(this.processedFiles.values())
  }

  getFileAnalysis(fileId) {
    const processedFile = this.processedFiles.get(fileId)
    return processedFile ? processedFile.analysis : null
  }

  clearFiles() {
    this.files = []
    this.processedFiles.clear()
    this.uploadProgress.clear()
    this.updateFileList()
    this.updateFileInput()
    
    if (this.hasDataPreviewTarget) {
      this.dataPreviewTarget.innerHTML = ''
    }
    
    if (this.hasUploadStatusTarget) {
      this.uploadStatusTarget.classList.add('hidden')
    }
  }
}