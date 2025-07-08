import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this.isOpen = false
    this.boundHandleClickOutside = this.handleClickOutside.bind(this)
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
    this.menuTarget.classList.add("active")
    document.addEventListener("click", this.boundHandleClickOutside)
  }

  close() {
    this.isOpen = false
    this.menuTarget.classList.remove("active")
    document.removeEventListener("click", this.boundHandleClickOutside)
  }

  handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  disconnect() {
    document.removeEventListener("click", this.boundHandleClickOutside)
  }
}