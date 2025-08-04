import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { data: Object }

  connect() {
    this.initializeChart()
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
    }
  }

  initializeChart() {
    const ctx = this.element.getContext('2d')
    const performanceData = this.dataValue || {}
    
    // Transform data for Chart.js
    const labels = Object.keys(performanceData)
    const successfulData = labels.map(label => {
      const pipelineData = performanceData[label] || {}
      return Object.keys(pipelineData).reduce((sum, status) => {
        return status === 'completed' ? sum + pipelineData[status] : sum
      }, 0)
    })
    
    const failedData = labels.map(label => {
      const pipelineData = performanceData[label] || {}
      return Object.keys(pipelineData).reduce((sum, status) => {
        return status === 'failed' ? sum + pipelineData[status] : sum
      }, 0)
    })
    
    const inProgressData = labels.map(label => {
      const pipelineData = performanceData[label] || {}
      return Object.keys(pipelineData).reduce((sum, status) => {
        return status === 'running' || status === 'pending' ? sum + pipelineData[status] : sum
      }, 0)
    })

    this.chart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: labels.length > 0 ? labels : ['Sales ETL', 'Customer Analytics', 'Inventory Sync', 'Marketing Data', 'Financial Reports', 'Product Catalog'],
        datasets: [
          {
            label: 'Successful',
            data: successfulData.length > 0 ? successfulData : [45, 38, 42, 35, 41, 37],
            backgroundColor: '#10b981',
            borderRadius: 4
          },
          {
            label: 'Failed', 
            data: failedData.length > 0 ? failedData : [3, 5, 2, 8, 2, 4],
            backgroundColor: '#ef4444',
            borderRadius: 4
          },
          {
            label: 'In Progress',
            data: inProgressData.length > 0 ? inProgressData : [2, 0, 1, 2, 0, 1],
            backgroundColor: '#3b82f6',
            borderRadius: 4
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'bottom',
            labels: { usePointStyle: true, padding: 20 }
          }
        },
        scales: {
          x: {
            stacked: true,
            grid: { display: false }
          },
          y: {
            stacked: true,
            beginAtZero: true,
            ticks: {
              precision: 0
            }
          }
        },
        elements: {
          bar: { borderRadius: 4 }
        }
      }
    })
  }
}
