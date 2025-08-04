import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="submenu"
export default class extends Controller {
  static targets = ["button", "menu", "chevron"]
  
  connect() {
    console.log("Submenu controller connected")
  }
  
  toggle(event) {
    console.log("Submenu toggle clicked")
    event.preventDefault()
    
    if (this.menuTarget.classList.contains('hidden')) {
      this.menuTarget.classList.remove('hidden')
      if (this.hasChevronTarget) {
        this.chevronTarget.style.transform = 'rotate(90deg)'
      }
    } else {
      this.menuTarget.classList.add('hidden')
      if (this.hasChevronTarget) {
        this.chevronTarget.style.transform = 'rotate(0deg)'
      }
    }
  }
};
