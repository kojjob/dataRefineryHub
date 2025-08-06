import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { metrics: Array }

  connect() {
    this.initializeChart()
    this.startRealTimeUpdates()
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
    }
    if (this.updateInterval) {
      clearInterval(this.updateInterval)
    }
  }

  initializeChart() {
    const ctx = this.element.getContext('2d')
    
    // Use metrics from data value or default empty array
    const metricsData = this.metricsValue || []
    
    this.chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: metricsData.map(m => m.timestamp || ''),
        datasets: [
          {
            label: 'CPU',
            data: metricsData.map(m => m.cpu || 0),
            borderColor: '#8b5cf6',
            backgroundColor: 'rgba(139, 92, 246, 0.1)',
            tension: 0.4,
            pointRadius: 2,
            pointHoverRadius: 4,
            borderWidth: 2
          },
          {
            label: 'Memory', 
            data: metricsData.map(m => m.memory || 0),
            borderColor: '#f97316',
            backgroundColor: 'rgba(249, 115, 22, 0.1)',
            tension: 0.4,
            pointRadius: 2,
            pointHoverRadius: 4,
            borderWidth: 2
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
          y: {
            beginAtZero: true,
            max: 100,
            ticks: {
              callback: function(value) {
                return value + '%'
              }
            }
          },
          x: { 
            display: false // Hide x-axis for cleaner look
          }
        },
        elements: {
          point: { hitRadius: 8 }
        }
      }
    })
  }

  startRealTimeUpdates() {
    // Update chart every 10 seconds with new data
    this.updateInterval = setInterval(() => {
      this.updateChartData()
    }, 10000)
  }

  updateChartData() {
    // Simulate new data points (in real app, fetch from server)
    const now = new Date().toLocaleTimeString('en-US', { 
      hour12: false, 
      hour: '2-digit', 
      minute: '2-digit' 
    })
    
    const newCpuValue = Math.random() * 80 + 10 // Random value between 10-90
    const newMemoryValue = Math.random() * 70 + 15 // Random value between 15-85

    // Add new data point
    this.chart.data.labels.push(now)
    this.chart.data.datasets[0].data.push(newCpuValue)
    this.chart.data.datasets[1].data.push(newMemoryValue)

    // Keep only last 20 data points
    if (this.chart.data.labels.length > 20) {
      this.chart.data.labels.shift()
      this.chart.data.datasets[0].data.shift()
      this.chart.data.datasets[1].data.shift()
    }

    this.chart.update('none') // Update without animation for smooth real-time feel
  }
};
