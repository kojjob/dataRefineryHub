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
      navbar.classList.add('navbar--scrolled')
    } else {
      navbar.classList.remove('navbar--scrolled')
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
    this.mobileMenuTarget.classList.add('navbar__mobile-menu--open')
    this.element.querySelector('.navbar__toggle').classList.add('navbar__toggle--open')
    document.body.classList.add('overflow-hidden')
  }

  closeMobile() {
    this.mobileMenuOpen = false
    this.mobileMenuTarget.classList.remove('navbar__mobile-menu--open')
    this.element.querySelector('.navbar__toggle').classList.remove('navbar__toggle--open')
    document.body.classList.remove('overflow-hidden')
  }

  disconnect() {
    window.removeEventListener('scroll', this.boundHandleScroll)
  }
}