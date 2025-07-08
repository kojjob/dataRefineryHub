import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "input", "chatContainer"]
  
  open() {
    this.modalTarget.classList.add('active')
    setTimeout(() => this.inputTarget.focus(), 100)
  }
  
  close() {
    this.modalTarget.classList.remove('active')
  }
  
  handleKeypress(event) {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault()
      this.sendMessage()
    }
  }
  
  sendMessage() {
    const message = this.inputTarget.value.trim()
    if (!message) return
    
    // Add user message
    this.addChatMessage(message, 'user')
    this.inputTarget.value = ''
    
    // Simulate AI response (in production, this would call your API)
    setTimeout(() => {
      const response = this.getAIResponse(message)
      this.addChatMessage(response, 'ai')
    }, 1000)
  }
  
  addChatMessage(message, type) {
    const messageDiv = document.createElement('div')
    messageDiv.className = `chat-message ${type}`
    messageDiv.innerHTML = `<p>${message}</p>`
    
    this.chatContainerTarget.appendChild(messageDiv)
    this.chatContainerTarget.scrollTop = this.chatContainerTarget.scrollHeight
  }
  
  getAIResponse(userMessage) {
    const responses = [
      "Based on your current data trends, I recommend focusing on customer retention strategies to improve the 18% churn rate in your enterprise segment.",
      "Your sales forecast shows strong growth potential. Would you like me to create a detailed breakdown by product category?",
      "I've analyzed your marketing spend and identified 3 optimization opportunities that could increase ROI by 25%.",
      "Your data quality score of 96% is excellent. Here are some suggestions to reach 98%+.",
      "I can help you create a custom dashboard for your specific industry. What type of business are you in?",
      "Your pipeline performance shows 85% success rate. Let me show you how to identify bottlenecks in the remaining 15%."
    ]
    
    return responses[Math.floor(Math.random() * responses.length)]
  }
  
  // Close modal when clicking outside
  backdropClick(event) {
    if (event.target === this.modalTarget) {
      this.close()
    }
  }
}