import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]
  
  connect() {
    this.startAutoScroll()
  }

  disconnect() {
    this.stopAutoScroll()
  }

  startAutoScroll() {
    // Auto-scroll to bottom when new logs are added
    this.scrollInterval = setInterval(() => {
      if (this.hasContainerTarget) {
        this.containerTarget.scrollTop = this.containerTarget.scrollHeight
      }
    }, 5000)
  }

  stopAutoScroll() {
    if (this.scrollInterval) {
      clearInterval(this.scrollInterval)
    }
  }

  filterByLevel(event) {
    const selectedLevel = event.target.value
    const logLines = this.element.querySelectorAll('.monitoring-log-line')
    
    logLines.forEach(line => {
      const levelElement = line.querySelector('.monitoring-log-level')
      if (!levelElement) return
      
      const lineLevel = levelElement.textContent.trim()
      
      if (selectedLevel === 'all' || lineLevel === selectedLevel) {
        line.style.display = 'flex'
      } else {
        line.style.display = 'none'
      }
    })
  }

  exportLogs() {
    const logs = []
    const logLines = this.element.querySelectorAll('.monitoring-log-line')
    
    // Header row
    logs.push(['Timestamp', 'Level', 'Message'])
    
    // Extract log data
    logLines.forEach(line => {
      const timestamp = line.querySelector('.monitoring-log-timestamp')?.textContent?.trim() || ''
      const level = line.querySelector('.monitoring-log-level')?.textContent?.trim() || ''
      const message = line.querySelector('.monitoring-log-message')?.textContent?.trim() || ''
      
      logs.push([timestamp, level, message])
    })

    this.downloadCSV(logs, 'system-logs')
  }

  downloadCSV(data, filename) {
    const csvContent = data.map(row => 
      row.map(field => `"${field}"`).join(',')
    ).join('\n')

    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' })
    const link = document.createElement('a')
    
    if (link.download !== undefined) {
      const url = URL.createObjectURL(blob)
      link.setAttribute('href', url)
      link.setAttribute('download', `${filename}-${new Date().toISOString().split('T')[0]}.csv`)
      link.style.visibility = 'hidden'
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)
    }
  }

  // Simulate adding new log entries (for demo purposes)
  addLogEntry(level, message) {
    if (!this.hasContainerTarget) return
    
    const timestamp = new Date().toLocaleTimeString('en-US', { hour12: false })
    const logLine = document.createElement('div')
    logLine.className = 'flex items-start gap-3 mb-1'
    
    const levelColors = {
      'INFO': 'text-blue-400',
      'WARN': 'text-yellow-400', 
      'ERROR': 'text-red-400'
    }
    
    logLine.innerHTML = `
      <span class="text-gray-500 text-xs flex-shrink-0 w-16">${timestamp}</span>
      <span class="flex-shrink-0 w-12 font-semibold ${levelColors[level] || 'text-gray-400'}">
        ${level}
      </span>
      <span class="flex-1 text-gray-100">${message}</span>
    `
    
    this.containerTarget.appendChild(logLine)
    
    // Auto-scroll to new entry
    this.containerTarget.scrollTop = this.containerTarget.scrollHeight
    
    // Remove old entries if too many (keep last 50)
    const allLines = this.containerTarget.querySelectorAll('.flex.items-start')
    if (allLines.length > 50) {
      allLines[0].remove()
    }
  }
};
