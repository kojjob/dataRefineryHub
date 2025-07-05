import { Controller } from "@hotwired/stimulus"

// Smooth page transitions with fade effects
export default class extends Controller {
  connect() {
    // Add page entrance animation
    this.element.classList.add('page-enter')
    
    // Force reflow to ensure the animation triggers
    this.element.offsetHeight
    
    requestAnimationFrame(() => {
      this.element.classList.add('page-enter-active')
      this.element.classList.remove('page-enter')
    })
    
    // Set up exit animation for links
    this.setupLinkTransitions()
  }
  
  setupLinkTransitions() {
    // Find all links that should trigger transitions
    const links = this.element.querySelectorAll('a[href]:not([data-turbo="false"]):not([target="_blank"])')
    
    links.forEach(link => {
      link.addEventListener('click', (e) => {
        // Don't transition for same-page anchors
        if (link.getAttribute('href').startsWith('#')) return
        
        // Don't transition if cmd/ctrl is held (new tab)
        if (e.metaKey || e.ctrlKey) return
        
        e.preventDefault()
        
        // Start exit animation
        this.element.classList.add('page-exit')
        
        // Navigate after animation
        setTimeout(() => {
          Turbo.visit(link.href)
        }, 200)
      })
    })
  }
}