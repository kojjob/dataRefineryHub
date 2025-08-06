import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "metric", "chart", "etlPipeline", "dataFlow", "processingNode", "connectionLine"]
  static values = {
    animationSpeed: { type: Number, default: 300 },
    realTimeEnabled: { type: Boolean, default: true },
    pipelineStatus: { type: String, default: "idle" }
  }

  connect() {
    this.initializeAnimations()
    this.setupETLPipelineVisualization()
    this.startRealTimeUpdates()
    this.createDataFlowParticles()
  }

  disconnect() {
    this.stopRealTimeUpdates()
    this.clearAnimationTimers()
  }

  initializeAnimations() {
    this.animateCardsOnLoad()
    this.animateMetrics()
    this.createFloatingElements()
    this.initializeProgressBars()
  }

  animateCardsOnLoad() {
    this.cardTargets.forEach((card, index) => {
      // Enhanced card entrance animation with stagger effect
      card.style.opacity = "0"
      card.style.transform = "translateY(40px) scale(0.95) rotateX(10deg)"
      card.style.filter = "blur(5px)"
      
      setTimeout(() => {
        card.style.transition = "all 0.8s cubic-bezier(0.34, 1.56, 0.64, 1)"
        card.style.opacity = "1"
        card.style.transform = "translateY(0) scale(1) rotateX(0deg)"
        card.style.filter = "blur(0px)"
        
        // Add hover effects after entrance
        this.addCardHoverEffects(card)
      }, index * 150)
    })
  }

  addCardHoverEffects(card) {
    card.addEventListener('mouseenter', () => {
      card.style.transform = 'translateY(-8px) scale(1.02)'
      card.style.boxShadow = '0 25px 50px -12px rgba(0, 0, 0, 0.25)'
    })
    
    card.addEventListener('mouseleave', () => {
      card.style.transform = 'translateY(0) scale(1)'
      card.style.boxShadow = ''
    })
  }

  animateMetrics() {
    this.metricTargets.forEach((metric, index) => {
      const finalValue = this.extractNumericValue(metric.textContent)
      const hasCommas = metric.textContent.includes(',')
      
      // Enhanced counter animation with easing
      this.animateCounter(metric, 0, finalValue, 2000, hasCommas, index * 200)
    })
  }

  animateCounter(element, start, end, duration, hasCommas = false, delay = 0) {
    setTimeout(() => {
      const startTime = performance.now()
      const animate = (currentTime) => {
        const elapsed = currentTime - startTime
        const progress = Math.min(elapsed / duration, 1)
        
        // Easing function for smooth animation
        const easeOutQuart = 1 - Math.pow(1 - progress, 4)
        const currentValue = Math.floor(start + (end - start) * easeOutQuart)
        
        element.textContent = hasCommas ? 
          this.formatNumberWithCommas(currentValue) : 
          this.formatNumber(currentValue)
        
        if (progress < 1) {
          requestAnimationFrame(animate)
        } else {
          // Add completion effect
          element.style.transform = 'scale(1.1)'
          setTimeout(() => {
            element.style.transform = 'scale(1)'
          }, 200)
        }
      }
      requestAnimationFrame(animate)
    }, delay)
  }

  setupETLPipelineVisualization() {
    if (this.etlPipelineTargets.length === 0) return
    
    this.etlPipelineTargets.forEach(pipeline => {
      this.createPipelineNodes(pipeline)
      this.animateDataFlow(pipeline)
    })
  }

  createPipelineNodes(pipeline) {
    const stages = ['Extract', 'Transform', 'Load']
    const colors = ['#3B82F6', '#8B5CF6', '#10B981']
    
    stages.forEach((stage, index) => {
      const node = document.createElement('div')
      node.className = `etl-node etl-${stage.toLowerCase()}`
      node.style.cssText = `
        position: relative;
        width: 120px;
        height: 120px;
        border-radius: 50%;
        background: linear-gradient(135deg, ${colors[index]}, ${this.lightenColor(colors[index], 20)});
        display: flex;
        align-items: center;
        justify-content: center;
        color: white;
        font-weight: bold;
        box-shadow: 0 10px 30px rgba(0,0,0,0.2);
        transition: all 0.3s ease;
        cursor: pointer;
      `
      node.textContent = stage
      
      // Add pulsing animation for active stages
      this.addNodePulseEffect(node, index)
      pipeline.appendChild(node)
      
      // Add connection lines between nodes
      if (index < stages.length - 1) {
        this.createConnectionLine(pipeline, index)
      }
    })
  }

  addNodePulseEffect(node, index) {
    setInterval(() => {
      node.style.transform = 'scale(1.05)'
      node.style.boxShadow = '0 15px 40px rgba(0,0,0,0.3)'
      
      setTimeout(() => {
        node.style.transform = 'scale(1)'
        node.style.boxShadow = '0 10px 30px rgba(0,0,0,0.2)'
      }, 300)
    }, 3000 + (index * 1000))
  }

  createConnectionLine(pipeline, index) {
    const line = document.createElement('div')
    line.className = 'connection-line'
    line.style.cssText = `
      position: absolute;
      width: 80px;
      height: 4px;
      background: linear-gradient(90deg, #6366F1, #8B5CF6);
      border-radius: 2px;
      left: ${140 + (index * 200)}px;
      top: 58px;
      opacity: 0.7;
    `
    
    // Add flowing animation
    this.addFlowingEffect(line)
    pipeline.appendChild(line)
  }

  addFlowingEffect(line) {
    const flow = document.createElement('div')
    flow.style.cssText = `
      position: absolute;
      width: 20px;
      height: 100%;
      background: linear-gradient(90deg, transparent, rgba(255,255,255,0.8), transparent);
      border-radius: 2px;
      animation: flow 2s linear infinite;
    `
    
    line.appendChild(flow)
  }

  createDataFlowParticles() {
    if (this.dataFlowTargets.length === 0) return
    
    this.dataFlowTargets.forEach(container => {
      this.generateParticles(container, 20)
    })
  }

  generateParticles(container, count) {
    for (let i = 0; i < count; i++) {
      const particle = document.createElement('div')
      particle.className = 'data-particle'
      particle.style.cssText = `
        position: absolute;
        width: 6px;
        height: 6px;
        background: radial-gradient(circle, #3B82F6, #1D4ED8);
        border-radius: 50%;
        opacity: 0;
        pointer-events: none;
      `
      
      container.appendChild(particle)
      this.animateParticle(particle, container)
    }
  }

  animateParticle(particle, container) {
    const animate = () => {
      const containerRect = container.getBoundingClientRect()
      const startX = Math.random() * containerRect.width
      const startY = Math.random() * containerRect.height
      const endX = Math.random() * containerRect.width
      const endY = Math.random() * containerRect.height
      
      particle.style.left = startX + 'px'
      particle.style.top = startY + 'px'
      particle.style.opacity = '1'
      
      particle.animate([
        { transform: `translate(0, 0)`, opacity: 1 },
        { transform: `translate(${endX - startX}px, ${endY - startY}px)`, opacity: 0 }
      ], {
        duration: 3000 + Math.random() * 2000,
        easing: 'ease-out'
      }).onfinish = () => {
        setTimeout(animate, Math.random() * 1000)
      }
    }
    
    setTimeout(animate, Math.random() * 2000)
  }

  createFloatingElements() {
    const floatingElements = document.querySelectorAll('.animate-float, .animate-float-delayed, .animate-float-delayed-2')
    
    floatingElements.forEach((element, index) => {
      const delay = index * 0.5
      element.style.animation = `float 6s ease-in-out infinite ${delay}s`
    })
  }

  initializeProgressBars() {
    const progressBars = document.querySelectorAll('.progress-bar')
    
    progressBars.forEach(bar => {
      const width = bar.style.width
      bar.style.width = '0%'
      
      setTimeout(() => {
        bar.style.transition = 'width 2s ease-out'
        bar.style.width = width
      }, 500)
    })
  }

  startRealTimeUpdates() {
    if (!this.realTimeEnabledValue) return
    
    this.updateInterval = setInterval(() => {
      this.updateMetrics()
      this.updatePipelineStatus()
    }, 5000)
  }

  stopRealTimeUpdates() {
    if (this.updateInterval) {
      clearInterval(this.updateInterval)
    }
  }

  updateMetrics() {
    // Simulate real-time metric updates
    this.metricTargets.forEach(metric => {
      const currentValue = this.extractNumericValue(metric.textContent)
      const variation = Math.floor(Math.random() * 10) - 5 // ±5 variation
      const newValue = Math.max(0, currentValue + variation)
      
      if (newValue !== currentValue) {
        this.animateCounter(metric, currentValue, newValue, 1000)
      }
    })
  }

  updatePipelineStatus() {
    const statuses = ['idle', 'extracting', 'transforming', 'loading', 'completed']
    const randomStatus = statuses[Math.floor(Math.random() * statuses.length)]
    
    if (randomStatus !== this.pipelineStatusValue) {
      this.pipelineStatusValue = randomStatus
      this.highlightActiveStage(randomStatus)
    }
  }

  highlightActiveStage(status) {
    const stageMap = {
      'extracting': 0,
      'transforming': 1,
      'loading': 2
    }
    
    const nodes = document.querySelectorAll('.etl-node')
    nodes.forEach((node, index) => {
      node.classList.remove('active', 'completed')
      
      if (status in stageMap) {
        if (index === stageMap[status]) {
          node.classList.add('active')
        } else if (index < stageMap[status]) {
          node.classList.add('completed')
        }
      }
    })
  }

  clearAnimationTimers() {
    // Clear any remaining timers
    if (this.animationTimers) {
      this.animationTimers.forEach(timer => clearTimeout(timer))
    }
  }

  // Utility methods
  extractNumericValue(text) {
    return parseInt(text.replace(/[^0-9]/g, '')) || 0
  }

  formatNumber(num) {
    if (num >= 1000000) {
      return (num / 1000000).toFixed(1) + 'M'
    } else if (num >= 1000) {
      return (num / 1000).toFixed(1) + 'K'
    }
    return num.toString()
  }

  formatNumberWithCommas(num) {
    return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',')
  }

  lightenColor(color, percent) {
    const num = parseInt(color.replace('#', ''), 16)
    const amt = Math.round(2.55 * percent)
    const R = (num >> 16) + amt
    const G = (num >> 8 & 0x00FF) + amt
    const B = (num & 0x0000FF) + amt
    return '#' + (0x1000000 + (R < 255 ? R < 1 ? 0 : R : 255) * 0x10000 +
      (G < 255 ? G < 1 ? 0 : G : 255) * 0x100 +
      (B < 255 ? B < 1 ? 0 : B : 255)).toString(16).slice(1)
  }

  refreshCard(event) {
    const card = event.currentTarget.closest('[data-dashboard-animation-target="card"]')
    card.style.transform = "scale(0.95)"
    
    setTimeout(() => {
      card.style.transition = "transform 0.2s ease-out"
      card.style.transform = "scale(1)"
    }, 100)
  }
};
