import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  exportReport() {
    // Collect data for export
    const reportData = this.collectReportData()
    
    // Generate and download CSV report
    this.downloadCSV(reportData)
  }

  collectReportData() {
    const data = []
    
    // Header row
    data.push([
      "Timestamp",
      "Pipeline Name", 
      "Status",
      "Records Processed",
      "CPU Usage (%)",
      "Memory Usage (%)",
      "Duration"
    ])

    // Collect pipeline data from DOM
    document.querySelectorAll('[data-pipeline-id]').forEach(pipeline => {
      const name = pipeline.querySelector('h4')?.textContent?.trim() || 'Unknown'
      const status = pipeline.querySelector('.pipeline-status-badge')?.textContent?.trim() || 'Unknown'
      const progress = pipeline.querySelector('.progress-percentage')?.textContent?.trim() || '0%'
      
      data.push([
        new Date().toISOString(),
        name,
        status,
        progress,
        "N/A", // CPU usage would come from data attributes
        "N/A", // Memory usage would come from data attributes  
        "N/A"  // Duration would come from data attributes
      ])
    })

    return data
  }

  downloadCSV(data) {
    const csvContent = data.map(row => 
      row.map(field => `"${field}"`).join(',')
    ).join('\n')

    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' })
    const link = document.createElement('a')
    
    if (link.download !== undefined) {
      const url = URL.createObjectURL(blob)
      link.setAttribute('href', url)
      link.setAttribute('download', `monitoring-report-${new Date().toISOString().split('T')[0]}.csv`)
      link.style.visibility = 'hidden'
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)
    }
  }
}
