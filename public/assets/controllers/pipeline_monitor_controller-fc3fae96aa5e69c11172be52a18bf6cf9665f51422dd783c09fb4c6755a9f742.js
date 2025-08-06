import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { refreshUrl: String }
  static targets = ["container"]

  connect() {
    this.startAutoRefresh()
  }

  disconnect() {
    this.stopAutoRefresh()
  }

  startAutoRefresh() {
    // Refresh every 30 seconds for live pipeline monitoring
    this.refreshInterval = setInterval(() => {
      this.refreshPipelines()
    }, 30000)
  }

  stopAutoRefresh() {
    if (this.refreshInterval) {
      clearInterval(this.refreshInterval)
      this.refreshInterval = null
    }
  }

  async refreshPipelines() {
    try {
      const response = await fetch(this.refreshUrlValue, {
        headers: {
          "Accept": "text/vnd.turbo-stream.html",
          "X-Requested-With": "XMLHttpRequest"
        }
      })

      if (response.ok) {
        const html = await response.text()
        // Update pipeline sections with new data
        // You might want to implement partial updates here
        console.log("Pipeline data refreshed")
      }
    } catch (error) {
      console.error("Failed to refresh pipeline data:", error)
    }
  }

  // Manual refresh trigger
  refresh() {
    this.refreshPipelines()
  }
};
