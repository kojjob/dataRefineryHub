import { Controller } from "@hotwired/stimulus"

// Unified Flash Message Controller
// Combines the best features from both basic and enhanced flash systems
export default class FlashController extends Controller {
  static targets = ["progressBar", "dismissButton", "actionButton"]
  static values = {
    autoDismiss: Number,
    persistent: Boolean,
    actionUrl: String,
    actionText: String
  }

  connect() {
    this.startTime = Date.now()
    this.isPaused = false

    // Calculate display duration based on message length and configuration
    this.calculateDisplayDuration()

    // Skip auto-dismiss for persistent messages
    if (!this.persistentValue) {
      // Start progress bar animation if target exists
      if (this.hasProgressBarTarget) {
        this.animateProgressBar()
      }

      // Set up hover pause/resume functionality
      this.setupHoverHandlers()

      // Auto-dismiss after calculated duration
      this.startDismissTimer()
    }

    // Set up keyboard accessibility (always enabled)
    this.setupKeyboardHandlers()

    // Set up action button if present
    this.setupActionButton()
  }

  calculateDisplayDuration() {
    // Use explicit autoDismiss value if provided, otherwise calculate dynamically
    if (this.hasAutoDismissValue && this.autoDismissValue > 0) {
      this.displayDuration = this.autoDismissValue
    } else {
      // Calculate based on message length for better readability
      const messageText = this.element.textContent || ''
      const baseTime = 12000 // 12 seconds base time for comfortable reading
      const extraTime = Math.min(messageText.length * 80, 8000) // Up to 8 extra seconds for longer messages
      this.displayDuration = baseTime + extraTime
    }
  }
  
  disconnect() {
    this.clearTimers()
  }

  dismiss() {
    this.clearTimers()
    this.element.classList.add('dismissing')
  }

  remove() {
    this.element.remove()
  }

  startDismissTimer() {
    if (this.persistentValue) return

    this.timeout = setTimeout(() => {
      this.dismiss()
    }, this.displayDuration)
  }

  clearTimers() {
    if (this.timeout) {
      clearTimeout(this.timeout)
      this.timeout = null
    }
  }

  setupHoverHandlers() {
    if (this.persistentValue) return // No hover behavior for persistent messages

    this.element.addEventListener('mouseenter', () => this.pauseTimer())
    this.element.addEventListener('mouseleave', () => this.resumeTimer())
  }

  setupKeyboardHandlers() {
    this.element.addEventListener('keydown', (event) => {
      if (event.key === 'Escape') {
        event.preventDefault()
        this.dismiss()
      }
    })

    // Set ARIA attributes for accessibility
    if (!this.element.hasAttribute('role')) {
      this.element.setAttribute('role', 'alert')
    }
    if (!this.element.hasAttribute('aria-live')) {
      this.element.setAttribute('aria-live', 'polite')
    }
    if (!this.element.hasAttribute('tabindex')) {
      this.element.setAttribute('tabindex', '-1')
    }

    // Focus the flash message for screen readers
    setTimeout(() => {
      this.element.focus()
    }, 100)
  }

  setupActionButton() {
    if (this.hasActionButtonTarget && this.hasActionUrlValue) {
      this.actionButtonTarget.addEventListener('click', () => {
        // Allow the link to work normally, but also dismiss the message
        setTimeout(() => {
          this.dismiss()
        }, 100)
      })
    }
  }

  pauseTimer() {
    if (this.persistentValue || this.isPaused || !this.timeout) return

    this.isPaused = true
    this.remainingTime = this.displayDuration - (Date.now() - this.startTime)
    clearTimeout(this.timeout)

    // Pause progress bar animation
    if (this.hasProgressBarTarget) {
      const computedStyle = window.getComputedStyle(this.progressBarTarget)
      const currentTransform = computedStyle.transform
      this.progressBarTarget.style.transition = 'none'
      this.progressBarTarget.style.transform = currentTransform
    }
  }

