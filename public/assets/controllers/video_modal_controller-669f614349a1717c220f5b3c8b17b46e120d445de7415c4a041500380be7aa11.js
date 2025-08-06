import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "video"]

  open(event) {
    event.preventDefault()
    const videoUrl = event.currentTarget.dataset.videoUrl
    
    if (this.hasModalTarget) {
      this.modalTarget.classList.remove("hidden")
      
      if (this.hasVideoTarget && videoUrl) {
        this.videoTarget.src = videoUrl
      }
    }
  }

  close(event) {
    if (event) event.preventDefault()
    
    if (this.hasModalTarget) {
      this.modalTarget.classList.add("hidden")
      
      if (this.hasVideoTarget) {
        this.videoTarget.src = ""
      }
    }
  }

  backdropClick(event) {
    if (event.target === event.currentTarget) {
      this.close()
    }
  }

  disconnect() {
    this.close()
  }
};
