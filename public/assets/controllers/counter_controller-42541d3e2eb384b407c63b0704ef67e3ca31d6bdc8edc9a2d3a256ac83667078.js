import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="counter"
export default class extends Controller {
  static targets = ["number"]
  static values = { 
    start: { type: Number, default: 0 },
    end: Number,
    duration: { type: Number, default: 2000 },
    suffix: { type: String, default: "" },
    prefix: { type: String, default: "" },
    separator: { type: String, default: "," }
  }

  connect() {
    // Set up intersection observer to trigger animation when element comes into view
    this.observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting && !this.hasAnimated) {
          this.animate()
          this.hasAnimated = true
        }
      })
    }, {
      threshold: 0.5, // Trigger when 50% of element is visible
      rootMargin: "0px 0px -100px 0px" // Start animation 100px before element enters viewport
    })

    this.observer.observe(this.element)
    this.hasAnimated = false
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
    if (this.animationFrame) {
      cancelAnimationFrame(this.animationFrame)
    }
  }

  animate() {
    const startTime = performance.now()
    const startValue = this.startValue
    const endValue = this.endValue
    const duration = this.durationValue

    // Add entrance animation class
    this.element.classList.add('counter-animating')

    const updateCounter = (currentTime) => {
      const elapsed = currentTime - startTime
      const progress = Math.min(elapsed / duration, 1)

      // Use easeOutCubic for smooth deceleration
      const easedProgress = 1 - Math.pow(1 - progress, 3)
      
      const currentValue = Math.floor(startValue + (endValue - startValue) * easedProgress)
      
      // Format the number with separators
      const formattedNumber = this.formatNumber(currentValue)
      
      // Update all number targets
      this.numberTargets.forEach(target => {
        target.textContent = this.prefixValue + formattedNumber + this.suffixValue
      })

      if (progress < 1) {
        this.animationFrame = requestAnimationFrame(updateCounter)
      } else {
        // Animation complete
        this.element.classList.remove('counter-animating')
        this.element.classList.add('counter-complete')
        
        // Ensure final value is exact
        const finalFormatted = this.formatNumber(endValue)
        this.numberTargets.forEach(target => {
          target.textContent = this.prefixValue + finalFormatted + this.suffixValue
        })
      }
    }

    this.animationFrame = requestAnimationFrame(updateCounter)
  }

  formatNumber(num) {
    if (this.separatorValue && num >= 1000) {
      return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, this.separatorValue)
    }
    return num.toString()
  }

  // Manual trigger method for testing
  trigger() {
    if (!this.hasAnimated) {
      this.animate()
      this.hasAnimated = true
    }
  }

  // Reset method to allow re-animation
  reset() {
    this.hasAnimated = false
    this.element.classList.remove('counter-animating', 'counter-complete')
    
    // Reset to start value
    const formattedStart = this.formatNumber(this.startValue)
    this.numberTargets.forEach(target => {
      target.textContent = this.prefixValue + formattedStart + this.suffixValue
    })
  }
};
