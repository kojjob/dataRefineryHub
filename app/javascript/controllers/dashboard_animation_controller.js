import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "metric", "chart"]

  connect() {
    this.animateCardsOnLoad()
    this.animateMetrics()
  }

  animateCardsOnLoad() {
    this.cardTargets.forEach((card, index) => {
      card.style.opacity = "0"
      card.style.transform = "translateY(20px)"
      
      setTimeout(() => {
        card.style.transition = "all 0.6s ease-out"
        card.style.opacity = "1"
        card.style.transform = "translateY(0)"
      }, index * 100)
    })
  }

  animateMetrics() {
    this.metricTargets.forEach((metric) => {
      const finalValue = parseInt(metric.textContent.replace(/[^0-9]/g, ''))
      const increment = finalValue / 50
      let currentValue = 0
      
      const timer = setInterval(() => {
        currentValue += increment
        if (currentValue >= finalValue) {
          metric.textContent = this.formatNumber(finalValue)
          clearInterval(timer)
        } else {
          metric.textContent = this.formatNumber(Math.floor(currentValue))
        }
      }, 30)
    })
  }

  formatNumber(num) {
    if (num >= 1000000) {
      return (num / 1000000).toFixed(1) + 'M'
    } else if (num >= 1000) {
      return (num / 1000).toFixed(1) + 'K'
    }
    return num.toString()
  }

  refreshCard(event) {
    const card = event.currentTarget.closest('[data-dashboard-animation-target="card"]')
    card.style.transform = "scale(0.95)"
    
    setTimeout(() => {
      card.style.transition = "transform 0.2s ease-out"
      card.style.transform = "scale(1)"
    }, 100)
  }
}