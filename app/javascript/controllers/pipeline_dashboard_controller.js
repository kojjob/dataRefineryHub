import { Controller } from "@hotwired/stimulus"
import { Chart } from "chart.js/auto"

export default class extends Controller {
  static targets = ["successRateChart"]
  
  connect() {
    this.initializeCharts()
    this.startLiveUpdates()
  }
  
  disconnect() {
    if (this.updateInterval) {
      clearInterval(this.updateInterval)
    }
    if (this.successRateChart) {
      this.successRateChart.destroy()
    }
  }
  
  initializeCharts() {
    // Success Rate Mini Chart
    const chartElement = document.getElementById('successRateChart')
    if (chartElement) {
      const ctx = chartElement.getContext('2d')
      this.successRateChart = new Chart(ctx, {
        type: 'line',
        data: {
          labels: ['', '', '', '', '', ''],
          datasets: [{
            data: [94, 96, 95, 97, 96, 98],
            borderColor: 'rgba(33, 128, 141, 0.8)',
            backgroundColor: 'rgba(33, 128, 141, 0.1)',
            borderWidth: 2,
            tension: 0.4,
            pointRadius: 0,
            pointHoverRadius: 0
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: { display: false },
            tooltip: { enabled: false }
          },
          scales: {
            x: { display: false },
            y: { display: false }
          }
        }
      })
    }
  }
  
  startLiveUpdates() {
    // Simulate live updates for running pipelines
    this.updateInterval = setInterval(() => {
      this.updateRunningPipelines()
    }, 3000)
  }
  
  updateRunningPipelines() {
    // Find all running pipeline progress bars
    const runningPipelines = this.element.querySelectorAll('.pipeline-card.running .progress-fill')
    
    runningPipelines.forEach(progressBar => {
      const currentWidth = parseInt(progressBar.style.width) || 0
      const increment = Math.random() * 5 + 1 // Random increment between 1-6%
      const newWidth = Math.min(currentWidth + increment, 100)
      
      progressBar.style.width = `${newWidth}%`
      
      // Update percentage text
      const percentageElement = progressBar.closest('.pipeline-progress').querySelector('.progress-percentage')
      if (percentageElement) {
        percentageElement.textContent = `${Math.round(newWidth)}%`
      }
      
      // Update record count
      const statItem = progressBar.closest('.pipeline-card').querySelector('.stat-item')
      if (statItem && newWidth < 100) {
        const totalRecords = 50000 // Example total
        const processedRecords = Math.round((newWidth / 100) * totalRecords)
        statItem.innerHTML = `
          <svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z" />
          </svg>
          ${processedRecords.toLocaleString()} / ${totalRecords.toLocaleString()}
        `
      }
      
      // Mark as completed if 100%
      if (newWidth >= 100) {
        const card = progressBar.closest('.pipeline-card')
        card.classList.remove('running')
        card.classList.add('completed')
        
        const statusBadge = card.querySelector('.pipeline-status-badge')
        statusBadge.classList.remove('running')
        statusBadge.classList.add('completed')
        statusBadge.innerHTML = '<span class="status-icon"></span>COMPLETED'
      }
    })
  }
  
  refreshPipelines(event) {
    event.preventDefault()
    
    // Add spinning animation to refresh button
    const button = event.currentTarget
    const svg = button.querySelector('svg')
    svg.style.animation = 'spin 1s linear'
    
    // Simulate refresh
    setTimeout(() => {
      svg.style.animation = ''
      // In production, this would fetch fresh data
      console.log('Pipelines refreshed')
    }, 1000)
  }
}