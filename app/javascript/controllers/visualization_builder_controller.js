import { Controller } from "@hotwire/stimulus"
import Chart from 'chart.js/auto'

export default class extends Controller {
  static targets = [
    "canvas",
    "chartType",
    "xColumn",
    "yColumn",
    "aggregation",
    "filterColumn",
    "filterValue",
    "chartTitle",
    "preview",
    "dataTable",
    "exportBtn",
    "saveBtn"
  ]

  static values = {
    data: Array,
    columns: Array,
    dataSourceId: Number
  }

  connect() {
    this.chart = null
    this.processedData = []
    this.originalData = this.dataValue || []
    
    if (this.originalData.length > 0) {
      this.initializeBuilder()
    }
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
    }
  }

  initializeBuilder() {
    this.populateColumnSelectors()
    this.renderDefaultChart()
    this.updateDataTable()
  }

  populateColumnSelectors() {
    const columns = this.columnsValue || []
    const selectors = [this.xColumnTarget, this.yColumnTarget, this.filterColumnTarget]
    
    selectors.forEach(selector => {
      selector.innerHTML = '<option value="">Select column...</option>'
      columns.forEach(column => {
        const option = document.createElement('option')
        option.value = column
        option.textContent = this.formatColumnName(column)
        selector.appendChild(option)
      })
    })
  }

  formatColumnName(column) {
    return column.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())
  }

  renderDefaultChart() {
    if (this.originalData.length === 0) return
    
    // Auto-detect best chart type and columns
    const numericColumns = this.getNumericColumns()
    const categoryColumns = this.getCategoryColumns()
    
    if (numericColumns.length > 0 && categoryColumns.length > 0) {
      this.xColumnTarget.value = categoryColumns[0]
      this.yColumnTarget.value = numericColumns[0]
      this.aggregationTarget.value = 'sum'
      this.updateChart()
    }
  }

  getNumericColumns() {
    if (this.originalData.length === 0) return []
    
    const sample = this.originalData[0]
    return Object.keys(sample).filter(key => {
      const value = sample[key]
      return !isNaN(parseFloat(value)) && isFinite(value)
    })
  }

  getCategoryColumns() {
    if (this.originalData.length === 0) return []
    
    const sample = this.originalData[0]
    const numericColumns = this.getNumericColumns()
    return Object.keys(sample).filter(key => !numericColumns.includes(key))
  }

  updateChart() {
    const chartType = this.chartTypeTarget.value
    const xColumn = this.xColumnTarget.value
    const yColumn = this.yColumnTarget.value
    const aggregation = this.aggregationTarget.value

    if (!xColumn || !yColumn) return

    this.processedData = this.processData(xColumn, yColumn, aggregation)
    this.renderChart(chartType)
    this.updateDataTable()
  }

  processData(xColumn, yColumn, aggregation) {
    let data = [...this.originalData]
    
    // Apply filters
    const filterColumn = this.filterColumnTarget.value
    const filterValue = this.filterValueTarget.value
    
    if (filterColumn && filterValue) {
      data = data.filter(row => 
        String(row[filterColumn]).toLowerCase().includes(filterValue.toLowerCase())
      )
    }

    // Group and aggregate data
    const grouped = {}
    
    data.forEach(row => {
      const xValue = row[xColumn] || 'Unknown'
      const yValue = parseFloat(row[yColumn]) || 0
      
      if (!grouped[xValue]) {
        grouped[xValue] = []
      }
      grouped[xValue].push(yValue)
    })

    // Apply aggregation
    const result = Object.keys(grouped).map(key => ({
      x: key,
      y: this.aggregate(grouped[key], aggregation)
    }))

    return result.sort((a, b) => b.y - a.y).slice(0, 20) // Top 20 items
  }

  aggregate(values, type) {
    switch(type) {
      case 'sum':
        return values.reduce((a, b) => a + b, 0)
      case 'avg':
        return values.reduce((a, b) => a + b, 0) / values.length
      case 'count':
        return values.length
      case 'max':
        return Math.max(...values)
      case 'min':
        return Math.min(...values)
      default:
        return values.reduce((a, b) => a + b, 0)
    }
  }

  renderChart(type) {
    if (this.chart) {
      this.chart.destroy()
    }

    const ctx = this.canvasTarget.getContext('2d')
    const title = this.chartTitleTarget.value || `${this.formatColumnName(this.yColumnTarget.value)} by ${this.formatColumnName(this.xColumnTarget.value)}`

    const config = this.getChartConfig(type, title)
    this.chart = new Chart(ctx, config)
  }

  getChartConfig(type, title) {
    const labels = this.processedData.map(d => d.x)
    const data = this.processedData.map(d => d.y)
    
    const colors = this.generateColors(data.length)
    
    const baseConfig = {
      data: {
        labels: labels,
        datasets: [{
          label: this.formatColumnName(this.yColumnTarget.value),
          data: data,
          backgroundColor: type === 'line' ? colors[0] + '20' : colors,
          borderColor: type === 'line' ? colors[0] : colors.map(c => c + 'FF'),
          borderWidth: 2,
          tension: 0.4
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          title: {
            display: true,
            text: title,
            font: {
              size: 16,
              weight: 'bold'
            }
          },
          legend: {
            display: type !== 'pie' && type !== 'doughnut'
          }
        },
        scales: type === 'pie' || type === 'doughnut' ? {} : {
          y: {
            beginAtZero: true,
            grid: {
              color: 'rgba(0,0,0,0.1)'
            }
          },
          x: {
            grid: {
              color: 'rgba(0,0,0,0.1)'
            }
          }
        }
      }
    }

    return {
      type: type,
      ...baseConfig
    }
  }

  generateColors(count) {
    const colors = [
      'rgba(99, 102, 241', 'rgba(168, 85, 247', 'rgba(236, 72, 153',
      'rgba(239, 68, 68', 'rgba(245, 101, 101', 'rgba(251, 146, 60',
      'rgba(252, 211, 77', 'rgba(163, 230, 53', 'rgba(52, 211, 153',
      'rgba(56, 189, 248', 'rgba(147, 197, 253', 'rgba(196, 181, 253'
    ]
    
    const result = []
    for (let i = 0; i < count; i++) {
      result.push(colors[i % colors.length])
    }
    return result
  }

  updateDataTable() {
    if (!this.hasDataTableTarget) return
    
    const tableHtml = this.generateDataTable()
    this.dataTableTarget.innerHTML = tableHtml
  }

  generateDataTable() {
    if (this.processedData.length === 0) {
      return `
        <div class="text-center py-8">
          <div class="text-4xl mb-4">📊</div>
          <p class="text-gray-500 text-sm">No data to display</p>
          <p class="text-gray-400 text-xs mt-1">Configure your chart settings to see processed data</p>
        </div>
      `
    }

    const xLabel = this.formatColumnName(this.xColumnTarget.value)
    const yLabel = this.formatColumnName(this.yColumnTarget.value)
    
    let html = `
      <div class="overflow-x-auto">
        <table class="visualization-builder__table">
          <thead>
            <tr>
              <th>${xLabel}</th>
              <th>${yLabel}</th>
            </tr>
          </thead>
          <tbody>
    `
    
    this.processedData.slice(0, 10).forEach((row, index) => {
      html += `
        <tr>
          <td><span class="font-medium text-gray-900">${row.x}</span></td>
          <td><span class="font-semibold text-indigo-600">${this.formatValue(row.y)}</span></td>
        </tr>
      `
    })
    
    if (this.processedData.length > 10) {
      html += `
        <tr>
          <td colspan="2" class="text-center text-gray-400 text-xs py-3 italic">
            ... and ${this.processedData.length - 10} more rows
          </td>
        </tr>
      `
    }
    
    html += `
          </tbody>
        </table>
      </div>
    `
    
    return html
  }

  formatValue(value) {
    if (typeof value === 'number') {
      return value.toLocaleString(undefined, { maximumFractionDigits: 2 })
    }
    return value
  }

  exportChart() {
    if (!this.chart) return
    
    const url = this.chart.toBase64Image()
    const link = document.createElement('a')
    link.download = `${this.chartTitleTarget.value || 'chart'}.png`
    link.href = url
    link.click()
  }

  saveVisualization() {
    const config = {
      chartType: this.chartTypeTarget.value,
      xColumn: this.xColumnTarget.value,
      yColumn: this.yColumnTarget.value,
      aggregation: this.aggregationTarget.value,
      filterColumn: this.filterColumnTarget.value,
      filterValue: this.filterValueTarget.value,
      title: this.chartTitleTarget.value,
      dataSourceId: this.dataSourceIdValue
    }

    fetch('/api/v1/visualizations', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({ visualization: config })
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        this.showNotification('Visualization saved successfully!', 'success')
      } else {
        this.showNotification('Failed to save visualization', 'error')
      }
    })
    .catch(error => {
      this.showNotification('Error saving visualization', 'error')
    })
  }

  showNotification(message, type) {
    const notification = document.createElement('div')
    notification.className = `visualization-builder__notification visualization-builder__notification--${type}`
    notification.innerHTML = `
      <div class="flex items-center">
        <span class="mr-3 text-xl">${type === 'success' ? '✅' : '❌'}</span>
        <span>${message}</span>
      </div>
    `
    
    document.body.appendChild(notification)
    
    // Trigger animation
    setTimeout(() => {
      notification.classList.add('visualization-builder__notification--show')
    }, 100)
    
    // Remove notification
    setTimeout(() => {
      notification.classList.remove('visualization-builder__notification--show')
      setTimeout(() => {
        if (notification.parentNode) {
          notification.remove()
        }
      }, 300)
    }, 3000)
  }
}