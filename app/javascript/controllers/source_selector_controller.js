import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["searchInput", "categoryTab", "sourceCard", "selectedSource", "noResults"]
  static values = { selectedType: String }

  connect() {
    this.sourceCategories = {
      'ecommerce': {
        name: 'E-commerce',
        icon: '🛒',
        sources: ['shopify', 'woocommerce', 'amazon_seller_central']
      },
      'financial': {
        name: 'Financial',
        icon: '💰',
        sources: ['stripe', 'quickbooks']
      },
      'marketing': {
        name: 'Marketing & Analytics',
        icon: '📊',
        sources: ['google_analytics', 'facebook_ads', 'google_ads', 'mailchimp']
      },
      'support': {
        name: 'Customer Support',
        icon: '🎧',
        sources: ['zendesk', 'hubspot']
      },
      'data': {
        name: 'Data Import',
        icon: '📁',
        sources: ['file_upload', 'custom_api']
      }
    }

    this.sourceMetadata = {
      'shopify': {
        name: 'Shopify',
        description: 'Import orders, customers, products, and inventory data from your Shopify store',
        status: 'available',
        priority: 'high',
        icon: '🛍️',
        color: 'green'
      },
      'woocommerce': {
        name: 'WooCommerce',
        description: 'Connect your WordPress WooCommerce store for comprehensive e-commerce data',
        status: 'available',
        priority: 'high',
        icon: '🔌',
        color: 'purple'
      },
      'amazon_seller_central': {
        name: 'Amazon Seller Central',
        description: 'Import sales, inventory, and performance data from Amazon Seller Central',
        status: 'beta',
        priority: 'medium',
        icon: '📦',
        color: 'orange'
      },
      'stripe': {
        name: 'Stripe',
        description: 'Import payment transactions, customer data, and subscription metrics',
        status: 'available',
        priority: 'high',
        icon: '💳',
        color: 'indigo'
      },
      'quickbooks': {
        name: 'QuickBooks',
        description: 'Sync financial data, invoices, expenses, and customer information',
        status: 'available',
        priority: 'high',
        icon: '📊',
        color: 'blue'
      },
      'google_analytics': {
        name: 'Google Analytics',
        description: 'Import website traffic, user behavior, and conversion data',
        status: 'coming_soon',
        priority: 'high',
        icon: '📈',
        color: 'red'
      },
      'facebook_ads': {
        name: 'Facebook Ads',
        description: 'Import ad performance, audience insights, and campaign data',
        status: 'coming_soon',
        priority: 'medium',
        icon: '📱',
        color: 'blue'
      },
      'google_ads': {
        name: 'Google Ads',
        description: 'Import campaign performance, keyword data, and ad spend metrics',
        status: 'coming_soon',
        priority: 'medium',
        icon: '🎯',
        color: 'yellow'
      },
      'mailchimp': {
        name: 'Mailchimp',
        description: 'Import email campaign data, subscriber lists, and engagement metrics',
        status: 'coming_soon',
        priority: 'medium',
        icon: '📧',
        color: 'yellow'
      },
      'zendesk': {
        name: 'Zendesk',
        description: 'Import support tickets, customer interactions, and satisfaction data',
        status: 'coming_soon',
        priority: 'low',
        icon: '🎫',
        color: 'green'
      },
      'hubspot': {
        name: 'HubSpot',
        description: 'Import CRM data, lead information, and sales pipeline metrics',
        status: 'coming_soon',
        priority: 'medium',
        icon: '🏢',
        color: 'orange'
      },
      'file_upload': {
        name: 'File Upload',
        description: 'Upload CSV, Excel, JSON, or text files for data analysis and processing',
        status: 'available',
        priority: 'high',
        icon: '📄',
        color: 'emerald'
      },
      'custom_api': {
        name: 'Custom API',
        description: 'Connect to any REST API endpoint for custom data integration',
        status: 'beta',
        priority: 'medium',
        icon: '🔗',
        color: 'gray'
      }
    }

    this.currentCategory = 'ecommerce'
    this.initializeView()
  }

  initializeView() {
    this.showCategory(this.currentCategory)
    this.updateCategoryTabs()
  }

  selectCategory(event) {
    const category = event.currentTarget.dataset.category
    this.currentCategory = category
    this.showCategory(category)
    this.updateCategoryTabs()
  }

  showCategory(category) {
    const categoryData = this.sourceCategories[category]
    if (!categoryData) return

    // Hide all source cards
    this.sourceCardTargets.forEach(card => {
      card.classList.add('hidden')
    })

    // Show cards for this category
    categoryData.sources.forEach(sourceType => {
      const card = this.sourceCardTargets.find(c => c.dataset.sourceType === sourceType)
      if (card) {
        card.classList.remove('hidden')
      }
    })

    this.checkNoResults()
  }

  updateCategoryTabs() {
    this.categoryTabTargets.forEach(tab => {
      const category = tab.dataset.category
      if (category === this.currentCategory) {
        tab.classList.add('border-indigo-500', 'text-indigo-600')
        tab.classList.remove('border-transparent', 'text-gray-500', 'hover:text-gray-700', 'hover:border-gray-300')
      } else {
        tab.classList.remove('border-indigo-500', 'text-indigo-600')
        tab.classList.add('border-transparent', 'text-gray-500', 'hover:text-gray-700', 'hover:border-gray-300')
      }
    })
  }

  search(event) {
    const query = event.target.value.toLowerCase().trim()
    
    if (query === '') {
      this.showCategory(this.currentCategory)
      return
    }

    // Hide all cards first
    this.sourceCardTargets.forEach(card => {
      card.classList.add('hidden')
    })

    // Show matching cards
    let hasResults = false
    this.sourceCardTargets.forEach(card => {
      const sourceType = card.dataset.sourceType
      const metadata = this.sourceMetadata[sourceType]
      
      if (metadata) {
        const searchText = `${metadata.name} ${metadata.description}`.toLowerCase()
        if (searchText.includes(query)) {
          card.classList.remove('hidden')
          hasResults = true
        }
      }
    })

    this.checkNoResults()
  }

  selectSource(event) {
    const sourceCard = event.currentTarget;
    const sourceType = sourceCard.dataset.sourceType;
    const sourceStatus = sourceCard.dataset.sourceStatus;
    
    // Check if source is available and implemented
    if (sourceStatus === 'coming_soon') {
      const sourceData = this.sourceMetadata[sourceType];
      this.showComingSoonMessage(sourceData ? sourceData.name : sourceType);
      return;
    }

    // Update radio button
    const radioButton = sourceCard.querySelector('input[type="radio"]');
    if (radioButton && !radioButton.disabled) {
      radioButton.checked = true;
      this.selectedTypeValue = sourceType;
    }

    // Update visual selection
    this.sourceCardTargets.forEach(card => {
      card.classList.remove('ring-2', 'ring-blue-500', 'border-blue-500');
    });
    
    sourceCard.classList.add('ring-2', 'ring-blue-500', 'border-blue-500');

    // Update selected source display
    this.updateSelectedSourceDisplay(sourceType);

    // Dispatch custom event
    this.dispatch('sourceSelected', { detail: { sourceType, status: sourceStatus } });
  }

  updateSelectedSourceDisplay(sourceType, metadata) {
    if (this.hasSelectedSourceTarget) {
      this.selectedSourceTarget.innerHTML = `
        <div class="flex items-center space-x-3 p-4 bg-indigo-50 border border-indigo-200 rounded-lg">
          <div class="flex-shrink-0">
            <span class="text-2xl">${metadata.icon}</span>
          </div>
          <div class="flex-1">
            <h4 class="text-lg font-medium text-indigo-900">${metadata.name}</h4>
            <p class="text-sm text-indigo-700">${metadata.description}</p>
          </div>
          <div class="flex-shrink-0">
            ${this.getStatusBadge(metadata.status)}
          </div>
        </div>
      `
      this.selectedSourceTarget.classList.remove('hidden')
    }
  }

  getStatusBadge(status) {
    const badges = {
      'available': '<span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">Available</span>',
      'beta': '<span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">Beta</span>',
      'coming_soon': '<span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-gray-100 text-gray-600">Coming Soon</span>'
    };
    
    return badges[status] || badges['available'];
  }

  // Add method to handle clicks on disabled sources
  handleDisabledSourceClick(event) {
    event.preventDefault();
    event.stopPropagation();
    
    const sourceCard = event.currentTarget;
    const sourceType = sourceCard.dataset.sourceType;
    const sourceData = this.sourceMetadata[sourceType];
    
    this.showComingSoonMessage(sourceData ? sourceData.name : sourceType);
  }

  showComingSoonMessage(sourceName) {
    // Create a more user-friendly notification
    const message = `${sourceName} integration is currently in development. We're working hard to bring you this feature. Sign up for updates to be notified when it's available.`;
    
    // You can replace this with a toast notification or modal for better UX
    if (window.showToast) {
      window.showToast(message, 'info');
    } else {
      alert(message);
    }
  }

  checkNoResults() {
    const visibleCards = this.sourceCardTargets.filter(card => !card.classList.contains('hidden'))
    
    if (this.hasNoResultsTarget) {
      if (visibleCards.length === 0) {
        this.noResultsTarget.classList.remove('hidden')
      } else {
        this.noResultsTarget.classList.add('hidden')
      }
    }
  }

  clearSearch() {
    if (this.hasSearchInputTarget) {
      this.searchInputTarget.value = ''
      this.showCategory(this.currentCategory)
    }
  }

  // Get popular sources for highlighting
  getPopularSources() {
    return Object.entries(this.sourceMetadata)
      .filter(([_, metadata]) => metadata.priority === 'high' && metadata.status === 'available')
      .map(([sourceType, _]) => sourceType)
  }

  // Get source metadata for external access
  getSourceMetadata(sourceType) {
    return this.sourceMetadata[sourceType]
  }
}