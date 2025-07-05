import { Controller } from "@hotwired/stimulus"

// Magnetic button effect that follows cursor movement
export default class extends Controller {
  static values = { strength: Number }
  
  connect() {
    this.strengthValue = this.strengthValue || 0.25
    this.boundingRect = this.element.getBoundingClientRect()
    
    // Update bounding rect on window resize
    this.resizeHandler = () => {
      this.boundingRect = this.element.getBoundingClientRect()
    }
    window.addEventListener('resize', this.resizeHandler)
  }
  
  disconnect() {
    window.removeEventListener('resize', this.resizeHandler)
  }
  
  mouseMove(event) {
    const x = event.clientX - this.boundingRect.left - this.boundingRect.width / 2
    const y = event.clientY - this.boundingRect.top - this.boundingRect.height / 2
    
    const translateX = x * this.strengthValue
    const translateY = y * this.strengthValue
    
    this.element.style.transform = `translate(${translateX}px, ${translateY}px)`
    this.element.style.transition = 'transform 0.1s ease-out'
  }
  
  mouseLeave() {
    this.element.style.transform = 'translate(0, 0)'
    this.element.style.transition = 'transform 0.3s ease-out'
  }
}