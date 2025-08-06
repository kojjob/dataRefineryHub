import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tabs", "tabContent"]
  static values = { 
    dataSourceId: String,
    previewData: Object 
  }

  connect() {
    console.log("Enhanced preview controller connected")
    this.currentTab = "overview"
    this.initializeAnimations()
  }

  switchTab(event) {
    const newTab = event.currentTarget.dataset.tab
    if (newTab === this.currentTab) return

    // Update tab buttons
    this.updateTabButtons(newTab)
    
    // Switch tab content with animation
    this.switchTabContent(newTab)
    
    this.currentTab = newTab
    
    // Track analytics
    this.trackTabSwitch(newTab)
  }

  updateTabButtons(activeTab) {
    const buttons = this.tabsTarget.querySelectorAll('.tab-button')
    
    buttons.forEach(button => {
      const isActive = button.dataset.tab === activeTab
      
      if (isActive) {
        button.classList.remove('border-transparent', 'text-gray-500')
        button.classList.add('border-blue-500', 'text-blue-600', 'active')
      } else {
        button.classList.remove('border-blue-500', 'text-blue-600', 'active')
        button.classList.add('border-transparent', 'text-gray-500')
      }
    })
  }

  switchTabContent(activeTab) {
    const contents = this.tabContentTargets
    
    contents.forEach(content => {
      const isActive = content.dataset.tab === activeTab
      
      if (isActive) {
        // Fade in new content
        content.classList.remove('hidden')
        content.classList.add('active')
        this.animateIn(content)
      } else {
        // Fade out old content
        content.classList.remove('active')
        content.classList.add('hidden')
      }
    })
  }

  animateIn(element) {
    // Add subtle fade-in animation
    element.style.opacity = '0'
    element.style.transform = 'translateY(10px)'
    
    requestAnimationFrame(() => {
      element.style.transition = 'opacity 0.3s ease, transform 0.3s ease'
      element.style.opacity = '1'
      element.style.transform = 'translateY(0)'
    })
  }

  initializeAnimations() {
    // Add progressive disclosure animations for cards
    const cards = this.element.querySelectorAll('.bg-white, .bg-gradient-to-r')
    
    cards.forEach((card, index) => {
      card.style.opacity = '0'
      card.style.transform = 'translateY(20px)'
      
      setTimeout(() => {
        card.style.transition = 'opacity 0.4s ease, transform 0.4s ease'
        card.style.opacity = '1'
        card.style.transform = 'translateY(0)'
      }, index * 100)
    })
  }

  processData(event) {
    event.preventDefault()
    
    // Show processing state
    const button = event.currentTarget
    const originalText = button.innerHTML
    button.innerHTML = '⏳ Processing...'
    button.disabled = true
    
    // Simulate processing with enhanced feedback
    this.showProcessingProgress()
    
    // In a real implementation, this would trigger the actual data processing
    setTimeout(() => {
      this.completeProcessing(button, originalText)
    }, 3000)
  }

  showProcessingProgress() {
    // Create a progress overlay
    const overlay = document.createElement('div')
    overlay.className = 'fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50'
    overlay.innerHTML = `
      <div class="bg-white rounded-lg p-8 max-w-md mx-4">
        <div class="text-center">
          <div class="animate-spin rounded-full h-16 w-16 border-4 border-blue-500 border-t-transparent mx-auto mb-4"></div>
          <h3 class="text-lg font-semibold text-gray-900 mb-2">Processing Your Data</h3>
          <p class="text-gray-600 mb-4">Applying business intelligence and quality analysis...</p>
          <div class="w-full bg-gray-200 rounded-full h-2">
            <div class="bg-blue-600 h-2 rounded-full transition-all duration-1000" style="width: 0%" data-progress-bar></div>
          </div>
          <div class="text-sm text-gray-500 mt-2" data-progress-text>Initializing...</div>
        </div>
      </div>
    `
    
    document.body.appendChild(overlay)
    this.progressOverlay = overlay
    
    // Animate progress
    this.animateProgress()
  }

  animateProgress() {
    const progressBar = this.progressOverlay.querySelector('[data-progress-bar]')
    const progressText = this.progressOverlay.querySelector('[data-progress-text]')
    
    const stages = [
      { progress: 20, text: "Parsing file structure..." },
      { progress: 40, text: "Detecting business fields..." },
      { progress: 60, text: "Analyzing data quality..." },
      { progress: 80, text: "Generating insights..." },
      { progress: 100, text: "Processing complete!" }
    ]
    
    let currentStage = 0
    const interval = setInterval(() => {
      if (currentStage < stages.length) {
        const stage = stages[currentStage]
        progressBar.style.width = `${stage.progress}%`
        progressText.textContent = stage.text
        currentStage++
      } else {
        clearInterval(interval)
      }
    }, 600)
  }

  completeProcessing(button, originalText) {
    // Remove progress overlay
    if (this.progressOverlay) {
      document.body.removeChild(this.progressOverlay)
      this.progressOverlay = null
    }
    
    // Restore button
    button.innerHTML = originalText
    button.disabled = false
    
    // Show success message
    this.showSuccessMessage()
    
    // In a real implementation, redirect to results or update the page
    setTimeout(() => {
      window.location.href = `/data_sources/${this.dataSourceIdValue}`
    }, 2000)
  }

  showSuccessMessage() {
    const message = document.createElement('div')
    message.className = 'fixed top-4 right-4 bg-green-500 text-white px-6 py-3 rounded-lg shadow-lg z-50 transform translate-x-full transition-transform duration-300'
    message.innerHTML = `
      <div class="flex items-center">
        <span class="text-xl mr-2">✅</span>
        <span>Data processed successfully!</span>
      </div>
    `
    
    document.body.appendChild(message)
    
    // Animate in
    setTimeout(() => {
      message.classList.remove('translate-x-full')
    }, 100)
    
    // Animate out
    setTimeout(() => {
      message.classList.add('translate-x-full')
      setTimeout(() => {
        document.body.removeChild(message)
      }, 300)
    }, 3000)
  }

  downloadReport(event) {
    event.preventDefault()
    
    // Show loading state
    const button = event.currentTarget
    const originalText = button.innerHTML
    button.innerHTML = '📄 Generating...'
    button.disabled = true
    
    // Generate and download report
    this.generateReport().then(reportContent => {
      this.downloadFile(reportContent, 'data-preview-report.html')
      
      // Restore button
      button.innerHTML = originalText
      button.disabled = false
      
      // Show download success
      this.showDownloadSuccess()
    })
  }

  async generateReport() {
    // Generate a comprehensive HTML report
    const reportData = this.previewDataValue || {}
    
    const reportHtml = `
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Data Preview Report</title>
        <style>
          body { font-family: Arial, sans-serif; margin: 40px; line-height: 1.6; }
          .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 8px; margin-bottom: 30px; }
          .section { margin-bottom: 30px; padding: 20px; border: 1px solid #e5e7eb; border-radius: 8px; }
          .metric { display: inline-block; margin: 10px; padding: 15px; background: #f9fafb; border-radius: 6px; }
          .quality-score { font-size: 2em; font-weight: bold; color: #059669; }
          table { width: 100%; border-collapse: collapse; margin-top: 15px; }
          th, td { padding: 12px; text-align: left; border-bottom: 1px solid #e5e7eb; }
          th { background-color: #f9fafb; font-weight: 600; }
          .insight { background: #eff6ff; padding: 15px; border-left: 4px solid #3b82f6; margin: 10px 0; }
        </style>
      </head>
      <body>
        <div class="header">
          <h1>📊 Enhanced Data Preview Report</h1>
          <p>Generated on ${new Date().toLocaleDateString()}</p>
          <p><strong>File:</strong> ${reportData.file_info?.name || 'Unknown'} (${reportData.file_info?.size || 'Unknown size'})</p>
        </div>
        
        <div class="section">
          <h2>📈 Executive Summary</h2>
          <div class="metric">
            <strong>Data Quality Grade:</strong> 
            <span class="quality-score">${reportData.data_quality?.grade || 'N/A'}</span>
          </div>
          <div class="metric">
            <strong>Business Impact:</strong> ${reportData.business_impact?.impact_level || 'TBD'}
          </div>
          <div class="metric">
            <strong>Processing Complexity:</strong> ${reportData.file_info?.processing_complexity || 'Unknown'}
          </div>
          <div class="insight">
            <strong>Primary Business Area:</strong> ${reportData.business_insights?.primary_business_area || 'General Business Intelligence'}
          </div>
        </div>
        
        <div class="section">
          <h2>🎯 Business Insights</h2>
          ${this.generateBusinessInsightsSection(reportData.business_insights)}
        </div>
        
        <div class="section">
          <h2>✅ Data Quality Analysis</h2>
          ${this.generateQualitySection(reportData.data_quality)}
        </div>
        
        <div class="section">
          <h2>🚀 Recommended Actions</h2>
          ${this.generateActionsSection(reportData.next_steps)}
        </div>
        
        <div class="section">
          <h2>📊 Technical Details</h2>
          <table>
            <tr><th>Metric</th><th>Value</th></tr>
            <tr><td>Total Rows</td><td>${reportData.structure_summary?.total_rows || 0}</td></tr>
            <tr><td>Total Columns</td><td>${reportData.structure_summary?.total_columns || 0}</td></tr>
            <tr><td>Estimated Processing Time</td><td>${reportData.structure_summary?.estimated_processing_time || 'Calculating...'}</td></tr>
            <tr><td>Data Density</td><td>${reportData.structure_summary?.data_density || 'Unknown'}</td></tr>
          </table>
        </div>
        
        <footer style="margin-top: 40px; padding-top: 20px; border-top: 1px solid #e5e7eb; text-align: center; color: #6b7280;">
          <p>Report generated by Data Refinery Platform Enhanced Preview System</p>
        </footer>
      </body>
      </html>
    `
    
    return reportHtml
  }

  generateBusinessInsightsSection(insights) {
    if (!insights) return '<p>Business insights will be available after processing.</p>'
    
    let html = ''
    
    if (insights.detected_entities?.length) {
      html += '<h3>Detected Business Fields:</h3><ul>'
      insights.detected_entities.forEach(entity => {
        html += `<li>${entity.toString().replace('_', ' ').toUpperCase()}</li>`
      })
      html += '</ul>'
    }
    
    if (insights.analysis_opportunities?.length) {
      html += '<h3>Analysis Opportunities:</h3><ul>'
      insights.analysis_opportunities.forEach(opportunity => {
        html += `<li>${opportunity}</li>`
      })
      html += '</ul>'
    }
    
    return html || '<p>Business insights analysis pending.</p>'
  }

  generateQualitySection(quality) {
    if (!quality) return '<p>Quality analysis will be available after processing.</p>'
    
    let html = `<p><strong>Overall Score:</strong> ${quality.overall_score || 0}/100</p>`
    
    if (quality.metrics) {
      html += '<h3>Quality Metrics:</h3><table>'
      html += '<tr><th>Metric</th><th>Score</th></tr>'
      Object.entries(quality.metrics).forEach(([metric, score]) => {
        html += `<tr><td>${metric.replace('_', ' ').toUpperCase()}</td><td>${score}%</td></tr>`
      })
      html += '</table>'
    }
    
    if (quality.recommendations?.length) {
      html += '<h3>Recommendations:</h3><ul>'
      quality.recommendations.forEach(rec => {
        html += `<li>${rec}</li>`
      })
      html += '</ul>'
    }
    
    return html
  }

  generateActionsSection(nextSteps) {
    if (!nextSteps) return '<p>Action recommendations will be available after processing.</p>'
    
    let html = ''
    
    if (nextSteps.immediate_actions?.length) {
      html += '<h3>Immediate Actions:</h3><ul>'
      nextSteps.immediate_actions.forEach(action => {
        html += `<li><strong>${action.action}:</strong> ${action.description} (${action.estimated_time})</li>`
      })
      html += '</ul>'
    }
    
    if (nextSteps.short_term_opportunities?.length) {
      html += '<h3>Short-term Opportunities:</h3><ul>'
      nextSteps.short_term_opportunities.forEach(opportunity => {
        html += `<li><strong>${opportunity.action}:</strong> ${opportunity.description} (${opportunity.estimated_time})</li>`
      })
      html += '</ul>'
    }
    
    return html || '<p>Action recommendations pending analysis.</p>'
  }

  downloadFile(content, filename) {
    const blob = new Blob([content], { type: 'text/html' })
    const url = window.URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = filename
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    window.URL.revokeObjectURL(url)
  }

  showDownloadSuccess() {
    const message = document.createElement('div')
    message.className = 'fixed top-4 right-4 bg-blue-500 text-white px-6 py-3 rounded-lg shadow-lg z-50 transform translate-x-full transition-transform duration-300'
    message.innerHTML = `
      <div class="flex items-center">
        <span class="text-xl mr-2">📄</span>
        <span>Report downloaded successfully!</span>
      </div>
    `
    
    document.body.appendChild(message)
    
    setTimeout(() => {
      message.classList.remove('translate-x-full')
    }, 100)
    
    setTimeout(() => {
      message.classList.add('translate-x-full')
      setTimeout(() => {
        document.body.removeChild(message)
      }, 300)
    }, 3000)
  }

  retryPreview(event) {
    event.preventDefault()
    
    // Show retry loading state
    const button = event.currentTarget
    button.innerHTML = '🔄 Retrying...'
    button.disabled = true
    
    // Reload the page to retry
    setTimeout(() => {
      window.location.reload()
    }, 1000)
  }

  contactSupport(event) {
    event.preventDefault()
    
    // Open support modal or redirect
    const supportUrl = '/support/contact?issue=data-preview-error'
    window.open(supportUrl, '_blank')
  }

  trackTabSwitch(tabName) {
    // Track analytics if available
    if (typeof gtag !== 'undefined') {
      gtag('event', 'preview_tab_switch', {
        'tab_name': tabName,
        'data_source_id': this.dataSourceIdValue
      })
    }
    
    console.log(`Tab switched to: ${tabName}`)
  }

  // Keyboard navigation support
  handleKeydown(event) {
    if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') {
      event.preventDefault()
      
      const tabs = ['overview', 'business', 'quality', 'preview', 'next-steps']
      const currentIndex = tabs.indexOf(this.currentTab)
      
      let newIndex
      if (event.key === 'ArrowLeft') {
        newIndex = currentIndex > 0 ? currentIndex - 1 : tabs.length - 1
      } else {
        newIndex = currentIndex < tabs.length - 1 ? currentIndex + 1 : 0
      }
      
      const newTab = tabs[newIndex]
      this.updateTabButtons(newTab)
      this.switchTabContent(newTab)
      this.currentTab = newTab
    }
  }

  disconnect() {
    // Clean up any remaining overlays
    if (this.progressOverlay) {
      document.body.removeChild(this.progressOverlay)
    }
  }
};
