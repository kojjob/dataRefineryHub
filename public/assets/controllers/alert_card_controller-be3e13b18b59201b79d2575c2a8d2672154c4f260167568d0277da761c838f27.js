import { Controller } from "@hotwired/stimulus"

// Premium Alert Card Controller for DataReflow
// Handles alert acknowledgment, resolution, and dismissal with premium UX
export default class extends Controller {
  static targets = ["card"]
  static values = { 
    alertId: Number,
    csrfToken: String 
  }

  connect() {
    this.setupPremiumAnimations()
    this.csrfTokenValue = this.getCSRFToken()
  }

  // Acknowledge alert action
  async acknowledge(event) {
    event.preventDefault()
    
    if (!this.confirmAction("acknowledge")) return
    
    try {
      this.showLoadingState(event.target, "Acknowledging...")
      
      const response = await this.makeRequest("acknowledge")
      
      if (response.success) {
        this.showSuccessState(event.target, "Acknowledged")
        this.updateAlertStatus("acknowledged")
        this.showNotification("Alert acknowledged successfully", "success")
      } else {
        throw new Error(response.error || "Failed to acknowledge alert")
      }
    } catch (error) {
      this.showErrorState(event.target, "Failed")
      this.showNotification(`Error: ${error.message}`, "error")
      console.error("Error acknowledging alert:", error)
    }
  }

  // Resolve alert action
  async resolve(event) {
    event.preventDefault()
    
    if (!this.confirmAction("resolve")) return
    
    try {
      this.showLoadingState(event.target, "Resolving...")
      
      const response = await this.makeRequest("resolve")
      
      if (response.success) {
        this.showSuccessState(event.target, "Resolved")
        this.updateAlertStatus("resolved")
        this.animateCardRemoval()
        this.showNotification("Alert resolved successfully", "success")
      } else {
        throw new Error(response.error || "Failed to resolve alert")
      }
    } catch (error) {
      this.showErrorState(event.target, "Failed")
      this.showNotification(`Error: ${error.message}`, "error")
      console.error("Error resolving alert:", error)
    }
  }

  // Dismiss alert action
  async dismiss(event) {
    event.preventDefault()
    
    if (!this.confirmAction("dismiss")) return
    
    try {
      this.showLoadingState(event.target, "Dismissing...")
      
      const response = await this.makeRequest("dismiss")
      
      if (response.success) {
        this.showSuccessState(event.target, "Dismissed")
        this.animateCardRemoval()
        this.showNotification("Alert dismissed successfully", "success")
      } else {
        throw new Error(response.error || "Failed to dismiss alert")
      }
    } catch (error) {
      this.showErrorState(event.target, "Failed")
      this.showNotification(`Error: ${error.message}`, "error")
      console.error("Error dismissing alert:", error)
    }
  }

  // Private methods

  async makeRequest(action) {
    const url = `/pipeline_monitoring/alerts/${this.alertIdValue}/${action}`
    
    const response = await fetch(url, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfTokenValue,
        "Accept": "application/json"
      },
      body: JSON.stringify({ action: action })
    })

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`)
    }

    return await response.json()
  }

  confirmAction(action) {
    const messages = {
      acknowledge: "Are you sure you want to acknowledge this alert?",
      resolve: "Are you sure you want to resolve this alert? This action cannot be undone.",
      dismiss: "Are you sure you want to dismiss this alert?"
    }
    
    return confirm(messages[action] || "Are you sure?")
  }

  showLoadingState(button, text) {
    button.disabled = true
    button.innerHTML = `
      <svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      <span class="ml-2">${text}</span>
    `
    button.classList.add("opacity-75", "cursor-not-allowed")
  }

  showSuccessState(button, text) {
    button.innerHTML = `
      <svg class="w-4 h-4 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
        <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7"></path>
      </svg>
      <span class="ml-2">${text}</span>
    `
    button.classList.remove("opacity-75", "cursor-not-allowed")
    button.classList.add("bg-green-500", "hover:bg-green-600")
  }

  showErrorState(button, text) {
    button.disabled = false
    button.innerHTML = `
      <svg class="w-4 h-4 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
        <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"></path>
      </svg>
      <span class="ml-2">${text}</span>
    `
    button.classList.remove("opacity-75", "cursor-not-allowed")
    button.classList.add("bg-red-500", "hover:bg-red-600")
  }

  updateAlertStatus(status) {
    // Update status badge in the UI
    const statusBadge = this.element.querySelector('[class*="bg-red-100"], [class*="bg-yellow-100"], [class*="bg-green-100"]')
    if (statusBadge) {
      statusBadge.textContent = status.charAt(0).toUpperCase() + status.slice(1)
      
      // Update badge colors based on status
      statusBadge.className = statusBadge.className.replace(/bg-\w+-100 text-\w+-800 border-\w+-200/g, '')
      
      const statusColors = {
        acknowledged: "bg-yellow-100 text-yellow-800 border-yellow-200",
        resolved: "bg-green-100 text-green-800 border-green-200",
        dismissed: "bg-gray-100 text-gray-800 border-gray-200"
      }
      
      statusBadge.classList.add(...statusColors[status].split(' '))
    }
  }

  animateCardRemoval() {
    // Premium card removal animation
    this.element.style.transition = "all 0.5s ease-out"
    this.element.style.transform = "translateX(100%) scale(0.8)"
    this.element.style.opacity = "0"
    
    setTimeout(() => {
      this.element.style.maxHeight = "0"
      this.element.style.marginBottom = "0"
      this.element.style.paddingTop = "0"
      this.element.style.paddingBottom = "0"
      
      setTimeout(() => {
        this.element.remove()
      }, 300)
    }, 500)
  }

  setupPremiumAnimations() {
    // Add premium hover effects
    this.element.addEventListener("mouseenter", () => {
      this.element.style.transform = "translateY(-2px) scale(1.01)"
    })
    
    this.element.addEventListener("mouseleave", () => {
      this.element.style.transform = "translateY(0) scale(1)"
    })
  }

  showNotification(message, type) {
    // Create premium notification
    const notification = document.createElement("div")
    notification.className = `fixed top-4 right-4 z-50 px-6 py-4 rounded-xl shadow-xl backdrop-blur-xl border transition-all duration-500 transform translate-x-full ${
      type === "success" 
        ? "bg-green-50/90 border-green-200 text-green-800" 
        : "bg-red-50/90 border-red-200 text-red-800"
    }`
    
    notification.innerHTML = `
      <div class="flex items-center gap-3">
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
          ${type === "success" 
            ? '<path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7"></path>'
            : '<path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"></path>'
          }
        </svg>
        <span class="font-medium">${message}</span>
      </div>
    `
    
    document.body.appendChild(notification)
    
    // Animate in
    setTimeout(() => {
      notification.style.transform = "translateX(0)"
    }, 100)
    
    // Auto remove
    setTimeout(() => {
      notification.style.transform = "translateX(100%)"
      setTimeout(() => notification.remove(), 500)
    }, 3000)
  }

  getCSRFToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.getAttribute('content') : ''
  }
};
