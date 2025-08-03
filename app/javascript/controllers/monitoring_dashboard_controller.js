import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

export default class extends Controller {
  static targets = ["metricsChart", "pipelineChart", "resourceChart"]
  static values = { 
    metricsData: Array,
    metricsLabels: Array,
    currentMetrics: Object,
    refreshInterval: { type: Number, default: 30000 }
  }

  connect() {
    this.initializeCharts()
    this.startAutoRefresh()
  }

  disconnect() {
    this.stopAutoRefresh()
    this.destroyCharts()
  }

  initializeCharts() {
    this.initializeMetricsChart()
    this.initializePipelineChart()
    this.initializeResourceChart()
  }

  initializeMetricsChart() {
    if (!this.hasMetricsChartTarget) return

    const ctx = this.metricsChartTarget.getContext('2d')
    this.metricsChart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: this.metricsLabelsValue,
        datasets: [{
          label: 'Records/sec',
          data: this.metricsDataValue,
          borderColor: '#14B8A6',
          backgroundColor: 'rgba(20, 184, 166, 0.1)',
          tension: 0.4
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: false
          }
        },
        scales: {
          y: {
            beginAtZero: true
          }
        }
      }
    })
  }

  initializePipelineChart() {
    if (!this.hasPipelineChartTarget) return

    const ctx = this.pipelineChartTarget.getContext('2d')
    this.pipelineChart = new Chart(ctx, {
      type: 'doughnut',
      data: {
        labels: ['Completed', 'Running', 'Failed', 'Queued'],
        datasets: [{
          data: [65, 20, 10, 5], // TODO: Replace with actual data
          backgroundColor: ['#10B981', '#14B8A6', '#EF4444', '#6B7280']
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'bottom'
          }
        }
      }
    })
  }

  initializeResourceChart() {
    if (!this.hasResourceChartTarget) return

    const ctx = this.resourceChartTarget.getContext('2d')
    const metrics = this.currentMetricsValue
    
    this.resourceChart = new Chart(ctx, {
      type: 'radar',
      data: {
        labels: ['CPU', 'Memory', 'Storage', 'Network I/O', 'Queue Depth'],
        datasets: [{
          label: 'Current',
          data: [
            metrics.cpu_usage || 0,
            metrics.memory_usage || 0,
            metrics.storage_usage || 0,
            45, // TODO: Replace with actual network I/O
            30  // TODO: Replace with actual queue depth
          ],
          borderColor: '#8B5CF6',
          backgroundColor: 'rgba(139, 92, 246, 0.2)'
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          r: {
            beginAtZero: true,
            max: 100
          }
        }
      }
    })
  }

  startAutoRefresh() {
    this.refreshTimer = setInterval(() => {
      this.refresh()
    }, this.refreshIntervalValue)
  }

  stopAutoRefresh() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
    }
  }

  refresh() {
    // Turbo will handle the page refresh
    window.location.reload()
  }

  destroyCharts() {
    if (this.metricsChart) this.metricsChart.destroy()
    if (this.pipelineChart) this.pipelineChart.destroy()
    if (this.resourceChart) this.resourceChart.destroy()
  }

  // Action methods for manual controls
  manualRefresh() {
    this.refresh()
  }

  updateRefreshInterval(event) {
    const newInterval = parseInt(event.target.value) * 1000
    this.refreshIntervalValue = newInterval
    this.stopAutoRefresh()
    this.startAutoRefresh()
  }
}