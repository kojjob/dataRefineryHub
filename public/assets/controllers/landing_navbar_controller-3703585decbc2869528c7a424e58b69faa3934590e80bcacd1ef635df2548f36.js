import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["mobileMenu", "hamburgerTop", "hamburgerMiddle", "hamburgerBottom"]

  connect() {
    this.mobileMenuOpen = false
    this.setupScrollListener()
    this.setupSmoothScroll()
  }

  setupScrollListener() {
    this.boundHandleScroll = this.handleScroll.bind(this)
    window.addEventListener('scroll', this.boundHandleScroll)
    this.handleScroll() // Call once to set initial state
  }

  handleScroll() {
    const scrolled = window.scrollY > 50
    const navbar = this.element
    
    if (scrolled) {
      navbar.classList.add('bg-white/10', 'backdrop-blur-lg', 'border-b', 'border-white/20')
      navbar.classList.remove('bg-transparent')
    } else {
      navbar.classList.remove('bg-white/10', 'backdrop-blur-lg', 'border-b', 'border-white/20')
      navbar.classList.add('bg-transparent')
    }
  }

  setupSmoothScroll() {
    // Add smooth scroll behavior to anchor links
    this.element.addEventListener('click', (e) => {
      const link = e.target.closest('a[href^="#"]')
      if (link) {
        e.preventDefault()
        const targetId = link.getAttribute('href').substring(1)
        const targetElement = document.getElementById(targetId)
        
        if (targetElement) {
          const offsetTop = targetElement.offsetTop - 100 // Account for fixed navbar
          window.scrollTo({
            top: offsetTop,
            behavior: 'smooth'
          })
        }
        
        // Close mobile menu if open
        if (this.mobileMenuOpen) {
          this.closeMobile()
        }
      }
    })
  }

  toggleMobile() {
    if (this.mobileMenuOpen) {
      this.closeMobile()
    } else {
      this.openMobile()
    }
  }

  openMobile() {
    this.mobileMenuOpen = true
    this.mobileMenuTarget.classList.remove('translate-x-full')
    document.body.classList.add('overflow-hidden')
    
    // Animate hamburger to X
    this.hamburgerTopTarget.style.transform = 'rotate(45deg) translateY(6px)'
    this.hamburgerMiddleTarget.style.opacity = '0'
    this.hamburgerBottomTarget.style.transform = 'rotate(-45deg) translateY(-6px)'
  }

  closeMobile() {
    this.mobileMenuOpen = false
    this.mobileMenuTarget.classList.add('translate-x-full')
    document.body.classList.remove('overflow-hidden')
    
    // Animate X back to hamburger
    this.hamburgerTopTarget.style.transform = 'translateY(-4px)'
    this.hamburgerMiddleTarget.style.opacity = '1'
    this.hamburgerBottomTarget.style.transform = 'translateY(4px)'
  }

  disconnect() {
    window.removeEventListener('scroll', this.boundHandleScroll)
  }
};
