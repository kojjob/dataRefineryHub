import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results"]
  static values = { 
    url: String,
    minLength: { type: Number, default: 2 },
    debounce: { type: Number, default: 300 }
  }

  connect() {
    this.timeout = null
    this.isOpen = false
    this.boundHandleClickOutside = this.handleClickOutside.bind(this)
    this.boundHandleKeydown = this.handleKeydown.bind(this)
    
    // Add keyboard shortcut listener (Cmd+K)
    document.addEventListener('keydown', this.boundHandleKeydown)
  }

  disconnect() {
    if (this.timeout) clearTimeout(this.timeout)
    document.removeEventListener('click', this.boundHandleClickOutside)
    document.removeEventListener('keydown', this.boundHandleKeydown)
  }

  handleKeydown(event) {
    // Handle Cmd+K or Ctrl+K to focus search
    if ((event.metaKey || event.ctrlKey) && event.key === 'k') {
      event.preventDefault()
      this.inputTarget.focus()
      this.inputTarget.select()
    }
    
    // Handle Escape to close search results
    if (event.key === 'Escape' && this.isOpen) {
      this.hideResults()
      this.inputTarget.blur()
    }
  }

  handleInput(event) {
    const query = event.target.value.trim()
    
    // Clear existing timeout
    if (this.timeout) clearTimeout(this.timeout)
    
    if (query.length < this.minLengthValue) {
      this.showEmptyState()
      return
    }
    
    // Debounce the search
    this.timeout = setTimeout(() => {
      this.performSearch(query)
    }, this.debounceValue)
  }

  handleFocus() {
    const query = this.inputTarget.value.trim()
    if (query.length >= this.minLengthValue) {
      this.showResults()
    } else {
      this.showEmptyState()
    }
  }

  handleBlur(event) {
    // Delay hiding to allow clicking on results
    setTimeout(() => {
      if (!this.element.contains(document.activeElement)) {
        this.hideResults()
      }
    }, 200)
  }

  handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.hideResults()
    }
  }

  performSearch(query) {
    this.showLoadingState()
    
    // Mock search results for now - replace with actual API call
    setTimeout(() => {
      const mockResults = this.generateMockResults(query)
      this.displayResults(mockResults)
    }, 500)
    
    /* 
    // Real implementation would be:
    fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`, {
      headers: {
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    .then(response => response.json())
    .then(data => this.displayResults(data))
    .catch(error => this.showErrorState(error))
    */
  }

  generateMockResults(query) {
    const mockData = [
      { type: 'customer', title: 'John Smith', subtitle: 'john.smith@email.com', url: '#', icon: 'user' },
      { type: 'order', title: `Order #${Math.floor(Math.random() * 10000)}`, subtitle: `$${(Math.random() * 500 + 50).toFixed(2)} • 2 items`, url: '#', icon: 'shopping-bag' },
      { type: 'product', title: `Product containing "${query}"`, subtitle: '$29.99 • In stock', url: '#', icon: 'cube' },
      { type: 'customer', title: 'Sarah Johnson', subtitle: 'sarah.j@company.com', url: '#', icon: 'user' }
    ]
    
    return mockData.filter(item => 
      item.title.toLowerCase().includes(query.toLowerCase())
    ).slice(0, 6)
  }

  displayResults(results) {
    if (results.length === 0) {
      this.showNoResultsState()
      return
    }

    const resultsHTML = results.map(result => {
      const iconSVG = this.getIconSVG(result.icon)
      const typeColor = this.getTypeColor(result.type)
      
      return `
        <a href="${result.url}" class="flex items-center gap-4 px-6 py-4 hover:bg-gray-50 transition-colors duration-200 group">
          <div class="flex-shrink-0">
            <div class="h-10 w-10 rounded-xl ${typeColor} flex items-center justify-center">
              ${iconSVG}
            </div>
          </div>
          <div class="flex-1 min-w-0">
            <div class="text-sm font-semibold text-gray-900 group-hover:text-blue-600 transition-colors duration-200">
              ${result.title}
            </div>
            <div class="text-xs text-gray-500 mt-1">${result.subtitle}</div>
          </div>
          <div class="flex-shrink-0">
            <span class="inline-flex items-center px-2 py-1 rounded-lg text-xs font-medium ${this.getTypeBadgeColor(result.type)}">
              ${result.type}
            </span>
          </div>
        </a>
      `
    }).join('')

    this.resultsTarget.innerHTML = `
      <div class="py-2">
        <div class="px-6 py-3 border-b border-gray-100">
          <div class="flex items-center justify-between">
            <p class="text-sm font-semibold text-gray-900">Search Results</p>
            <span class="text-xs text-gray-500">${results.length} found</span>
          </div>
        </div>
        ${resultsHTML}
        <div class="px-6 py-3 border-t border-gray-100 bg-gray-50">
          <p class="text-xs text-gray-500 text-center">
            Press <kbd class="px-1.5 py-0.5 text-xs font-semibold text-gray-800 bg-white border border-gray-200 rounded">↵</kbd> to select • <kbd class="px-1.5 py-0.5 text-xs font-semibold text-gray-800 bg-white border border-gray-200 rounded">ESC</kbd> to close
          </p>
        </div>
      </div>
    `
    
    this.showResults()
  }

  showEmptyState() {
    this.resultsTarget.innerHTML = `
      <div class="p-6 text-center text-gray-500 text-sm">
        <svg class="mx-auto h-8 w-8 mb-3 text-gray-300" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
        </svg>
        <p class="font-medium mb-1">Start your search</p>
        <p class="text-xs text-gray-400">Search for customers, orders, products and more...</p>
      </div>
    `
    this.showResults()
  }

  showLoadingState() {
    this.resultsTarget.innerHTML = `
      <div class="p-6 text-center">
        <div class="inline-flex items-center gap-2 text-sm text-gray-500">
          <svg class="animate-spin h-4 w-4" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" fill="none"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          Searching...
        </div>
      </div>
    `
    this.showResults()
  }

  showNoResultsState() {
    this.resultsTarget.innerHTML = `
      <div class="p-6 text-center text-gray-500 text-sm">
        <svg class="mx-auto h-8 w-8 mb-3 text-gray-300" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" d="M15.182 16.318A4.486 4.486 0 0012.016 15a4.486 4.486 0 00-3.198 1.318M21 12a9 9 0 11-18 0 9 9 0 0118 0zM9.75 9.75c0 .414-.168.75-.375.75S9 10.164 9 9.75 9.168 9 9.375 9s.375.336.375.75zm-.375 0h.008v.015h-.008V9.75zm5.625 0c0 .414-.168.75-.375.75s-.375-.336-.375-.75.168-.75.375-.75.375.336.375.75zm-.375 0h.008v.015h-.008V9.75z" />
        </svg>
        <p class="font-medium mb-1">No results found</p>
        <p class="text-xs text-gray-400">Try adjusting your search terms</p>
      </div>
    `
    this.showResults()
  }

  showErrorState(error) {
    this.resultsTarget.innerHTML = `
      <div class="p-6 text-center text-red-500 text-sm">
        <svg class="mx-auto h-8 w-8 mb-3 text-red-300" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z" />
        </svg>
        <p class="font-medium mb-1">Search error</p>
        <p class="text-xs text-red-400">Please try again</p>
      </div>
    `
    this.showResults()
  }

  showResults() {
    this.resultsTarget.classList.remove('hidden')
    this.isOpen = true
    document.addEventListener('click', this.boundHandleClickOutside)
  }

  hideResults() {
    this.resultsTarget.classList.add('hidden')
    this.isOpen = false
    document.removeEventListener('click', this.boundHandleClickOutside)
  }

  getIconSVG(iconType) {
    const icons = {
      user: `<svg class="h-5 w-5 text-white" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z" />
      </svg>`,
      'shopping-bag': `<svg class="h-5 w-5 text-white" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 10.5V6a3.75 3.75 0 10-7.5 0v4.5m11.356-1.993l1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 01-1.12-1.243l1.264-12A1.125 1.125 0 015.513 7.5h12.974c.576 0 1.059.435 1.119 1.007zM8.625 10.5a.375.375 0 11-.75 0 .375.375 0 01.75 0zm7.5 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z" />
      </svg>`,
      cube: `<svg class="h-5 w-5 text-white" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" d="M21 7.5l-9-5.25L3 7.5m18 0l-9 5.25m9-5.25v9l-9 5.25M3 7.5l9 5.25M3 7.5v9l9 5.25m0-9v9" />
      </svg>`
    }
    return icons[iconType] || icons.cube
  }

  getTypeColor(type) {
    const colors = {
      customer: 'bg-blue-500',
      order: 'bg-green-500',
      product: 'bg-purple-500'
    }
    return colors[type] || 'bg-gray-500'
  }

  getTypeBadgeColor(type) {
    const colors = {
      customer: 'bg-blue-100 text-blue-800',
      order: 'bg-green-100 text-green-800',
      product: 'bg-purple-100 text-purple-800'
    }
    return colors[type] || 'bg-gray-100 text-gray-800'
  }
};
