import { Controller } from "@hotwired/stimulus"

// Confetti celebration effect for success actions
export default class extends Controller {
  static values = { 
    trigger: String,
    particleCount: Number,
    spread: Number,
    colors: Array
  }
  
  connect() {
    this.particleCountValue = this.particleCountValue || 100
    this.spreadValue = this.spreadValue || 70
    this.colorsValue = this.colorsValue || ['#ff0000', '#00ff00', '#0000ff', '#ffff00', '#ff00ff', '#00ffff', '#ffa500']
    
    // Auto-trigger on connection if specified
    if (this.triggerValue === 'auto') {
      this.celebrate()
    }
  }
  
  celebrate(event) {
    const rect = this.element.getBoundingClientRect()
    const x = event ? event.clientX : rect.left + rect.width / 2
    const y = event ? event.clientY : rect.top + rect.height / 2
    
    this.createConfetti(x, y)
  }
  
  createConfetti(originX, originY) {
    const container = document.createElement('div')
    container.className = 'confetti-container fixed inset-0 pointer-events-none z-50'
    document.body.appendChild(container)
    
    for (let i = 0; i < this.particleCountValue; i++) {
      this.createParticle(container, originX, originY)
    }
    
    // Remove container after animation
    setTimeout(() => container.remove(), 3000)
  }
  
  createParticle(container, x, y) {
    const particle = document.createElement('div')
    const size = Math.random() * 8 + 4
    const color = this.colorsValue[Math.floor(Math.random() * this.colorsValue.length)]
    
    // Random velocities
    const angle = (Math.random() * Math.PI * 2)
    const velocity = 15 + Math.random() * 15
    const vx = Math.cos(angle) * velocity
    const vy = Math.sin(angle) * velocity - 20 // Negative for upward motion
    
    // Random rotation
    const rotationSpeed = Math.random() * 600 - 300
    
    particle.className = 'confetti-particle absolute'
    particle.style.width = size + 'px'
    particle.style.height = size + 'px'
    particle.style.backgroundColor = color
    particle.style.left = x + 'px'
    particle.style.top = y + 'px'
    particle.style.borderRadius = Math.random() > 0.5 ? '50%' : '0'
    
    container.appendChild(particle)
    
    // Animate particle
    let posX = x
    let posY = y
    let velocityY = vy
    let rotation = 0
    let opacity = 1
    
    const animate = () => {
      posX += vx * 0.02
      velocityY += 0.5 // Gravity
      posY += velocityY * 0.02
      rotation += rotationSpeed * 0.02
      opacity -= 0.01
      
      particle.style.transform = `translate(${posX - x}px, ${posY - y}px) rotate(${rotation}deg)`
      particle.style.opacity = opacity
      
      if (opacity > 0 && posY < window.innerHeight) {
        requestAnimationFrame(animate)
      } else {
        particle.remove()
      }
    }
    
    requestAnimationFrame(animate)
  }
  
  // Method to trigger confetti from other controllers or events
  success() {
    // Trigger from center of viewport
    const x = window.innerWidth / 2
    const y = window.innerHeight / 3
    this.createConfetti(x, y)
  }
};
