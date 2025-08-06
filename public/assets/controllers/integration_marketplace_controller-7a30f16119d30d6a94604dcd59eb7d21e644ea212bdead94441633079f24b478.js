import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["integration", "filterBtn", "searchInput"]
  
  connect() {
    // Initialize filter buttons
    this.filterBtns = this.element.querySelectorAll('.filter-btn')
    this.filterBtns.forEach(btn => {
      btn.addEventListener('click', (e) => this.filter(e))
    })
  }
  
  search(event) {
    const searchTerm = event.target.value.toLowerCase()
    const integrations = this.element.querySelectorAll('[data-integration]')
    
    integrations.forEach(card => {
      const name = card.querySelector('h3')?.textContent.toLowerCase() || ''
      const description = card.querySelector('p')?.textContent.toLowerCase() || ''
      const type = card.dataset.integration
      
      if (name.includes(searchTerm) || description.includes(searchTerm) || type.includes(searchTerm)) {
        card.style.display = ''
      } else {
        card.style.display = 'none'
      }
    })
  }
  
  filter(event) {
    const btn = event.currentTarget
    const filter = btn.dataset.filter
    
    // Update active state
    this.filterBtns.forEach(b => b.classList.remove('active'))
    btn.classList.add('active')
    
    // Apply filter
    const integrations = this.element.querySelectorAll('[data-integration]')
    
    integrations.forEach(card => {
      switch(filter) {
        case 'all':
          card.style.display = ''
          break
        case 'connected':
          card.style.display = card.classList.contains('connected-card') ? '' : 'none'
          break
        case 'popular':
          const popularTypes = ['shopify', 'stripe', 'quickbooks', 'google_analytics', 'mailchimp']
          card.style.display = popularTypes.includes(card.dataset.integration) ? '' : 'none'
          break
        case 'new':
          const newTypes = ['hubspot', 'salesforce', 'amazon']
          card.style.display = newTypes.includes(card.dataset.integration) ? '' : 'none'
          break
        default:
          card.style.display = ''
      }
    })
  }
  
  disconnect() {
    // Cleanup
    this.filterBtns.forEach(btn => {
      btn.removeEventListener('click', this.filter)
    })
  }
};
