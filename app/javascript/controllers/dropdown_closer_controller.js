import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="dropdown-closer" on the body or document
export default class extends Controller {
  connect() {
    document.addEventListener('click', this.closeDropdowns.bind(this))
  }
  
  disconnect() {
    document.removeEventListener('click', this.closeDropdowns.bind(this))
  }
  
  closeDropdowns(event) {
    // Close user menu dropdowns
    this.closeDropdownsOfType('[data-controller*="user-menu"]', '[data-user-menu-target="dropdown"]', event)
    
    // Close notification dropdowns
    this.closeDropdownsOfType('[data-controller*="notifications"]', '[data-notifications-target="dropdown"]', event)
    
    // Close search results
    this.closeDropdownsOfType('[data-controller*="search"]', '[data-search-target="results"]', event)
  }
  
  closeDropdownsOfType(controllerSelector, dropdownSelector, event) {
    const controllers = document.querySelectorAll(controllerSelector)
    controllers.forEach(controller => {
      const dropdown = controller.querySelector(dropdownSelector)
      if (dropdown && !dropdown.classList.contains('hidden') && !controller.contains(event.target)) {
        dropdown.classList.add('hidden')
      }
    })
  }
}