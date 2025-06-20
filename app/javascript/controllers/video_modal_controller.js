import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "video"]

  connect() {
    this.boundHandleEscape = this.handleEscape.bind(this)
  }

  open() {
    this.modalTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
    document.addEventListener("keydown", this.boundHandleEscape)
    
    // Load video if it has a data-src attribute
    if (this.hasVideoTarget && this.videoTarget.dataset.src) {
      this.videoTarget.src = this.videoTarget.dataset.src
    }
  }

  close() {
    this.modalTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
    document.removeEventListener("keydown", this.boundHandleEscape)
    
    // Stop video playback
    if (this.hasVideoTarget) {
      this.videoTarget.pause()
      this.videoTarget.currentTime = 0
    }
  }

  closeOnBackdrop(event) {
    if (event.target === this.modalTarget) {
      this.close()
    }
  }

  handleEscape(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHandleEscape)
  }
}