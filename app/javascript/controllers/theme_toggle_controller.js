import { Controller } from "@hotwired/stimulus"

// Premium Theme Toggle Controller with enhanced functionality
export default class extends Controller {
  static targets = ["button", "lightIcon", "darkIcon", "icon"]

  connect() {
    this.initializeTheme()
    this.updateIcons()
    this.setupSystemThemeListener()
  }

  disconnect() {
    if (this.mediaQuery) {
      this.mediaQuery.removeEventListener('change', this.boundHandleSystemThemeChange)
    }
  }

  initializeTheme() {
    // Get saved theme preference or default to system preference
    const savedTheme = localStorage.getItem('theme')
    const systemPrefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches

    if (savedTheme) {
      this.currentTheme = savedTheme
    } else {
      this.currentTheme = systemPrefersDark ? 'dark' : 'light'
    }

    this.applyTheme(this.currentTheme)
  }

  setupSystemThemeListener() {
    // Listen for system theme changes when no explicit preference is set
    this.mediaQuery = window.matchMedia('(prefers-color-scheme: dark)')
    this.boundHandleSystemThemeChange = this.handleSystemThemeChange.bind(this)
    this.mediaQuery.addEventListener('change', this.boundHandleSystemThemeChange)
  }

  handleSystemThemeChange(e) {
    // Only respond to system changes if user hasn't set an explicit preference
    if (!localStorage.getItem('theme')) {
      this.currentTheme = e.matches ? 'dark' : 'light'
      this.applyTheme(this.currentTheme)
      this.updateIcons()
    }
  }

  toggle() {
    // Toggle between light and dark themes
    this.currentTheme = this.currentTheme === 'light' ? 'dark' : 'light'

    // Save preference to localStorage
    localStorage.setItem('theme', this.currentTheme)

    // Apply the theme with smooth transition
    this.applyThemeWithTransition(this.currentTheme)
    this.updateIcons()

    // Dispatch custom event for other components to listen to
    this.dispatch('themeChanged', {
      detail: {
        theme: this.currentTheme,
        timestamp: Date.now()
      }
    })

    // Also dispatch legacy event for backward compatibility
    window.dispatchEvent(new CustomEvent('theme:changed', { detail: { theme: this.currentTheme } }))
  }

  applyTheme(theme) {
    const html = document.documentElement
    const body = document.body

    if (theme === 'dark') {
      html.setAttribute('data-color-scheme', 'dark')
      html.classList.add('dark')
      body.classList.add('dark')
    } else {
      html.setAttribute('data-color-scheme', 'light')
      html.classList.remove('dark')
      body.classList.remove('dark')
    }

    // Update CSS custom properties for immediate effect
    this.updateCSSCustomProperties(theme)
  }

  applyThemeWithTransition(theme) {
    // Add transition class for smooth theme switching
    document.documentElement.classList.add('theme-transitioning')
    document.body.classList.add('theme-transition')

    // Apply the theme
    this.applyTheme(theme)

    // Remove transition class after animation completes
    setTimeout(() => {
      document.documentElement.classList.remove('theme-transitioning')
      document.body.classList.remove('theme-transition')
    }, 300)
  }

  updateCSSCustomProperties(theme) {
    const root = document.documentElement

    if (theme === 'dark') {
      // Dark theme color values
      root.style.setProperty('--color-background', '#0f172a')
      root.style.setProperty('--color-surface', '#1e293b')
      root.style.setProperty('--color-surface-rgb', '30, 41, 59')
      root.style.setProperty('--color-text', '#f8fafc')
      root.style.setProperty('--color-text-secondary', '#cbd5e1')
      root.style.setProperty('--color-border', '#334155')
      root.style.setProperty('--color-border-rgb', '51, 65, 85')
      root.style.setProperty('--color-primary', '#14b8a6')
      root.style.setProperty('--color-primary-rgb', '20, 184, 166')
    } else {
      // Light theme color values
      root.style.setProperty('--color-background', '#ffffff')
      root.style.setProperty('--color-surface', '#f8fafc')
      root.style.setProperty('--color-surface-rgb', '248, 250, 252')
      root.style.setProperty('--color-text', '#1e293b')
      root.style.setProperty('--color-text-secondary', '#64748b')
      root.style.setProperty('--color-border', '#e2e8f0')
      root.style.setProperty('--color-border-rgb', '226, 232, 240')
      root.style.setProperty('--color-primary', '#0d9488')
      root.style.setProperty('--color-primary-rgb', '13, 148, 136')
    }
  }

  updateIcons() {
    // Handle new premium icons
    if (this.hasLightIconTarget && this.hasDarkIconTarget) {
      const lightIcon = this.lightIconTarget
      const darkIcon = this.darkIconTarget

      if (this.currentTheme === 'dark') {
        lightIcon.style.display = 'none'
        darkIcon.style.display = 'block'

        // Add glow effect for dark mode
        if (this.hasButtonTarget) {
          this.buttonTarget.style.boxShadow = '0 4px 12px rgba(20, 184, 166, 0.2)'
        }
      } else {
        lightIcon.style.display = 'block'
        darkIcon.style.display = 'none'

        // Remove glow effect for light mode
        if (this.hasButtonTarget) {
          this.buttonTarget.style.boxShadow = '0 4px 12px rgba(0, 0, 0, 0.05)'
        }
      }

      // Add rotation animation
      const activeIcon = this.currentTheme === 'dark' ? darkIcon : lightIcon
      activeIcon.style.transform = 'rotate(360deg)'
      activeIcon.style.transition = 'transform 0.3s cubic-bezier(0.4, 0, 0.2, 1)'

      setTimeout(() => {
        activeIcon.style.transform = 'rotate(0deg)'
      }, 300)
    }

    // Handle legacy icon (backward compatibility)
    if (this.hasIconTarget) {
      this.iconTarget.textContent = this.currentTheme === 'dark' ? '☀️' : '🌙'
    }
  }

  // Public method to get current theme
  getCurrentTheme() {
    return this.currentTheme
  }

  // Public method to set theme programmatically
  setTheme(theme) {
    if (theme === 'light' || theme === 'dark') {
      this.currentTheme = theme
      localStorage.setItem('theme', theme)
      this.applyThemeWithTransition(theme)
      this.updateIcons()
    }
  }
}