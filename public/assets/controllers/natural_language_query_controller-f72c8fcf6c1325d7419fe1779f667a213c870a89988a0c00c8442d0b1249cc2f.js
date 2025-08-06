import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "submit", "results", "loading", "examples"]

  connect() {
    this.setupEventListeners()
  }

  setupEventListeners() {
    if (this.hasInputTarget) {
      this.inputTarget.addEventListener("keydown", (e) => {
        if (e.key === "Enter" && !e.shiftKey) {
          e.preventDefault()
          this.submitQuery()
        }
      })
    }
  }

  submitQuery() {
    const query = this.inputTarget.value.trim()
    if (!query) return

    this.showLoading()
    
    // Simulate API call - in real implementation, this would call your backend
    fetch("/api/v1/ai/query", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({ query: query })
    })
    .then(response => response.json())
    .then(data => {
      this.displayResults(data)
    })
    .catch(error => {
      console.error("Query failed:", error)
      this.showError("Failed to process query. Please try again.")
    })
    .finally(() => {
      this.hideLoading()
    })
  }

  useExample(event) {
    const example = event.currentTarget.dataset.example
    if (example && this.hasInputTarget) {
      this.inputTarget.value = example
      this.inputTarget.focus()
    }
  }

  showLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.remove("hidden")
    }
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = true
    }
  }

  hideLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.add("hidden")
    }
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = false
    }
  }

  displayResults(data) {
    if (!this.hasResultsTarget) return

    this.resultsTarget.innerHTML = `
      <div class="bg-gray-50 rounded-lg p-4">
        <h4 class="font-semibold text-gray-900 mb-2">Query Results</h4>
        <div class="text-gray-700">
          ${data.response || "No results found"}
        </div>
      </div>
    `
    
    this.resultsTarget.classList.remove("hidden")
  }

  showError(message) {
    if (!this.hasResultsTarget) return

    this.resultsTarget.innerHTML = `
      <div class="bg-red-50 rounded-lg p-4">
        <p class="text-red-700">${message}</p>
      </div>
    `
    
    this.resultsTarget.classList.remove("hidden")
  }

  clearResults() {
    if (this.hasResultsTarget) {
      this.resultsTarget.innerHTML = ""
      this.resultsTarget.classList.add("hidden")
    }
    if (this.hasInputTarget) {
      this.inputTarget.value = ""
      this.inputTarget.focus()
    }
  }
};
