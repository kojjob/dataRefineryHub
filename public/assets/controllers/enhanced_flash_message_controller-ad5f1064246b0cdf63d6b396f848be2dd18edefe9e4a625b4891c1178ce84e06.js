import { Controller } from "@hotwired/stimulus"

// Handles auto-dismiss, progress bars, animations, and user interactions
export default class extends Controller {
  static targets = ["progressBar", "dismissButton"]
  static values = {
    autoDismiss: Number,
    persistent: Boolean
  }

  connect() {
    this.startTime = Date.now()
    this.remainingTime = this.autoDismissValue
    this.isPaused = false
    
    // Start auto-dismiss timer if not persistent
    if (!this.persistentValue && this.autoDismissValue > 0) {
      this.startAutoDismiss()
    }
    
    // Add entrance animation
    this.element.classList.add('flash-message')
    
    // Set up keyboard accessibility
    this.setupKeyboardHandlers()
  }

  disconnect() {
    this.clearTimers()
  }

  // Auto-dismiss functionality
  startAutoDismiss() {
    if (this.persistentValue) return
    
    this.startTime = Date.now()
    this.remainingTime = this.autoDismissValue
    
    // Start progress bar animation
    if (this.hasProgressBarTarget) {
      this.animateProgressBar()
    }
    
    // Set dismiss timer
    this.dismissTimer = setTimeout(() => {
      this.dismiss()
    }, this.remainingTime)
  }

  pauseTimer() {
    if (this.persistentValue || this.isPaused) return
    
    this.isPaused = true
    this.clearTimers()
    
    // Calculate remaining time
    const elapsed = Date.now() - this.startTime
    this.remainingTime = Math.max(0, this.remainingTime - elapsed)
    
    // Pause progress bar
    if (this.hasProgressBarTarget) {
      this.progressBarTarget.style.animationPlayState = 'paused'
    }
  }

  resumeTimer() {
    if (this.persistentValue || !this.isPaused) return
    
    this.isPaused = false
    
    if (this.remainingTime > 0) {
      this.startTime = Date.now()
      
      // Resume progress bar
      if (this.hasProgressBarTarget) {
        this.animateProgressBar()
      }
      
      // Resume dismiss timer
      this.dismissTimer = setTimeout(() => {
        this.dismiss()
      }, this.remainingTime)
    }
  }

  animateProgressBar() {
    if (!this.hasProgressBarTarget) return
    
    // Reset and animate progress bar
    this.progressBarTarget.style.width = '100%'
    this.progressBarTarget.style.transition = `width ${this.remainingTime}ms linear`
    
    // Use requestAnimationFrame to ensure the transition starts
    requestAnimationFrame(() => {
      this.progressBarTarget.style.width = '0%'
    })
  }

  // Dismiss the flash message
  dismiss() {
    this.clearTimers()
    
    // Add dismissing animation
    this.element.classList.add('dismissing')
    
    // Remove element after animation completes
    setTimeout(() => {
      if (this.element.parentNode) {
        this.element.remove()
      }
    }, 300) // Match animation duration
  }

  // Handle action button clicks
  handleAction(event) {
    // Allow the link to work normally, but also dismiss the message
    setTimeout(() => {
      this.dismiss()
    }, 100)
  }

  // Keyboard accessibility
  setupKeyboardHandlers() {
    this.element.addEventListener('keydown', (event) => {
      if (event.key === 'Escape') {
        event.preventDefault()
        this.dismiss()
      }
    })
    
    // Make the flash message focusable for screen readers
    if (!this.element.hasAttribute('tabindex')) {
      this.element.setAttribute('tabindex', '-1')
    }
    
    // Set ARIA attributes for accessibility
    this.element.setAttribute('role', 'alert')
    this.element.setAttribute('aria-live', 'polite')
  }

  // Clear all timers
  clearTimers() {
    if (this.dismissTimer) {
      clearTimeout(this.dismissTimer)
      this.dismissTimer = null
    }
  }

  // Static method to create flash messages programmatically
  static create(type, message, options = {}) {
    const container = document.getElementById('flash-messages-container')
    if (!container) {
      console.warn('Flash messages container not found')
      return
    }

    const messageData = {
      message: message,
      title: options.title,
      action_text: options.actionText,
      action_url: options.actionUrl,
      persistent: options.persistent || false,
      auto_dismiss: options.autoDismiss || 5000
    }

    // Create flash message element
    const flashElement = this.createFlashElement(type, messageData)
    container.appendChild(flashElement)

    return flashElement
  }

  static createFlashElement(type, data) {
    // This would need to be implemented to create the HTML structure
    // For now, this is a placeholder for programmatic flash creation
    const div = document.createElement('div')
    div.className = 'flash-message'
    div.setAttribute('data-controller', 'enhanced-flash-message')
    div.innerHTML = `<div class="p-4">${data.message}</div>`
    return div
  }
}

// Global helper function for creating flash messages from JavaScript
window.createFlashMessage = function(type, message, options = {}) {
  return EnhancedFlashMessageController.create(type, message, options)
}

// Export for use in other modules
export { EnhancedFlashMessageController };
