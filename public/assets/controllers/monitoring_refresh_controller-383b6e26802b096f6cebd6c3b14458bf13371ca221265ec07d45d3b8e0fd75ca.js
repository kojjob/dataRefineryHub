import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.setupAutoRefresh()
  }

  disconnect() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
    }
  }

  refresh() {
    // Add spinning animation to refresh button
    const button = this.element
    const icon = button.querySelector('svg')
    
    icon.classList.add('animate-spin')
    
    // Trigger Turbo reload
    Turbo.visit(window.location.href, { action: "replace" })
    
    setTimeout(() => {
      icon.classList.remove('animate-spin')
    }, 1000)
  }

  setupAutoRefresh() {
    // Check if auto-refresh is enabled
    const toggleSwitch = document.querySelector('[data-controller="toggle-switch"][data-toggle-switch-active-value="true"]')
    
    if (toggleSwitch && toggleSwitch.classList.contains('active')) {
      // Refresh every 30 seconds
      this.refreshTimer = setInterval(() => {
        this.refresh()
      }, 30000)
    }
  }
};
