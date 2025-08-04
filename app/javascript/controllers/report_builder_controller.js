import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "canvas", 
    "sidebar", 
    "propertiesPanel", 
    "componentLibrary",
    "canvasContent"
  ]
  
  static values = {
    templateId: Number,
    gridSize: { type: Number, default: 24 }
  }

  connect() {
    console.log("Report Builder connected")
    this.selectedComponent = null
    this.isDragging = false
    this.isResizing = false
    this.dragOffset = { x: 0, y: 0 }
    this.components = new Map()
    
    this.setupEventListeners()
    this.loadComponents()
  }

  setupEventListeners() {
    // Component library drag events
    this.componentLibraryTarget.addEventListener('dragstart', this.handleDragStart.bind(this))
    this.componentLibraryTarget.addEventListener('dragend', this.handleDragEnd.bind(this))
    
    // Canvas drop events
    this.canvasContentTarget.addEventListener('dragover', this.handleDragOver.bind(this))
    this.canvasContentTarget.addEventListener('drop', this.handleDrop.bind(this))
    
    // Canvas click events
    this.canvasContentTarget.addEventListener('click', this.handleCanvasClick.bind(this))
    
    // Document events
    document.addEventListener('mousemove', this.handleMouseMove.bind(this))
    document.addEventListener('mouseup', this.handleMouseUp.bind(this))
    document.addEventListener('keydown', this.handleKeyDown.bind(this))
  }

  // Drag and Drop for Component Library
  handleDragStart(event) {
    if (!event.target.closest('.component-item')) return
    
    const componentItem = event.target.closest('.component-item')
    const componentType = componentItem.dataset.componentType
    
    event.dataTransfer.setData('text/plain', componentType)
    event.dataTransfer.effectAllowed = 'copy'
    
    // Create drag preview
    const dragPreview = componentItem.cloneNode(true)
    dragPreview.style.transform = 'rotate(5deg)'
    dragPreview.style.opacity = '0.8'
    event.dataTransfer.setDragImage(dragPreview, 50, 50)
  }

  handleDragEnd(event) {
    // Cleanup after drag
  }

  handleDragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = 'copy'
  }

  handleDrop(event) {
    event.preventDefault()
    
    const componentType = event.dataTransfer.getData('text/plain')
    if (!componentType) return
    
    const rect = this.canvasContentTarget.getBoundingClientRect()
    const x = Math.round((event.clientX - rect.left) / this.gridSizeValue) * this.gridSizeValue
    const y = Math.round((event.clientY - rect.top) / this.gridSizeValue) * this.gridSizeValue
    
    this.addComponent(componentType, x, y)
  }

  // Component Management
  addComponent(type, x, y) {
    const componentId = `component_${Date.now()}`
    const defaultProps = this.getDefaultProperties(type)
    
    const componentData = {
      id: componentId,
      type: type,
      position_x: x,
      position_y: y,
      width: defaultProps.width,
      height: defaultProps.height,
      properties: defaultProps.properties,
      styling: defaultProps.styling
    }
    
    // Send to server
    fetch(`/report_builder/${this.templateIdValue}/add_component`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({
        component: componentData
      })
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        this.renderComponent(data.component)
        this.selectComponent(data.component.id)
      }
    })
    .catch(error => {
      console.error('Error adding component:', error)
    })
  }

  renderComponent(component) {
    const element = document.createElement('div')
    element.className = 'report-component'
    element.dataset.componentId = component.id
    element.dataset.componentType = component.component_type
    element.style.left = `${component.position_x}px`
    element.style.top = `${component.position_y}px`
    element.style.width = `${component.width * this.gridSizeValue}px`
    element.style.height = `${component.height * this.gridSizeValue}px`
    element.style.zIndex = component.z_index || 0
    
    // Add component content
    element.innerHTML = this.getComponentHTML(component)
    
    // Add controls
    this.addComponentControls(element)
    
    // Add resize handles
    this.addResizeHandles(element)
    
    // Add event listeners
    this.addComponentEventListeners(element)
    
    this.canvasContentTarget.appendChild(element)
    this.components.set(component.id, component)
  }

  getComponentHTML(component) {
    // This would typically fetch the rendered HTML from the server
    // For now, return a placeholder
    switch (component.component_type) {
      case 'chart':
        return `
          <div class="chart-placeholder">
            <div class="placeholder-icon">📊</div>
            <div class="placeholder-text">${component.properties.title || 'Chart'}</div>
          </div>
        `
      case 'metric':
        return `
          <div class="metric-widget">
            <div class="metric-label">${component.properties.title || 'Metric'}</div>
            <div class="metric-value">${component.properties.sample_value || '0'}</div>
          </div>
        `
      case 'table':
        return `
          <div class="table-placeholder">
            <div class="placeholder-icon">📋</div>
            <div class="placeholder-text">${component.properties.title || 'Table'}</div>
          </div>
        `
      case 'text':
        return `
          <div class="text-component">
            <p>${component.properties.content || 'Text content'}</p>
          </div>
        `
      case 'filter':
        return `
          <div class="filter-component">
            <div class="filter-icon">🔍</div>
            <div class="filter-title">${component.properties.title || 'Filter'}</div>
          </div>
        `
      default:
        return `<div class="placeholder">Component</div>`
    }
  }

  addComponentControls(element) {
    const controls = document.createElement('div')
    controls.className = 'component-controls'
    controls.innerHTML = `
      <button class="control-btn" data-action="edit" title="Edit">✏️</button>
      <button class="control-btn" data-action="duplicate" title="Duplicate">📋</button>
      <button class="control-btn" data-action="delete" title="Delete">🗑️</button>
    `
    element.appendChild(controls)
  }

  addResizeHandles(element) {
    const handles = ['nw', 'n', 'ne', 'e', 'se', 's', 'sw', 'w']
    handles.forEach(handle => {
      const handleElement = document.createElement('div')
      handleElement.className = `resize-handle ${handle}`
      handleElement.dataset.handle = handle
      element.appendChild(handleElement)
    })
  }

  addComponentEventListeners(element) {
    // Click to select
    element.addEventListener('click', (e) => {
      e.stopPropagation()
      this.selectComponent(element.dataset.componentId)
    })
    
    // Control buttons
    element.addEventListener('click', (e) => {
      if (e.target.matches('[data-action="delete"]')) {
        e.stopPropagation()
        this.deleteComponent(element.dataset.componentId)
      } else if (e.target.matches('[data-action="duplicate"]')) {
        e.stopPropagation()
        this.duplicateComponent(element.dataset.componentId)
      } else if (e.target.matches('[data-action="edit"]')) {
        e.stopPropagation()
        this.editComponent(element.dataset.componentId)
      }
    })
    
    // Drag to move
    element.addEventListener('mousedown', (e) => {
      if (e.target.classList.contains('resize-handle')) {
        this.startResize(e, element)
      } else if (!e.target.closest('.component-controls')) {
        this.startDrag(e, element)
      }
    })
  }

  // Component Selection
  selectComponent(componentId) {
    // Remove previous selection
    document.querySelectorAll('.report-component.selected').forEach(el => {
      el.classList.remove('selected')
    })
    
    // Select new component
    const element = document.querySelector(`[data-component-id="${componentId}"]`)
    if (element) {
      element.classList.add('selected')
      this.selectedComponent = componentId
      this.loadPropertiesPanel(componentId)
    }
  }

  deselectComponent() {
    document.querySelectorAll('.report-component.selected').forEach(el => {
      el.classList.remove('selected')
    })
    this.selectedComponent = null
    this.clearPropertiesPanel()
  }

  // Component Operations
  deleteComponent(componentId) {
    if (confirm('Are you sure you want to delete this component?')) {
      fetch(`/report_builder/${this.templateIdValue}/components/${componentId}`, {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })
      .then(response => response.json())
      .then(data => {
        if (data.success) {
          const element = document.querySelector(`[data-component-id="${componentId}"]`)
          if (element) {
            element.remove()
          }
          this.components.delete(componentId)
          if (this.selectedComponent === componentId) {
            this.deselectComponent()
          }
        }
      })
    }
  }

  duplicateComponent(componentId) {
    const component = this.components.get(componentId)
    if (component) {
      this.addComponent(component.component_type, component.position_x + 50, component.position_y + 50)
    }
  }

  editComponent(componentId) {
    this.selectComponent(componentId)
    // Could open a modal or focus properties panel
  }

  // Drag and Move
  startDrag(event, element) {
    if (event.button !== 0) return // Only left mouse button
    
    this.isDragging = true
    this.dragElement = element
    
    const rect = element.getBoundingClientRect()
    const canvasRect = this.canvasContentTarget.getBoundingClientRect()
    
    this.dragOffset = {
      x: event.clientX - rect.left,
      y: event.clientY - rect.top
    }
    
    element.classList.add('dragging')
    document.body.style.cursor = 'grabbing'
    
    event.preventDefault()
  }

  handleMouseMove(event) {
    if (this.isDragging && this.dragElement) {
      const canvasRect = this.canvasContentTarget.getBoundingClientRect()
      let x = event.clientX - canvasRect.left - this.dragOffset.x
      let y = event.clientY - canvasRect.top - this.dragOffset.y
      
      // Snap to grid
      x = Math.round(x / this.gridSizeValue) * this.gridSizeValue
      y = Math.round(y / this.gridSizeValue) * this.gridSizeValue
      
      // Keep within bounds
      x = Math.max(0, Math.min(x, canvasRect.width - this.dragElement.offsetWidth))
      y = Math.max(0, Math.min(y, canvasRect.height - this.dragElement.offsetHeight))
      
      this.dragElement.style.left = `${x}px`
      this.dragElement.style.top = `${y}px`
    }
    
    if (this.isResizing && this.resizeElement) {
      this.handleResize(event)
    }
  }

  handleMouseUp(event) {
    if (this.isDragging && this.dragElement) {
      this.isDragging = false
      this.dragElement.classList.remove('dragging')
      document.body.style.cursor = ''
      
      // Save position to server
      this.saveComponentPosition(this.dragElement.dataset.componentId)
      
      this.dragElement = null
    }
    
    if (this.isResizing && this.resizeElement) {
      this.isResizing = false
      this.resizeElement = null
      this.resizeHandle = null
      document.body.style.cursor = ''
      
      // Save size to server
      this.saveComponentSize(this.resizeElement?.dataset.componentId)
    }
  }

  // Resize
  startResize(event, element) {
    if (event.button !== 0) return
    
    this.isResizing = true
    this.resizeElement = element
    this.resizeHandle = event.target.dataset.handle
    
    const rect = element.getBoundingClientRect()
    this.resizeStart = {
      x: event.clientX,
      y: event.clientY,
      width: rect.width,
      height: rect.height,
      left: rect.left,
      top: rect.top
    }
    
    event.preventDefault()
    event.stopPropagation()
  }

  handleResize(event) {
    if (!this.isResizing || !this.resizeElement) return
    
    const deltaX = event.clientX - this.resizeStart.x
    const deltaY = event.clientY - this.resizeStart.y
    
    let newWidth = this.resizeStart.width
    let newHeight = this.resizeStart.height
    let newLeft = this.resizeElement.offsetLeft
    let newTop = this.resizeElement.offsetTop
    
    const handle = this.resizeHandle
    
    if (handle.includes('e')) newWidth += deltaX
    if (handle.includes('w')) {
      newWidth -= deltaX
      newLeft += deltaX
    }
    if (handle.includes('s')) newHeight += deltaY
    if (handle.includes('n')) {
      newHeight -= deltaY
      newTop += deltaY
    }
    
    // Minimum size constraints
    newWidth = Math.max(this.gridSizeValue * 2, newWidth)
    newHeight = Math.max(this.gridSizeValue * 2, newHeight)
    
    // Snap to grid
    newWidth = Math.round(newWidth / this.gridSizeValue) * this.gridSizeValue
    newHeight = Math.round(newHeight / this.gridSizeValue) * this.gridSizeValue
    
    this.resizeElement.style.width = `${newWidth}px`
    this.resizeElement.style.height = `${newHeight}px`
    
    if (handle.includes('w') || handle.includes('n')) {
      newLeft = Math.round(newLeft / this.gridSizeValue) * this.gridSizeValue
      newTop = Math.round(newTop / this.gridSizeValue) * this.gridSizeValue
      this.resizeElement.style.left = `${newLeft}px`
      this.resizeElement.style.top = `${newTop}px`
    }
  }

  // Canvas Events
  handleCanvasClick(event) {
    if (event.target === this.canvasContentTarget) {
      this.deselectComponent()
    }
  }

  handleKeyDown(event) {
    if (event.key === 'Delete' && this.selectedComponent) {
      this.deleteComponent(this.selectedComponent)
    } else if (event.key === 'Escape') {
      this.deselectComponent()
    }
  }

  // Properties Panel
  loadPropertiesPanel(componentId) {
    const component = this.components.get(componentId)
    if (!component) return
    
    fetch(`/report_builder/${this.templateIdValue}/components/${componentId}/properties`)
      .then(response => response.text())
      .then(html => {
        this.propertiesPanelTarget.innerHTML = html
        this.bindPropertiesEvents()
      })
  }

  clearPropertiesPanel() {
    this.propertiesPanelTarget.innerHTML = `
      <div class="properties-header">
        <h3>Properties</h3>
        <p>Select a component to edit its properties</p>
      </div>
    `
  }

  bindPropertiesEvents() {
    const inputs = this.propertiesPanelTarget.querySelectorAll('input, select, textarea')
    inputs.forEach(input => {
      input.addEventListener('change', this.handlePropertyChange.bind(this))
    })
  }

  handlePropertyChange(event) {
    if (!this.selectedComponent) return
    
    const property = event.target.name
    const value = event.target.value
    
    // Update component
    this.updateComponentProperty(this.selectedComponent, property, value)
  }

  updateComponentProperty(componentId, property, value) {
    fetch(`/report_builder/${this.templateIdValue}/components/${componentId}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({
        component: {
          [property]: value
        }
      })
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        // Update local component data
        const component = this.components.get(componentId)
        if (component) {
          if (property.startsWith('properties.')) {
            const propName = property.replace('properties.', '')
            component.properties[propName] = value
          } else {
            component[property] = value
          }
        }
        
        // Re-render component
        this.refreshComponent(componentId)
      }
    })
  }

  refreshComponent(componentId) {
    const element = document.querySelector(`[data-component-id="${componentId}"]`)
    const component = this.components.get(componentId)
    
    if (element && component) {
      // Update the content while preserving controls and handles
      const content = element.querySelector('.component-content') || element
      content.innerHTML = this.getComponentHTML(component)
    }
  }

  // Server Communication
  saveComponentPosition(componentId) {
    const element = document.querySelector(`[data-component-id="${componentId}"]`)
    if (!element) return
    
    const x = parseInt(element.style.left)
    const y = parseInt(element.style.top)
    
    fetch(`/report_builder/${this.templateIdValue}/components/${componentId}/move`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({
        position_x: x,
        position_y: y
      })
    })
  }

  saveComponentSize(componentId) {
    const element = document.querySelector(`[data-component-id="${componentId}"]`)
    if (!element) return
    
    const width = Math.round(element.offsetWidth / this.gridSizeValue)
    const height = Math.round(element.offsetHeight / this.gridSizeValue)
    
    fetch(`/report_builder/${this.templateIdValue}/components/${componentId}/resize`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({
        width: width,
        height: height
      })
    })
  }

  // Utilities
  getDefaultProperties(type) {
    const defaults = {
      chart: {
        width: 6,
        height: 4,
        properties: {
          title: 'New Chart',
          chart_type: 'bar',
          show_legend: true,
          show_grid: true
        },
        styling: {
          background: '#ffffff',
          border: '1px solid #e5e7eb'
        }
      },
      metric: {
        width: 3,
        height: 2,
        properties: {
          title: 'New Metric',
          format: 'number',
          show_trend: true,
          sample_value: '0'
        },
        styling: {
          background: '#ffffff',
          text_color: '#111827'
        }
      },
      table: {
        width: 8,
        height: 6,
        properties: {
          title: 'New Table',
          show_pagination: true,
          rows_per_page: 10
        },
        styling: {
          background: '#ffffff'
        }
      },
      text: {
        width: 4,
        height: 2,
        properties: {
          content: 'New text component',
          text_type: 'paragraph',
          alignment: 'left'
        },
        styling: {
          background: 'transparent',
          color: '#111827'
        }
      },
      filter: {
        width: 3,
        height: 3,
        properties: {
          title: 'New Filter',
          filter_type: 'search',
          placeholder: 'Enter search term...'
        },
        styling: {
          background: '#f9fafb'
        }
      }
    }
    
    return defaults[type] || defaults.text
  }

  loadComponents() {
    // Load existing components from the server
    fetch(`/report_builder/${this.templateIdValue}/components`)
      .then(response => response.json())
      .then(components => {
        components.forEach(component => {
          this.renderComponent(component)
        })
      })
  }
}
