import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { metrics: Array }

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
    const metricsData = this.metricsValue || []
    
    // Generate sample data if no real data available
    const sampleData = this.generateSampleData()
    const dataToUse = metricsData.length > 0 ? metricsData : sampleData

    this.chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: dataToUse.map(m => m.timestamp || ''),
        datasets: [
          {
            label: 'CPU Usage',
            data: dataToUse.map(m => m.cpu || 0),
            borderColor: '#8b5cf6',
            backgroundColor: 'rgba(139, 92, 246, 0.1)',
            tension: 0.3,
            pointRadius: 3,
            pointHoverRadius: 6,
            borderWidth: 2,
            fill: true
          },
          {
            label: 'Memory Usage',
            data: dataToUse.map(m => m.memory || 0),
            borderColor: '#f97316', 
            backgroundColor: 'rgba(249, 115, 22, 0.1)',
            tension: 0.3,
            pointRadius: 3,
            pointHoverRadius: 6,
            borderWidth: 2,
            fill: true
          },
          {
            label: 'Storage Usage',
            data: dataToUse.map(m => m.storage || 0),
            borderColor: '#ef4444',
            backgroundColor: 'rgba(239, 68, 68, 0.1)', 
            tension: 0.3,
            pointRadius: 3,
            pointHoverRadius: 6,
            borderWidth: 2,
            fill: true
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'bottom',
            labels: { 
              usePointStyle: true, 
              padding: 20,
              font: { size: 12 }
            }
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
            },
            grid: {
              color: 'rgba(0, 0, 0, 0.05)'
            }
          },
          x: {
            grid: {
              display: false
            },
            ticks: {
              maxTicksLimit: 8
            }
          }
        },
        elements: {
          point: { 
            hitRadius: 8,
            hoverRadius: 6
          }
        },
        interaction: {
          intersect: false,
          mode: 'index'
        }
      }
    })
  }

  generateSampleData() {
    const data = []
    const now = new Date()
    
    // Generate 24 hours of sample data points
    for (let i = 23; i >= 0; i--) {
      const time = new Date(now.getTime() - (i * 60 * 60 * 1000))
      const hour = time.getHours()
      
      // Simulate realistic usage patterns
      let baseCpu = 30 + Math.sin(hour / 24 * Math.PI * 2) * 15 + Math.random() * 10
      let baseMemory = 50 + Math.sin((hour + 6) / 24 * Math.PI * 2) * 20 + Math.random() * 10
      let baseStorage = 70 + Math.sin((hour + 12) / 24 * Math.PI * 2) * 10 + Math.random() * 5
      
      // Add some spikes during business hours (9 AM - 5 PM)
      if (hour >= 9 && hour <= 17) {
        baseCpu += Math.random() * 20
        baseMemory += Math.random() * 15
      }
      
      data.push({
        timestamp: `${hour.toString().padStart(2, '0')}:00`,
        cpu: Math.min(Math.max(baseCpu, 0), 100),
        memory: Math.min(Math.max(baseMemory, 0), 100), 
        storage: Math.min(Math.max(baseStorage, 0), 100)
      })
    }
    
    return data
  }
}
