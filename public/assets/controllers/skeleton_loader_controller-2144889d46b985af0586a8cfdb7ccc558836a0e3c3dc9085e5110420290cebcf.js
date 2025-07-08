import { Controller } from "@hotwired/stimulus"

// Skeleton loader for smooth loading states
export default class extends Controller {
  static targets = ["content", "skeleton"]
  static values = { 
    url: String,
    type: String,
    autoLoad: Boolean 
  }
  
  connect() {
    if (this.autoLoadValue) {
      this.load()
    }
  }
  
  load() {
    // Show skeleton
    this.showSkeleton()
    
    // Fetch content
    if (this.urlValue) {
      fetch(this.urlValue, {
        headers: {
          'Accept': 'text/html',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      .then(response => response.text())
      .then(html => {
        // Minimum loading time for better UX
        setTimeout(() => {
          this.showContent(html)
        }, 300)
      })
      .catch(error => {
        console.error('Error loading content:', error)
        this.showError()
      })
    }
  }
  
  showSkeleton() {
    if (this.hasContentTarget) {
      this.contentTarget.style.display = 'none'
    }
    
    if (this.hasSkeletonTarget) {
      this.skeletonTarget.style.display = 'block'
      this.animateSkeleton()
    } else {
      // Create skeleton dynamically based on type
      this.createSkeleton()
    }
  }
  
  createSkeleton() {
    const skeleton = document.createElement('div')
    skeleton.className = 'skeleton-container'
    skeleton.setAttribute('data-skeleton-loader-target', 'skeleton')
    
    switch(this.typeValue || 'text') {
      case 'card':
        skeleton.innerHTML = this.cardSkeleton()
        break
      case 'table':
        skeleton.innerHTML = this.tableSkeleton()
        break
      case 'list':
        skeleton.innerHTML = this.listSkeleton()
        break
      default:
        skeleton.innerHTML = this.textSkeleton()
    }
    
    this.element.appendChild(skeleton)
    this.animateSkeleton()
  }
  
  cardSkeleton() {
    return `
      <div class="space-y-4">
        ${[1,2,3].map(() => `
          <div class="bg-white rounded-xl p-6 shadow-lg">
            <div class="flex items-center space-x-4 mb-4">
              <div class="skeleton-circle w-12 h-12"></div>
              <div class="flex-1 space-y-2">
                <div class="skeleton-line h-4 w-1/3"></div>
                <div class="skeleton-line h-3 w-1/2"></div>
              </div>
            </div>
            <div class="space-y-2">
              <div class="skeleton-line h-3"></div>
              <div class="skeleton-line h-3 w-5/6"></div>
              <div class="skeleton-line h-3 w-4/6"></div>
            </div>
          </div>
        `).join('')}
      </div>
    `
  }
  
  tableSkeleton() {
    return `
      <div class="bg-white rounded-xl shadow-lg overflow-hidden">
        <div class="p-4 border-b">
          <div class="skeleton-line h-6 w-1/4"></div>
        </div>
        <table class="w-full">
          <thead>
            <tr class="border-b bg-gray-50">
              ${[1,2,3,4].map(() => `
                <th class="p-4">
                  <div class="skeleton-line h-4 w-20"></div>
                </th>
              `).join('')}
            </tr>
          </thead>
          <tbody>
            ${[1,2,3,4,5].map(() => `
              <tr class="border-b">
                ${[1,2,3,4].map(() => `
                  <td class="p-4">
                    <div class="skeleton-line h-4"></div>
                  </td>
                `).join('')}
              </tr>
            `).join('')}
          </tbody>
        </table>
      </div>
    `
  }
  
  listSkeleton() {
    return `
      <div class="space-y-3">
        ${[1,2,3,4,5].map(() => `
          <div class="flex items-center space-x-3 p-4 bg-white rounded-lg shadow">
            <div class="skeleton-circle w-10 h-10"></div>
            <div class="flex-1 space-y-2">
              <div class="skeleton-line h-4 w-1/3"></div>
              <div class="skeleton-line h-3 w-1/2"></div>
            </div>
          </div>
        `).join('')}
      </div>
    `
  }
  
  textSkeleton() {
    return `
      <div class="space-y-3">
        <div class="skeleton-line h-8 w-1/3"></div>
        <div class="skeleton-line h-4"></div>
        <div class="skeleton-line h-4 w-5/6"></div>
        <div class="skeleton-line h-4 w-4/6"></div>
      </div>
    `
  }
  
  animateSkeleton() {
    // Add shimmer animation
    const skeletons = this.element.querySelectorAll('.skeleton-line, .skeleton-circle')
    skeletons.forEach(skeleton => {
      skeleton.style.background = 'linear-gradient(90deg, #f0f0f0 25%, #e0e0e0 50%, #f0f0f0 75%)'
      skeleton.style.backgroundSize = '200% 100%'
      skeleton.style.animation = 'shimmer 1.5s infinite'
    })
  }
  
  showContent(html = null) {
    // Fade out skeleton
    if (this.hasSkeletonTarget) {
      this.skeletonTarget.style.opacity = '0'
      this.skeletonTarget.style.transition = 'opacity 0.3s ease-out'
      
      setTimeout(() => {
        this.skeletonTarget.remove()
      }, 300)
    }
    
    // Update and show content
    if (html && this.hasContentTarget) {
      this.contentTarget.innerHTML = html
    }
    
    if (this.hasContentTarget) {
      this.contentTarget.style.display = 'block'
      this.contentTarget.style.opacity = '0'
      
      requestAnimationFrame(() => {
        this.contentTarget.style.transition = 'opacity 0.3s ease-in'
        this.contentTarget.style.opacity = '1'
      })
    }
  }
  
  showError() {
    if (this.hasSkeletonTarget) {
      this.skeletonTarget.innerHTML = `
        <div class="text-center py-8">
          <div class="text-red-500 text-5xl mb-4">⚠️</div>
          <p class="text-gray-600">Failed to load content</p>
          <button class="mt-4 px-4 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition-colors"
                  data-action="click->skeleton-loader#load">
            Retry
          </button>
        </div>
      `
    }
  }
};
