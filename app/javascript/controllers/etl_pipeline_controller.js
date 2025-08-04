import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["node", "status"]
  
  connect() {
    this.animateNodes()
  }
  
  animateNodes() {
    // Add staggered animation to nodes
    this.nodeTargets.forEach((node, index) => {
      setTimeout(() => {
        node.style.opacity = '0'
        node.style.transform = 'translateY(20px)'
        
        setTimeout(() => {
          node.style.transition = 'all 0.5s cubic-bezier(0.16, 1, 0.3, 1)'
          node.style.opacity = '1'
          node.style.transform = 'translateY(0)'
        }, 50)
      }, index * 200)
    })
  }
  
  selectNode(event) {
    const node = event.currentTarget
    
    // Remove previous selections
    this.nodeTargets.forEach(n => n.classList.remove('selected'))
    
    // Add selection to clicked node
    node.classList.add('selected')
    
    // Show configuration panel (in production, this would open a modal or side panel)
    this.showNodeConfig(node)
  }
  
  showNodeConfig(node) {
    const nodeType = node.dataset.nodeType
    console.log(`Configure ${nodeType} node`)
    // In production, this would open a configuration panel
  }
  
  togglePipeline(event) {
    const button = event.currentTarget
    const pipelineId = button.dataset.pipelineId
    const statusElement = button.querySelector('.pipeline-status')
    const isRunning = statusElement.classList.contains('running')
    
    if (isRunning) {
      statusElement.classList.remove('running')
      statusElement.classList.add('paused')
      statusElement.querySelector('span:last-child').textContent = 'Paused'
    } else {
      statusElement.classList.remove('paused')
      statusElement.classList.add('running')
      statusElement.querySelector('span:last-child').textContent = 'Running'
    }
    
    // In production, this would make an API call to toggle the pipeline
    console.log(`Toggle pipeline ${pipelineId}`)
  }
}