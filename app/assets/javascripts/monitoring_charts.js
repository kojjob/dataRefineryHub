document.addEventListener('DOMContentLoaded', function() {
  // Real-time Metrics Chart
  const realtimeCtx = document.getElementById('realtimeMetricsChart');
  if (realtimeCtx) {
    new Chart(realtimeCtx, {
      type: 'line',
      data: {
        labels: Array.from({length: 20}, (_, i) => `${i * 3}m`),
        datasets: [{
          label: 'CPU',
          data: Array.from({length: 20}, () => Math.floor(Math.random() * 40) + 30),
          borderColor: '#8b5cf6',
          backgroundColor: '#8b5cf640',
          tension: 0.4
        }, {
          label: 'Memory',
          data: Array.from({length: 20}, () => Math.floor(Math.random() * 30) + 50),
          borderColor: '#f59e0b',
          backgroundColor: '#f59e0b40',
          tension: 0.4
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'bottom'
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            max: 100,
            ticks: {
              callback: function(value) {
                return value + '%';
              }
            }
          }
        }
      }
    });
  }

  // Pipeline Performance Chart
  const performanceCtx = document.getElementById('pipelinePerformanceChart');
  if (performanceCtx) {
    new Chart(performanceCtx, {
      type: 'bar',
      data: {
        labels: ['Sales ETL', 'Customer Analytics', 'Inventory Sync', 'Marketing Data', 'Financial Reports', 'Product Catalog'],
        datasets: [{
          label: 'Successful',
          data: [42, 38, 40, 35, 38, 36],
          backgroundColor: '#10b981'
        }, {
          label: 'Failed',
          data: [3, 4, 5, 3, 4, 2],
          backgroundColor: '#ef4444'
        }, {
          label: 'In Progress',
          data: [5, 3, 0, 2, 0, 2],
          backgroundColor: '#3b82f6'
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          x: {
            stacked: true
          },
          y: {
            stacked: true,
            beginAtZero: true
          }
        },
        plugins: {
          legend: {
            position: 'bottom'
          }
        }
      }
    });
  }

  // Resource Utilization Chart
  const resourceCtx = document.getElementById('resourceUtilizationChart');
  if (resourceCtx) {
    new Chart(resourceCtx, {
      type: 'line',
      data: {
        labels: ['00:00', '04:00', '08:00', '12:00', '16:00', '20:00', '24:00'],
        datasets: [{
          label: 'CPU Usage',
          data: [30, 35, 45, 60, 55, 45, 40],
          borderColor: '#8b5cf6',
          backgroundColor: 'transparent',
          tension: 0.4
        }, {
          label: 'Memory Usage',
          data: [50, 55, 70, 75, 70, 65, 60],
          borderColor: '#f59e0b',
          backgroundColor: 'transparent',
          tension: 0.4
        }, {
          label: 'Storage Usage',
          data: [70, 72, 75, 78, 80, 81, 81],
          borderColor: '#ef4444',
          backgroundColor: 'transparent',
          tension: 0.4
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'bottom'
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            max: 100,
            ticks: {
              callback: function(value) {
                return value + '%';
              }
            }
          }
        }
      }
    });
  }
});