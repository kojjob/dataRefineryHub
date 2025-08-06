import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

export default class extends Controller {
  static targets = ["revenue", "customer"]
  
  connect() {
    this.initializeCharts()
    
    // Listen for theme changes
    this.handleThemeChange = (event) => {
      this.updateTheme()
    }
    window.addEventListener('theme:changed', this.handleThemeChange)
  }
  
  disconnect() {
    // Destroy charts to prevent memory leaks
    if (this.revenueChart) this.revenueChart.destroy()
    if (this.customerChart) this.customerChart.destroy()
    
    // Remove theme change listener
    window.removeEventListener('theme:changed', this.handleThemeChange)
  }
  
  initializeCharts() {
    // Get the current theme - FIXED: use data-color-scheme instead of data-theme
    const isDarkMode = document.documentElement.getAttribute('data-color-scheme') === 'dark'

    // Set Chart.js defaults based on theme
    Chart.defaults.color = isDarkMode ? '#F5F5F5' : '#13343B'
    Chart.defaults.borderColor = isDarkMode ? 'rgba(119, 124, 124, 0.2)' : 'rgba(94, 82, 64, 0.2)'
    
    // Initialize Revenue Chart
    if (this.hasRevenueTarget) {
      const ctx = this.revenueTarget.getContext('2d')
      this.revenueChart = new Chart(ctx, {
        type: 'line',
        data: {
          labels: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
          datasets: [
            {
              label: 'Current Revenue',
              data: [125000, 138000, 142000, 155000, 168000, 175000],
              borderColor: isDarkMode ? 'rgba(50, 184, 198, 1)' : 'rgba(33, 128, 141, 1)',
              backgroundColor: isDarkMode ? 'rgba(50, 184, 198, 0.1)' : 'rgba(33, 128, 141, 0.1)',
              borderWidth: 3,
              tension: 0.4,
              fill: true
            },
            {
              label: 'Predicted Revenue',
              data: [null, null, null, null, null, 175000, 180000, 195000, 208000, 225000, 240000, 255000],
              borderColor: isDarkMode ? 'rgba(230, 129, 97, 1)' : 'rgba(168, 75, 47, 1)',
              backgroundColor: isDarkMode ? 'rgba(230, 129, 97, 0.1)' : 'rgba(168, 75, 47, 0.1)',
              borderWidth: 3,
              borderDash: [5, 5],
              tension: 0.4,
              fill: false
            }
          ]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: {
              display: true,
              position: 'top',
              labels: {
                usePointStyle: true,
                padding: 15,
                font: {
                  size: 12
                }
              }
            },
            tooltip: {
              backgroundColor: isDarkMode ? 'rgba(38, 40, 40, 0.9)' : 'rgba(255, 255, 253, 0.9)',
              titleColor: isDarkMode ? '#F5F5F5' : '#13343B',
              bodyColor: isDarkMode ? '#F5F5F5' : '#13343B',
              borderColor: isDarkMode ? 'rgba(119, 124, 124, 0.3)' : 'rgba(94, 82, 64, 0.2)',
              borderWidth: 1,
              cornerRadius: 8,
              padding: 12,
              displayColors: true,
              callbacks: {
                label: function(context) {
                  let label = context.dataset.label || ''
                  if (label) {
                    label += ': '
                  }
                  if (context.parsed.y !== null) {
                    label += new Intl.NumberFormat('en-GB', { style: 'currency', currency: 'GBP' }).format(context.parsed.y)
                  }
                  return label
                }
              }
            }
          },
          scales: {
            x: {
              grid: {
                display: false
              },
              ticks: {
                font: {
                  size: 11
                }
              }
            },
            y: {
              beginAtZero: true,
              grid: {
                color: isDarkMode ? 'rgba(119, 124, 124, 0.1)' : 'rgba(94, 82, 64, 0.1)'
              },
              ticks: {
                font: {
                  size: 11
                },
                callback: function(value) {
                  return '£' + (value / 1000) + 'K'
                }
              }
            }
          }
        }
      })
    }
    
    // Initialize Customer Chart
    if (this.hasCustomerTarget) {
      const ctx = this.customerTarget.getContext('2d')
      this.customerChart = new Chart(ctx, {
        type: 'bar',
        data: {
          labels: ['Week 1', 'Week 2', 'Week 3', 'Week 4'],
          datasets: [{
            label: 'New Customers',
            data: [245, 287, 312, 298],
            backgroundColor: isDarkMode ? [
              'rgba(50, 184, 198, 0.8)',
              'rgba(230, 129, 97, 0.8)',
              'rgba(167, 169, 169, 0.8)',
              'rgba(255, 84, 89, 0.8)'
            ] : [
              'rgba(33, 128, 141, 0.8)',
              'rgba(168, 75, 47, 0.8)',
              'rgba(98, 108, 113, 0.8)',
              'rgba(192, 21, 47, 0.8)'
            ],
            borderWidth: 0,
            borderRadius: 8
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: {
              display: false
            },
            tooltip: {
              backgroundColor: isDarkMode ? 'rgba(38, 40, 40, 0.9)' : 'rgba(255, 255, 253, 0.9)',
              titleColor: isDarkMode ? '#F5F5F5' : '#13343B',
              bodyColor: isDarkMode ? '#F5F5F5' : '#13343B',
              borderColor: isDarkMode ? 'rgba(119, 124, 124, 0.3)' : 'rgba(94, 82, 64, 0.2)',
              borderWidth: 1,
              cornerRadius: 8,
              padding: 12
            }
          },
          scales: {
            x: {
              grid: {
                display: false
              },
              ticks: {
                font: {
                  size: 11
                }
              }
            },
            y: {
              beginAtZero: true,
              grid: {
                color: isDarkMode ? 'rgba(119, 124, 124, 0.1)' : 'rgba(94, 82, 64, 0.1)'
              },
              ticks: {
                font: {
                  size: 11
                }
              }
            }
          }
        }
      })
    }
  }
  
  // Update charts when theme changes
  updateTheme() {
    // Destroy existing charts
    if (this.revenueChart) this.revenueChart.destroy()
    if (this.customerChart) this.customerChart.destroy()
    
    // Reinitialize with new theme
    this.initializeCharts()
  }
};
