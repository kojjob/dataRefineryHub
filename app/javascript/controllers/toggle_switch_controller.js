import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { active: Boolean }
  static classes = ["active"]

  connect() {
    this.updateToggleState()
  }

  toggle() {
    this.activeValue = !this.activeValue
    this.updateToggleState()
    
    // Emit custom event for other controllers to listen to
    this.element.dispatchEvent(new CustomEvent("toggle:changed", {
      detail: { active: this.activeValue },
      bubbles: true
    }))
  }

  updateToggleState() {
    if (this.activeValue) {
      this.element.classList.add("active")
    } else {
      this.element.classList.remove("active")
    }
  }
}
