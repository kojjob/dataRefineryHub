import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["icon"]
  
  connect() {
    // Check for saved theme preference or default to light
    const savedTheme = localStorage.getItem('theme') || 'light'
    this.applyTheme(savedTheme)
  }
  
  toggle() {
    const currentTheme = document.documentElement.getAttribute('data-color-scheme') || 'light'
    const newTheme = currentTheme === 'light' ? 'dark' : 'light'
    
    this.applyTheme(newTheme)
    localStorage.setItem('theme', newTheme)
    
    // Dispatch custom event for other components to react to theme change
    window.dispatchEvent(new CustomEvent('theme:changed', { detail: { theme: newTheme } }))
  }
  
  applyTheme(theme) {
    // Add transition class before changing theme
    document.body.classList.add('theme-transition')
    
    // Apply theme
    document.documentElement.setAttribute('data-color-scheme', theme)
    
    // Update icon
    if (this.hasIconTarget) {
      this.iconTarget.textContent = theme === 'dark' ? '☀️' : '🌙'
    }
    
    // Remove transition class after a delay
    setTimeout(() => {
      document.body.classList.remove('theme-transition')
    }, 300)
  }
}