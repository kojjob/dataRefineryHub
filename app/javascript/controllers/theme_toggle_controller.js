import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["icon"]
  
  connect() {
    // Check for saved theme preference or default to light
    const savedTheme = localStorage.getItem('theme') || 'light'
    this.applyTheme(savedTheme)
  }
  
  toggle() {
    const currentTheme = document.documentElement.classList.contains('dark') ? 'dark' : 'light'
    const newTheme = currentTheme === 'dark' ? 'light' : 'dark'
    this.applyTheme(newTheme)
    localStorage.setItem('theme', newTheme)
  }
  
  applyTheme(theme) {
    if (theme === 'dark') {
      document.documentElement.classList.add('dark')
      if (this.hasIconTarget) {
        this.iconTarget.textContent = '☀️'
      }
    } else {
      document.documentElement.classList.remove('dark')
      if (this.hasIconTarget) {
        this.iconTarget.textContent = '🌙'
      }
    }
  }
}