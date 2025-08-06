import { Controller } from "@hotwired/stimulus"
import { Chart, registerables } from "chart.js"

Chart.register(...registerables)

export default class extends Controller {
  static targets = ["canvas"]
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
    const ctx = this.canvasTarget.getContext('2d')
    const chartData = this.dataValue
    
    // Prepare data for the chart
    const labels = Object.keys(chartData).map(key => {
      const date = new Date(key)
      return date.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })
    })
    
    const data = Object.values(chartData)
    
    this.chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: labels,
        datasets: [{
          label: 'Pipeline Executions',
          data: data,
          fill: true,
          backgroundColor: 'rgba(79, 70, 229, 0.1)',
          borderColor: 'rgb(79, 70, 229)',
          borderWidth: 2,
          tension: 0.4,
          pointBackgroundColor: 'rgb(79, 70, 229)',
          pointBorderColor: '#fff',
          pointBorderWidth: 2,
          pointRadius: 4,
          pointHoverRadius: 6
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          mode: 'index',
          intersect: false,
        },
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            backgroundColor: 'rgba(0, 0, 0, 0.8)',
            padding: 12,
            cornerRadius: 6,
            titleFont: {
              size: 14,
              weight: 'normal'
            },
            bodyFont: {
              size: 14,
              weight: 'bold'
            },
            callbacks: {
              title: function(context) {
                return 'Time: ' + context[0].label
              },
              label: function(context) {
                return context.parsed.y + ' executions'
              }
            }
          }
        },
        scales: {
          x: {
            display: true,
            grid: {
              display: false
            },
            ticks: {
              font: {
                size: 11
              },
              color: '#6b7280',
              maxRotation: 0,
              autoSkip: true,
              maxTicksLimit: 8
            }
          },
          y: {
            display: true,
            beginAtZero: true,
            grid: {
              color: 'rgba(0, 0, 0, 0.05)',
              drawBorder: false
            },
            ticks: {
              font: {
                size: 11
              },
              color: '#6b7280',
              padding: 8,
              stepSize: 1,
              callback: function(value) {
                if (value % 1 === 0) {
                  return value
                }
              }
            }
          }
        }
      }
    })
  }
  
  refreshChart(newData) {
    if (this.chart) {
      const labels = Object.keys(newData).map(key => {
        const date = new Date(key)
        return date.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })
      })
      
      const data = Object.values(newData)
      
      this.chart.data.labels = labels
      this.chart.data.datasets[0].data = data
      this.chart.update('active')
    }
  }
};
