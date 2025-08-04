import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { 
    endValue: Number,
    duration: { type: Number, default: 2000 }
  }

  connect() {
    this.startCounting()
  }

  startCounting() {
    const startValue = 0
    const endValue = this.endValueValue
    const duration = this.durationValue
    const startTime = performance.now()

    const updateCounter = (currentTime) => {
      const elapsed = currentTime - startTime
      const progress = Math.min(elapsed / duration, 1)
      
      // Easing function for smooth animation
      const easeOutQuart = 1 - Math.pow(1 - progress, 4)
      
      const currentValue = Math.floor(startValue + (endValue - startValue) * easeOutQuart)
      
      // Format number with commas
      this.element.textContent = currentValue.toLocaleString()
      
      if (progress < 1) {
        requestAnimationFrame(updateCounter)
      }
    }

    // Start the animation
    requestAnimationFrame(updateCounter)
  }
};
