import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "loading", "error", "refreshButton"]
  static values = { 
    autoRefresh: { type: Boolean, default: true },
    refreshInterval: { type: Number, default: 300000 } // 5 minutes
  }

  connect() {
    this.loadInsights()
    
    if (this.autoRefreshValue) {
      this.startAutoRefresh()
    }
  }

  disconnect() {
    this.stopAutoRefresh()
  }

  async loadInsights() {
    this.showLoading()
    this.hideError()

    try {
      const response = await fetch("/api/v1/ai/insights", {
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('[name="csrf-token"]').content
        }
      })

      if (!response.ok) throw new Error("Failed to load insights")

      const data = await response.json()
      this.displayInsights(data.insights || [])
    } catch (error) {
      console.error("AI insights error:", error)
      this.showError("Failed to load AI insights. Please try again.")
    } finally {
      this.hideLoading()
    }
  }

  displayInsights(insights) {
    if (!this.hasContentTarget) return

    if (insights.length === 0) {
      this.contentTarget.innerHTML = `
        <div class="text-center py-8 text-gray-500">
          <p>No insights available at this time.</p>
          <p class="text-sm mt-2">Check back later as we analyze your data.</p>
        </div>
      `
      return
    }

    this.contentTarget.innerHTML = insights.map(insight => this.renderInsight(insight)).join("")
  }

  renderInsight(insight) {
    const priorityColors = {
      high: "red",
      medium: "yellow",
      low: "blue",
      info: "gray"
    }

    const color = priorityColors[insight.priority] || "blue"

    return `
      <div class="p-3 bg-${color}-50 rounded-lg border border-${color}-100 mb-3">
        <div class="flex items-start gap-3">
          <div class="h-2 w-2 bg-${color}-500 rounded-full mt-2 flex-shrink-0"></div>
          <div class="flex-1">
            <h5 class="text-sm font-medium text-${color}-900 mb-1">
              ${this.escapeHtml(insight.title)}
            </h5>
            <p class="text-sm text-${color}-700">
              ${this.escapeHtml(insight.description)}
            </p>
            ${insight.action ? `
              <button class="mt-2 text-xs font-medium text-${color}-600 hover:text-${color}-700 underline"
                      data-action="click->ai-insights#performAction"
                      data-insight-id="${insight.id}"
                      data-insight-action="${insight.action}">
                ${this.escapeHtml(insight.actionLabel || "Take Action")}
              </button>
            ` : ""}
          </div>
          ${insight.confidence ? `
            <span class="text-xs text-gray-500 flex-shrink-0">
              ${Math.round(insight.confidence * 100)}%
            </span>
          ` : ""}
        </div>
      </div>
    `
  }

  performAction(event) {
    const insightId = event.currentTarget.dataset.insightId
    const action = event.currentTarget.dataset.insightAction

    // Handle different action types
    switch (action) {
      case "navigate":
        // Navigate to a specific page
        window.location.href = event.currentTarget.dataset.actionUrl
        break
      case "modal":
        // Open a modal (would need modal controller)
        this.dispatch("open-modal", { detail: { insightId } })
        break
      case "refresh":
        // Refresh the insights
        this.loadInsights()
        break
      default:
        console.log("Unknown action:", action)
    }
  }

  refresh(event) {
    if (event) event.preventDefault()
    this.loadInsights()
  }

  startAutoRefresh() {
    this.refreshTimer = setInterval(() => {
      this.loadInsights()
    }, this.refreshIntervalValue)
  }

  stopAutoRefresh() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
    }
  }

  showLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.remove("hidden")
    }
    if (this.hasContentTarget) {
      this.contentTarget.classList.add("opacity-50")
    }
    if (this.hasRefreshButtonTarget) {
      this.refreshButtonTarget.disabled = true
    }
  }

  hideLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.add("hidden")
    }
    if (this.hasContentTarget) {
      this.contentTarget.classList.remove("opacity-50")
    }
    if (this.hasRefreshButtonTarget) {
      this.refreshButtonTarget.disabled = false
    }
  }

  showError(message) {
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = message
      this.errorTarget.classList.remove("hidden")
    }
  }

  hideError() {
    if (this.hasErrorTarget) {
      this.errorTarget.classList.add("hidden")
    }
  }

  escapeHtml(unsafe) {
    return unsafe
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#039;")
  }
}