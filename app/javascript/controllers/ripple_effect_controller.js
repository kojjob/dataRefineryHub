import { Controller } from "@hotwired/stimulus"

// Ripple effect on click for buttons and interactive elements
export default class extends Controller {
  connect() {
    // Ensure element has proper styling for ripple
    this.element.style.position = 'relative'
    this.element.style.overflow = 'hidden'
  }
  
  click(event) {
    // Create ripple element
    const ripple = document.createElement('span')
    const rect = this.element.getBoundingClientRect()
    const size = Math.max(rect.width, rect.height)
    const x = event.clientX - rect.left - size / 2
    const y = event.clientY - rect.top - size / 2
    
    // Apply ripple styles
    ripple.style.width = ripple.style.height = size + 'px'
    ripple.style.left = x + 'px'
    ripple.style.top = y + 'px'
    ripple.style.position = 'absolute'
    ripple.style.borderRadius = '50%'
    ripple.style.backgroundColor = 'rgba(255, 255, 255, 0.5)'
    ripple.style.pointerEvents = 'none'
    ripple.style.animation = 'ripple-animation 0.6s ease-out'
    
    this.element.appendChild(ripple)
    
    // Remove ripple after animation
    setTimeout(() => ripple.remove(), 600)
  }
}