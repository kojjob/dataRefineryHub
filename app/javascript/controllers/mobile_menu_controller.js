import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "overlay"]

  connect() {
    this.isOpen = false
  }

  toggle() {
    if (this.isOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.isOpen = true
    document.body.classList.add("overflow-hidden")
    
    // Show overlay and sidebar
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.remove("hidden")
      setTimeout(() => {
        this.overlayTarget.firstElementChild.classList.remove("opacity-0")
        this.overlayTarget.firstElementChild.classList.add("opacity-100")
      }, 10)
    }
    
    if (this.hasSidebarTarget) {
      setTimeout(() => {
        this.sidebarTarget.classList.remove("-translate-x-full")
        this.sidebarTarget.classList.add("translate-x-0")
      }, 10)
    }
  }

  close() {
    this.isOpen = false
    document.body.classList.remove("overflow-hidden")
    
    // Hide overlay and sidebar
    if (this.hasOverlayTarget) {
      this.overlayTarget.firstElementChild.classList.remove("opacity-100")
      this.overlayTarget.firstElementChild.classList.add("opacity-0")
      setTimeout(() => {
        this.overlayTarget.classList.add("hidden")
      }, 300)
    }
    
    if (this.hasSidebarTarget) {
      this.sidebarTarget.classList.remove("translate-x-0")
      this.sidebarTarget.classList.add("-translate-x-full")
    }
  }

  closeOnOverlay(event) {
    if (event.target === this.overlayTarget || event.target === this.overlayTarget.firstElementChild) {
      this.close()
    }
  }

  disconnect() {
    document.body.classList.remove("overflow-hidden")
  }
}