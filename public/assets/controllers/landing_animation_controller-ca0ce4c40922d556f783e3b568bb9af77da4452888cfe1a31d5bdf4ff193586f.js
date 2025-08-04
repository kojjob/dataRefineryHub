import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["counter", "feature", "testimonial", "integration"]

  connect() {
    this.observeElements()
    this.animateOnScroll()
  }

  observeElements() {
    // Create intersection observer for animations
    this.observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          this.animateElement(entry.target)
        }
      })
    }, {
      threshold: 0.1,
      rootMargin: '0px 0px -100px 0px'
    })

    // Observe all animated elements
    this.featureTargets.forEach(el => this.observer.observe(el))
    this.testimonialTargets.forEach(el => this.observer.observe(el))
    this.integrationTargets.forEach(el => this.observer.observe(el))
    this.counterTargets.forEach(el => this.observer.observe(el))
  }

  animateElement(element) {
    // Add staggered animation classes
    const delay = Array.from(element.parentNode.children).indexOf(element) * 100

    setTimeout(() => {
      element.style.transform = 'translateY(0)'
      element.style.opacity = '1'
      
      // Animate counters
      if (element.hasAttribute('data-landing-animation-target') && 
          element.getAttribute('data-landing-animation-target').includes('counter')) {
        this.animateCounter(element)
      }
    }, delay)
  }

  animateCounter(element) {
    const target = element.textContent.replace(/[^0-9.]/g, '')
    const suffix = element.textContent.replace(/[0-9.]/g, '')
    const finalValue = parseFloat(target)
    
    if (isNaN(finalValue)) return

    const increment = finalValue / 50
    let currentValue = 0
    
    const timer = setInterval(() => {
      currentValue += increment
      if (currentValue >= finalValue) {
        element.textContent = target + suffix
        clearInterval(timer)
      } else {
        element.textContent = Math.floor(currentValue) + suffix
      }
    }, 30)
  }

  animateOnScroll() {
    // Set initial state for elements
    this.featureTargets.forEach((el, index) => {
      el.style.transform = 'translateY(20px)'
      el.style.opacity = '0'
      el.style.transition = 'all 0.6s ease-out'
    })

    this.testimonialTargets.forEach((el, index) => {
      el.style.transform = 'translateY(20px)'
      el.style.opacity = '0'
      el.style.transition = 'all 0.6s ease-out'
    })

    this.integrationTargets.forEach((el, index) => {
      el.style.transform = 'translateY(20px)'
      el.style.opacity = '0'
      el.style.transition = 'all 0.6s ease-out'
    })
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }
};
