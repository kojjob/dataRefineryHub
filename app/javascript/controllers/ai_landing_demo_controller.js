import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "dynamicSubheadline", "primaryCTA", "liveDemo", "liveInsight", 
    "featureCard", "uploadDemo", "demoResults", "demoModal", "modalContent"
  ]
  
  static values = {
    personalization: Object
  }

  connect() {
    console.log("AI Landing Demo controller connected")
    this.startLiveUpdates()
    this.initializePersonalization()
    this.setupAnimations()
  }

  disconnect() {
    this.stopLiveUpdates()
  }

  initializePersonalization() {
    if (this.personalizationValue) {
      this.applyPersonalization()
    }
  }

  applyPersonalization() {
    const personalization = this.personalizationValue
    
    // Update primary CTA based on visitor context
    if (this.hasPrimaryCTATarget) {
      this.primaryCTATarget.textContent = personalization.primary_cta || "Start Free Trial"
    }

    // Update subheadline for business type
    if (this.hasDynamicSubheadlineTarget && personalization.likely_business_type) {
      this.updateSubheadlineForBusinessType(personalization.likely_business_type)
    }
  }

  updateSubheadlineForBusinessType(businessType) {
    const messages = {
      ecommerce: "AI agent monitors your store 24/7, predicts revenue drops, and alerts you to opportunities before your competitors notice.",
      saas: "Autonomous intelligence that predicts churn, identifies expansion opportunities, and optimizes your entire customer journey.",
      agency: "AI-powered insights that help you deliver better client results and identify new revenue streams across all campaigns.",
      general: "The first truly autonomous business intelligence platform. AI monitors your business, predicts outcomes, and prevents problems before they happen."
    }

    const message = messages[businessType] || messages.general
    this.animateTextChange(this.dynamicSubheadlineTarget, message)
  }

  startLiveUpdates() {
    // Simulate live data updates
    this.updateInterval = setInterval(() => {
      this.updateLiveMetrics()
      this.rotateInsights()
    }, 5000) // Update every 5 seconds

    // Start the animation sequence
    this.animateFeatureCards()
  }

  stopLiveUpdates() {
    if (this.updateInterval) {
      clearInterval(this.updateInterval)
    }
  }

  updateLiveMetrics() {
    // Simulate real-time metric updates
    const revenueElement = document.querySelector('[data-live-metrics-target="revenue"]')
    const usersElement = document.querySelector('[data-live-metrics-target="users"]')
    const timestampElement = document.querySelector('[data-live-metrics-target="timestamp"]')

    if (revenueElement) {
      const currentRevenue = parseInt(revenueElement.textContent.replace(/[^0-9]/g, ''))
      const variation = Math.floor(Math.random() * 100) - 50 // ±50
      const newRevenue = Math.max(currentRevenue + variation, 1000)
      this.animateNumberChange(revenueElement, newRevenue, '$')
    }

    if (usersElement) {
      const currentUsers = parseInt(usersElement.textContent)
      const variation = Math.floor(Math.random() * 20) - 10 // ±10
      const newUsers = Math.max(currentUsers + variation, 50)
      this.animateNumberChange(usersElement, newUsers)
    }

    if (timestampElement) {
      timestampElement.textContent = 'Just now'
    }
  }

  animateNumberChange(element, newValue, prefix = '') {
    element.style.transform = 'scale(1.1)'
    element.style.color = '#10b981' // green-500
    
    setTimeout(() => {
      element.textContent = prefix + newValue.toLocaleString()
      element.style.transform = 'scale(1)'
      element.style.color = ''
    }, 200)
  }

  rotateInsights() {
    if (!this.hasLiveInsightTarget) return

    const insights = [
      {
        description: "AI identified 15% revenue increase opportunity in mobile checkout flow",
        confidence: 92,
        impact: "$12,500/month"
      },
      {
        description: "Unusual traffic pattern detected - 30% spike from social media campaigns",
        confidence: 87,
        impact: "Monitor closely"
      },
      {
        description: "Customer churn risk increased 12% - recommend retention campaign",
        confidence: 94,
        impact: "Action needed"
      },
      {
        description: "Inventory levels trending low for top 3 products",
        confidence: 89,
        impact: "Reorder recommended"
      }
    ]

    const randomInsight = insights[Math.floor(Math.random() * insights.length)]
    
    // Fade out
    this.liveInsightTarget.style.opacity = '0.5'
    
    setTimeout(() => {
      // Update content
      this.liveInsightTarget.textContent = randomInsight.description
      
      // Update confidence and impact
      const confidenceElement = this.liveInsightTarget.parentElement.querySelector('.confidence')
      const impactElement = this.liveInsightTarget.parentElement.querySelector('.impact')
      
      if (confidenceElement) {
        confidenceElement.textContent = `Confidence: ${randomInsight.confidence}%`
      }
      if (impactElement) {
        impactElement.textContent = randomInsight.impact
      }
      
      // Fade in
      this.liveInsightTarget.style.opacity = '1'
    }, 300)
  }

  animateFeatureCards() {
    if (!this.hasFeatureCardTargets) return

    this.featureCardTargets.forEach((card, index) => {
      setTimeout(() => {
        card.style.opacity = '0'
        card.style.transform = 'translateY(30px)'
        
        setTimeout(() => {
          card.style.transition = 'all 0.6s ease-out'
          card.style.opacity = '1'
          card.style.transform = 'translateY(0)'
        }, 100)
      }, index * 200)
    })
  }

  animateTextChange(element, newText) {
    element.style.transition = 'opacity 0.3s ease'
    element.style.opacity = '0.5'
    
    setTimeout(() => {
      element.textContent = newText
      element.style.opacity = '1'
    }, 300)
  }

  // Interactive demo actions

  showLiveDemo() {
    this.openModal('live-analytics')
    this.trackEvent('demo_viewed', { type: 'live_analytics' })
  }

  showFeatureDemo(event) {
    const feature = event.currentTarget.dataset.feature
    this.openModal('feature-demo', { feature })
    this.trackEvent('demo_viewed', { type: 'feature', feature })
  }

  showRealTimeDemo() {
    this.openModal('real-time-analytics')
    this.trackEvent('demo_viewed', { type: 'real_time' })
  }

  triggerFileUpload() {
    // Simulate file upload for demo
    if (this.hasUploadDemoTarget) {
      this.uploadDemoTarget.style.border = '2px solid #8b5cf6'
      this.uploadDemoTarget.innerHTML = `
        <div class="text-center">
          <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-purple-600 mx-auto mb-4"></div>
          <p class="text-purple-600 font-medium">Analyzing your data with AI...</p>
        </div>
      `
      
      setTimeout(() => {
        this.showDemoResults()
      }, 2000)
    }
    
    this.trackEvent('demo_interaction', { type: 'file_upload' })
  }

  useDemoData() {
    this.triggerFileUpload() // Same animation for demo
    this.trackEvent('demo_interaction', { type: 'demo_data' })
  }

  showDemoResults() {
    if (this.hasDemoResultsTarget) {
      this.demoResultsTarget.classList.remove('hidden')
      this.demoResultsTarget.style.opacity = '0'
      this.demoResultsTarget.style.transform = 'translateY(20px)'
      
      setTimeout(() => {
        this.demoResultsTarget.style.transition = 'all 0.6s ease-out'
        this.demoResultsTarget.style.opacity = '1'
        this.demoResultsTarget.style.transform = 'translateY(0)'
      }, 100)
    }

    // Reset upload area
    if (this.hasUploadDemoTarget) {
      this.uploadDemoTarget.style.border = '2px dashed #d1d5db'
      this.uploadDemoTarget.innerHTML = `
        <svg class="mx-auto h-12 w-12 text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 48 48">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02"></path>
        </svg>
        <h4 class="text-lg font-semibold text-gray-900 mb-2">Analysis Complete!</h4>
        <p class="text-green-600 mb-4">AI found valuable insights in your data</p>
        <div class="flex flex-col sm:flex-row gap-3 justify-center">
          <button class="px-6 py-2 bg-green-600 text-white font-medium rounded-lg">
            View Full Report
          </button>
          <button class="px-6 py-2 border border-gray-300 text-gray-700 font-medium rounded-lg" data-action="click->ai-landing-demo#resetDemo">
            Try Another File
          </button>
        </div>
      `
    }
  }

  resetDemo() {
    if (this.hasDemoResultsTarget) {
      this.demoResultsTarget.classList.add('hidden')
    }
    
    if (this.hasUploadDemoTarget) {
      this.uploadDemoTarget.style.border = '2px dashed #d1d5db'
      this.uploadDemoTarget.innerHTML = `
        <svg class="mx-auto h-12 w-12 text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 48 48">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02"></path>
        </svg>
        <h4 class="text-lg font-semibold text-gray-900 mb-2">Drop your CSV, Excel, or JSON file</h4>
        <p class="text-gray-600 mb-4">Or click to browse files</p>
        <div class="flex flex-col sm:flex-row gap-3 justify-center">
          <button class="px-6 py-2 bg-purple-600 text-white font-medium rounded-lg hover:bg-purple-700 transition-colors duration-300" data-action="click->ai-landing-demo#triggerFileUpload">
            Choose File
          </button>
          <button class="px-6 py-2 border border-gray-300 text-gray-700 font-medium rounded-lg hover:bg-gray-50 transition-colors duration-300" data-action="click->ai-landing-demo#useDemoData">
            Use Demo Data
          </button>
        </div>
      `
    }
  }

  scheduleDemo() {
    // In a real implementation, this would open a calendar booking widget
    alert('Demo scheduling feature would be integrated with Calendly or similar service.')
    this.trackEvent('demo_scheduled')
  }

  trackCTA() {
    this.trackEvent('cta_clicked', { 
      cta_text: this.primaryCTATarget?.textContent || 'Start Free Trial',
      personalization: this.personalizationValue
    })
  }

  // Modal management

  openModal(type, options = {}) {
    if (!this.hasDemoModalTarget) return

    const content = this.generateModalContent(type, options)
    
    if (this.hasModalContentTarget) {
      this.modalContentTarget.innerHTML = content
    }

    this.demoModalTarget.classList.remove('hidden')
    document.body.style.overflow = 'hidden'

    // Close modal on escape key
    this.escapeListener = (e) => {
      if (e.key === 'Escape') {
        this.closeModal()
      }
    }
    document.addEventListener('keydown', this.escapeListener)

    // Close modal on backdrop click
    this.demoModalTarget.addEventListener('click', (e) => {
      if (e.target === this.demoModalTarget) {
        this.closeModal()
      }
    })
  }

  closeModal() {
    if (this.hasDemoModalTarget) {
      this.demoModalTarget.classList.add('hidden')
      document.body.style.overflow = ''
    }

    if (this.escapeListener) {
      document.removeEventListener('keydown', this.escapeListener)
    }
  }

  generateModalContent(type, options) {
    switch (type) {
      case 'live-analytics':
        return this.generateLiveAnalyticsModal()
      case 'feature-demo':
        return this.generateFeatureDemoModal(options.feature)
      case 'real-time-analytics':
        return this.generateRealTimeModal()
      default:
        return '<p>Demo content loading...</p>'
    }
  }

  generateLiveAnalyticsModal() {
    return `
      <div class="flex justify-between items-center mb-6">
        <h3 class="text-2xl font-bold text-gray-900">Live AI Analytics Demo</h3>
        <button data-action="click->ai-landing-demo#closeModal" class="text-gray-400 hover:text-gray-600">
          <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        </button>
      </div>
      
      <div class="grid md:grid-cols-2 gap-8">
        <div>
          <h4 class="text-lg font-semibold mb-4">Real-Time Business Monitoring</h4>
          <p class="text-gray-600 mb-6">See how our AI continuously monitors your business metrics and provides instant insights.</p>
          
          <div class="space-y-4">
            <div class="flex items-center text-sm">
              <div class="h-2 w-2 bg-green-500 rounded-full mr-3 animate-pulse"></div>
              <span>24/7 autonomous monitoring active</span>
            </div>
            <div class="flex items-center text-sm">
              <div class="h-2 w-2 bg-blue-500 rounded-full mr-3 animate-pulse"></div>
              <span>Predictive analytics running</span>
            </div>
            <div class="flex items-center text-sm">
              <div class="h-2 w-2 bg-purple-500 rounded-full mr-3 animate-pulse"></div>
              <span>Anomaly detection enabled</span>
            </div>
          </div>
          
          <div class="mt-6">
            <button class="px-6 py-3 bg-blue-600 text-white font-semibold rounded-lg hover:bg-blue-700 transition-colors">
              Start Your AI Trial
            </button>
          </div>
        </div>
        
        <div>
          <div class="bg-gray-50 rounded-xl p-6">
            <div class="text-center">
              <div class="text-3xl font-bold text-blue-600 mb-2">94.7%</div>
              <div class="text-sm text-gray-600 mb-4">Prediction Accuracy</div>
              
              <div class="text-2xl font-bold text-green-600 mb-2">$2.5M+</div>
              <div class="text-sm text-gray-600 mb-4">Revenue Protected</div>
              
              <div class="text-2xl font-bold text-purple-600 mb-2">2.5M</div>
              <div class="text-sm text-gray-600">Anomalies Detected</div>
            </div>
          </div>
        </div>
      </div>
    `
  }

  generateFeatureDemoModal(feature) {
    const features = {
      'autonomous-business-intelligence-agent': {
        title: 'Autonomous Business Intelligence Agent',
        description: 'AI that works 24/7 to monitor, analyze, and optimize your business',
        benefits: [
          'Proactive opportunity identification',
          'Risk prediction 2+ weeks early',
          'Automated competitive analysis',
          'Self-improving recommendations'
        ]
      },
      'real-time-anomaly-detection': {
        title: 'Real-Time Anomaly Detection',
        description: 'Advanced ML algorithms that learn your patterns and detect issues instantly',
        benefits: [
          'Dynamic threshold learning',
          'False positive reduction',
          'Multi-dimensional analysis',
          'Instant alerting system'
        ]
      },
      'enhanced-data-intelligence': {
        title: 'Enhanced Data Intelligence',
        description: 'AI that understands your business context and maximizes data value',
        benefits: [
          'Automatic business context detection',
          'Data quality optimization',
          'ROI impact estimation',
          'Smart transformation suggestions'
        ]
      }
    }

    const featureData = features[feature] || features['autonomous-business-intelligence-agent']

    return `
      <div class="flex justify-between items-center mb-6">
        <h3 class="text-2xl font-bold text-gray-900">${featureData.title}</h3>
        <button data-action="click->ai-landing-demo#closeModal" class="text-gray-400 hover:text-gray-600">
          <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        </button>
      </div>
      
      <p class="text-xl text-gray-600 mb-8">${featureData.description}</p>
      
      <div class="grid md:grid-cols-2 gap-8">
        <div>
          <h4 class="text-lg font-semibold mb-4">Key Benefits</h4>
          <ul class="space-y-3">
            ${featureData.benefits.map(benefit => `
              <li class="flex items-center">
                <svg class="h-5 w-5 text-green-500 mr-3" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>
                </svg>
                ${benefit}
              </li>
            `).join('')}
          </ul>
          
          <div class="mt-8">
            <button class="px-6 py-3 bg-purple-600 text-white font-semibold rounded-lg hover:bg-purple-700 transition-colors mr-4">
              Try This Feature
            </button>
            <button data-action="click->ai-landing-demo#closeModal" class="px-6 py-3 border border-gray-300 text-gray-700 font-semibold rounded-lg hover:bg-gray-50 transition-colors">
              Continue Browsing
            </button>
          </div>
        </div>
        
        <div>
          <div class="bg-gradient-to-br from-blue-50 to-purple-50 rounded-xl p-6">
            <h5 class="font-semibold text-gray-900 mb-4">Live Demo Environment</h5>
            <div class="space-y-3 text-sm">
              <div class="flex justify-between">
                <span>Status:</span>
                <span class="text-green-600 font-medium">Active</span>
              </div>
              <div class="flex justify-between">
                <span>AI Confidence:</span>
                <span class="text-blue-600 font-medium">94.7%</span>
              </div>
              <div class="flex justify-between">
                <span>Processing Speed:</span>
                <span class="text-purple-600 font-medium">Real-time</span>
              </div>
              <div class="flex justify-between">
                <span>Data Sources:</span>
                <span class="text-indigo-600 font-medium">5 connected</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    `
  }

  generateRealTimeModal() {
    return `
      <div class="flex justify-between items-center mb-6">
        <h3 class="text-2xl font-bold text-gray-900">Real-Time Analytics Dashboard</h3>
        <button data-action="click->ai-landing-demo#closeModal" class="text-gray-400 hover:text-gray-600">
          <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        </button>
      </div>
      
      <div class="text-center mb-8">
        <p class="text-lg text-gray-600">Experience live business monitoring with AI-powered insights</p>
      </div>
      
      <!-- This would embed the actual real-time analytics widget -->
      <div class="bg-gray-100 rounded-xl p-8 text-center">
        <div class="animate-pulse">
          <div class="grid grid-cols-2 gap-4 mb-6">
            <div class="bg-white rounded-lg p-4">
              <div class="h-4 bg-gray-300 rounded mb-2"></div>
              <div class="h-8 bg-gray-300 rounded"></div>
            </div>
            <div class="bg-white rounded-lg p-4">
              <div class="h-4 bg-gray-300 rounded mb-2"></div>
              <div class="h-8 bg-gray-300 rounded"></div>
            </div>
          </div>
          <div class="bg-white rounded-lg p-4">
            <div class="h-4 bg-gray-300 rounded mb-2"></div>
            <div class="h-16 bg-gray-300 rounded"></div>
          </div>
        </div>
        <p class="text-gray-500 mt-4">Live dashboard loading...</p>
      </div>
      
      <div class="mt-8 text-center">
        <button class="px-8 py-3 bg-green-600 text-white font-bold rounded-lg hover:bg-green-700 transition-colors">
          Get Full Access
        </button>
      </div>
    `
  }

  // Analytics tracking

  trackEvent(eventName, properties = {}) {
    // In a real implementation, this would send to analytics service
    console.log('Landing Page Event:', eventName, properties)
    
    // Example integration with analytics services:
    // gtag('event', eventName, properties)
    // analytics.track(eventName, properties)
  }

  setupAnimations() {
    // Set up intersection observer for scroll animations
    const observerOptions = {
      threshold: 0.1,
      rootMargin: '0px 0px -50px 0px'
    }

    this.observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.classList.add('animate-fade-in-up')
        }
      })
    }, observerOptions)

    // Observe feature cards and other elements
    this.featureCardTargets.forEach(card => {
      this.observer.observe(card)
    })
  }
}