  resumeTimer() {
    if (this.persistentValue || !this.isPaused) return

    this.isPaused = false
    this.startTime = Date.now()

    // Resume progress bar animation
    if (this.hasProgressBarTarget && this.remainingTime > 0) {
      this.progressBarTarget.style.transition = `transform ${this.remainingTime}ms linear`
      requestAnimationFrame(() => {
        this.progressBarTarget.style.transform = 'scaleX(0)'
      })
    }

    // Restart timer with remaining time
    this.timeout = setTimeout(() => {
      this.dismiss()
    }, this.remainingTime)
  }

  animateProgressBar() {
    if (!this.hasProgressBarTarget || this.persistentValue) return

    // Set initial state
    this.progressBarTarget.style.transform = 'scaleX(1)'
    this.progressBarTarget.style.transition = `transform ${this.displayDuration}ms linear`

    // Start animation
    requestAnimationFrame(() => {
      this.progressBarTarget.style.transform = 'scaleX(0)'
    })
  }

  // Static method to create flash messages programmatically
  static create(type, message, options = {}) {
    const container = document.querySelector('.flash-messages') || document.getElementById('flash-messages-container')
    if (!container) {
      console.warn('Flash messages container not found')
      return
    }

    const flashElement = this.createFlashElement(type, message, options)
    container.appendChild(flashElement)

    return flashElement
  }

  static createFlashElement(type, message, options = {}) {
    // Create the flash message HTML structure
    const alertType = this.normalizeAlertType(type)
    const icon = this.getIconForType(alertType)

    const flashDiv = document.createElement('div')
    flashDiv.className = `alert alert--${alertType}`
    flashDiv.setAttribute('data-controller', 'flash')
    flashDiv.setAttribute('data-action', 'animationend->flash#remove')
    flashDiv.setAttribute('role', 'alert')
    flashDiv.setAttribute('aria-live', 'polite')
    flashDiv.setAttribute('tabindex', '-1')

    // Set stimulus values if provided
    if (options.persistent) {
      flashDiv.setAttribute('data-flash-persistent-value', 'true')
    }
    if (options.autoDismiss) {
      flashDiv.setAttribute('data-flash-auto-dismiss-value', options.autoDismiss.toString())
    }

    // Build the HTML content
    let content = `
      <span class="alert__icon" aria-hidden="true">${icon}</span>
      <div class="alert__content">
        ${options.title ? `<strong>${options.title}</strong><br>` : ''}
        ${message}
      </div>
      <button type="button"
              class="alert__close"
              data-action="click->flash#dismiss"
              aria-label="Dismiss notification"
              title="Dismiss (or press Escape)">
        &times;
      </button>
    `

    // Add action button if provided
    if (options.actionText && options.actionUrl) {
      content += `
        <a href="${options.actionUrl}"
           class="alert__action"
           data-flash-target="actionButton"
           data-flash-action-url-value="${options.actionUrl}">
          ${options.actionText}
        </a>
      `
    }

    // Add progress bar if not persistent
    if (!options.persistent) {
      content += `
        <div class="alert__progress"
             data-flash-target="progressBar"
             aria-hidden="true"
             title="Auto-dismiss progress"></div>
      `
    }

    flashDiv.innerHTML = content
    return flashDiv
  }

  static normalizeAlertType(type) {
    switch (type.toString()) {
      case 'notice':
      case 'success':
        return 'success'
      case 'alert':
      case 'error':
        return 'error'
      case 'warning':
        return 'warning'
      case 'info':
        return 'info'
      default:
        return 'info'
    }
  }

  static getIconForType(alertType) {
    switch (alertType) {
      case 'success':
        return '✅'
      case 'error':
        return '❌'
      case 'warning':
        return '⚠️'
      default:
        return 'ℹ️'
    }
  }
}

// Global helper function for creating flash messages from JavaScript
window.createFlashMessage = function(type, message, options = {}) {
  return FlashController.create(type, message, options)
}

// Export for use in other modules
export { FlashController }