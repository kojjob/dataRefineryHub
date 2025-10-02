import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

export default class extends Controller {
  static targets = [
    "toggleButton", 
    "chatWindow", 
    "messagesContainer", 
    "messageInput", 
    "sendButton",
    "voiceButton",
    "voiceIndicator",
    "loadingIndicator",
    "suggestions"
  ]
  
  static values = {
    organizationId: Number,
    userId: Number
  }
  
  connect() {
    this.isOpen = false
    this.isRecording = false
    this.messageHistory = []
    this.setupWebSocket()
    this.setupVoiceRecognition()
    this.loadChatHistory()
  }
  
  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    if (this.recognition) {
      this.recognition.stop()
    }
  }
  
  setupWebSocket() {
    this.subscription = consumer.subscriptions.create(
      {
        channel: "AiChatChannel",
        organization_id: this.organizationIdValue,
        user_id: this.userIdValue
      },
      {
        connected: () => {
          console.log("Connected to AI Chat channel")
        },
        
        disconnected: () => {
          console.log("Disconnected from AI Chat channel")
        },
        
        received: (data) => {
          this.handleWebSocketMessage(data)
        }
      }
    )
  }
  
  setupVoiceRecognition() {
    if (!('webkitSpeechRecognition' in window || 'SpeechRecognition' in window)) {
      console.log("Speech recognition not supported")
      if (this.hasVoiceButtonTarget) {
        this.voiceButtonTarget.style.display = 'none'
      }
      return
    }
    
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition
    this.recognition = new SpeechRecognition()
    this.recognition.continuous = false
    this.recognition.interimResults = true
    this.recognition.lang = 'en-US'
    
    this.recognition.onstart = () => {
      this.isRecording = true
      this.voiceIndicatorTarget.classList.remove('hidden')
    }
    
    this.recognition.onresult = (event) => {
      const transcript = Array.from(event.results)
        .map(result => result[0])
        .map(result => result.transcript)
        .join('')
      
      this.messageInputTarget.value = transcript
    }
    
    this.recognition.onerror = (event) => {
      console.error('Speech recognition error:', event.error)
      this.stopVoiceRecording()
      this.showNotification('Voice recognition error. Please try again.', 'error')
    }
    
    this.recognition.onend = () => {
      this.stopVoiceRecording()
      if (this.messageInputTarget.value.trim()) {
        this.sendMessage()
      }
    }
  }
  
  toggleChat() {
    this.isOpen = !this.isOpen
    
    if (this.isOpen) {
      this.chatWindowTarget.classList.remove('hidden')
      this.toggleButtonTarget.classList.add('hidden')
      this.messageInputTarget.focus()
    } else {
      this.chatWindowTarget.classList.add('hidden')
      this.toggleButtonTarget.classList.remove('hidden')
    }
  }
  
  async sendMessage(event) {
    if (event) event.preventDefault()
    
    const message = this.messageInputTarget.value.trim()
    if (!message) return
    
    // Add user message to chat
    this.addMessage(message, 'user')
    
    // Clear input
    this.messageInputTarget.value = ''
    
    // Show loading
    this.showLoading()
    
    try {
      // Get current context
      const context = this.getCurrentContext()
      
      // Send to backend
      const response = await fetch('/ai/chat', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({
          query: message,
          context: context
        })
      })
      
      const data = await response.json()
      
      if (data.success) {
        this.handleAiResponse(data.response)
      } else {
        this.showError(data.error || 'Failed to process your request')
      }
    } catch (error) {
      console.error('Chat error:', error)
      this.showError('Connection error. Please try again.')
    } finally {
      this.hideLoading()
    }
  }
  
  handleAiResponse(response) {
    // Add AI message
    const messageElement = this.addMessage(response.message, 'ai')
    
    // Add visualizations if any
    if (response.visualizations && response.visualizations.length > 0) {
      this.addVisualizations(messageElement, response.visualizations)
    }
    
    // Add action buttons if any
    if (response.actions && response.actions.length > 0) {
      this.addActionButtons(messageElement, response.actions)
    }
    
    // Store in history
    this.messageHistory.push({
      query: this.lastUserMessage,
      response: response,
      timestamp: new Date()
    })
  }
  
  addMessage(content, sender) {
    const template = sender === 'user' 
      ? document.getElementById('user-message-template')
      : document.getElementById('ai-message-template')
    
    if (!template) {
      console.error(`Template not found for sender: ${sender}`);
      return null;
    }
    
    const messageElement = template.content.cloneNode(true)
    
    // Set content safely
    const contentElement = messageElement.querySelector('.message-content')
    const timeElement = messageElement.querySelector('.message-time')
    
    if (contentElement) {
      contentElement.innerHTML = this.formatMessage(content)
    }
    
    if (timeElement) {
      timeElement.textContent = this.formatTime(new Date())
    }
    
    if (sender === 'user') {
      const initials = this.getUserInitials()
      const initialsElement = messageElement.querySelector('.user-initials')
      if (initialsElement) {
        initialsElement.textContent = initials
      }
      this.lastUserMessage = content
    }
    
    // Append to container
    this.messagesContainerTarget.appendChild(messageElement)
    
    // Scroll to bottom
    this.scrollToBottom()
    
    // Return the message element for adding visualizations/actions
    return this.messagesContainerTarget.lastElementChild
  }
  
  addVisualizations(messageElement, visualizations) {
    const container = messageElement.querySelector('.visualizations-container')
    
    if (!container) {
      console.error('Visualizations container not found')
      return
    }
    
    visualizations.forEach(viz => {
      const vizElement = this.createVisualizationElement(viz)
      if (vizElement) {
        container.appendChild(vizElement)
      }
    })
  }
  
  createVisualizationElement(viz) {
    const div = document.createElement('div')
    div.className = 'mt-2 p-3 bg-df-background rounded-lg'
    
    switch (viz.type) {
      case 'metric':
        div.innerHTML = `
          <div class="text-center">
            <p class="text-xs text-df-text-secondary uppercase">${viz.title}</p>
            <p class="text-2xl font-semibold text-df-text">${this.formatValue(viz.value)}</p>
          </div>
        `
        break
        
      case 'bar_chart':
        div.innerHTML = `
          <p class="text-xs text-df-text-secondary mb-2">${viz.title}</p>
          <div class="space-y-1">
            ${this.createMiniBarChart(viz.data)}
          </div>
        `
        break
        
      case 'line_chart':
        div.innerHTML = `
          <p class="text-xs text-df-text-secondary mb-2">${viz.title}</p>
          <div class="h-20 flex items-end gap-1">
            ${this.createMiniLineChart(viz.data)}
          </div>
        `
        break
        
      default:
        div.innerHTML = `<p class="text-xs">Visualization: ${viz.title}</p>`
    }
    
    return div
  }
  
  createMiniBarChart(data) {
    if (!data || typeof data !== 'object') return ''
    
    const entries = Object.entries(data).slice(0, 5)
    const maxValue = Math.max(...entries.map(([_, v]) => v))
    
    return entries.map(([label, value]) => {
      const percentage = (value / maxValue) * 100
      return `
        <div class="flex items-center gap-2">
          <span class="text-xs text-df-text-secondary w-24 truncate">${label}</span>
          <div class="flex-1 bg-df-secondary rounded-full h-4">
            <div class="bg-df-primary h-4 rounded-full" style="width: ${percentage}%"></div>
          </div>
          <span class="text-xs text-df-text">${this.formatValue(value)}</span>
        </div>
      `
    }).join('')
  }
  
  createMiniLineChart(data) {
    // Simple sparkline representation
    if (!Array.isArray(data)) return ''
    
    const maxValue = Math.max(...data)
    
    return data.map((value, index) => {
      const height = (value / maxValue) * 100
      return `<div class="w-2 bg-df-primary rounded-t" style="height: ${height}%"></div>`
    }).join('')
  }
  
  addActionButtons(messageElement, actions) {
    const container = messageElement.querySelector('.actions-container')
    
    if (!container) {
      console.error('Actions container not found')
      return
    }
    
    actions.forEach(action => {
      const button = this.createActionButton(action)
      if (button) {
        container.appendChild(button)
      }
    })
  }
  
  createActionButton(action) {
    const template = document.getElementById('action-button-template')
    
    if (!template) {
      console.error('Action button template not found')
      return null
    }
    
    const buttonElement = template.content.cloneNode(true)
    const button = buttonElement.querySelector('button')
    
    if (!button) {
      console.error('Button element not found in template')
      return null
    }
    
    const actionText = button.querySelector('.action-text')
    if (actionText) {
      actionText.textContent = action.description
    }
    
    // Add appropriate icon based on action type
    const iconPath = this.getActionIcon(action.type)
    const pathElement = button.querySelector('path')
    if (iconPath && pathElement) {
      pathElement.setAttribute('d', iconPath)
    }
    
    // Add click handler
    button.addEventListener('click', () => this.executeAction(action))
    
    // Add priority styling
    if (action.priority === 'high') {
      button.classList.add('border', 'border-df-primary')
    }
    
    return button
  }
  
  async executeAction(action) {
    if (action.requires_approval) {
      const confirmed = confirm(`Are you sure you want to: ${action.description}?`)
      if (!confirmed) return
    }
    
    try {
      const response = await fetch('/ai/chat/execute_action', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({
          action_id: action.id,
          action_type: action.type,
          parameters: action.parameters
        })
      })
      
      const data = await response.json()
      
      if (data.success) {
        this.showNotification('Action executed successfully', 'success')
        this.addMessage(`✓ ${action.description} has been executed.`, 'ai')
      } else {
        this.showError(data.error || 'Failed to execute action')
      }
    } catch (error) {
      console.error('Action execution error:', error)
      this.showError('Failed to execute action')
    }
  }
  
  sendSuggestion(event) {
    const suggestion = event.currentTarget.dataset.suggestion
    this.messageInputTarget.value = suggestion
    this.sendMessage()
  }
  
  quickAction(event) {
    const actionType = event.currentTarget.dataset.actionType
    
    const quickQueries = {
      revenue: "What's my revenue this month compared to last month?",
      customers: "Show me customer metrics and churn risk",
      forecast: "Forecast my revenue for the next quarter",
      alerts: "What anomalies or issues need my attention?"
    }
    
    this.messageInputTarget.value = quickQueries[actionType]
    this.sendMessage()
  }
  
  toggleVoice() {
    if (this.isRecording) {
      this.stopVoiceRecording()
    } else {
      this.startVoiceRecording()
    }
  }
  
  startVoiceRecording() {
    if (!this.recognition) {
      this.showNotification('Voice input not supported in your browser', 'error')
      return
    }
    
    try {
      this.recognition.start()
    } catch (error) {
      console.error('Failed to start voice recording:', error)
      this.showNotification('Failed to start voice recording', 'error')
    }
  }
  
  stopVoiceRecording() {
    if (this.recognition && this.isRecording) {
      this.recognition.stop()
    }
    
    this.isRecording = false
    this.voiceIndicatorTarget.classList.add('hidden')
  }
  
  async handleInput() {
    const query = this.messageInputTarget.value
    
    if (query.length < 3) {
      this.hideSuggestions()
      return
    }
    
    // Debounce
    clearTimeout(this.suggestionTimeout)
    this.suggestionTimeout = setTimeout(() => {
      this.fetchSuggestions(query)
    }, 300)
  }
  
  async fetchSuggestions(query) {
    try {
      const response = await fetch(`/ai/chat/suggestions?query=${encodeURIComponent(query)}`)
      const data = await response.json()
      
      if (data.success && data.suggestions.length > 0) {
        this.showSuggestions(data.suggestions)
      } else {
        this.hideSuggestions()
      }
    } catch (error) {
      console.error('Failed to fetch suggestions:', error)
    }
  }
  
  showSuggestions(suggestions) {
    this.suggestionsTarget.innerHTML = suggestions.map(suggestion => `
      <button class="w-full text-left px-3 py-2 hover:bg-df-secondary transition-colors text-sm"
              data-action="click->ai-chat#selectSuggestion"
              data-suggestion="${suggestion}">
        ${suggestion}
      </button>
    `).join('')
    
    this.suggestionsTarget.classList.remove('hidden')
  }
  
  hideSuggestions() {
    this.suggestionsTarget.classList.add('hidden')
  }
  
  selectSuggestion(event) {
    this.messageInputTarget.value = event.currentTarget.dataset.suggestion
    this.hideSuggestions()
    this.sendMessage()
  }
  
  async loadChatHistory() {
    try {
      const response = await fetch('/ai/chat/history', {
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || ''
        }
      })
      
      if (!response.ok) {
        console.error('Failed to load chat history:', response.status)
        return
      }
      
      const data = await response.json()
      
      if (data.success && data.queries && data.queries.length > 0) {
        // Show last few messages
        data.queries.slice(-3).forEach(query => {
          // Ensure we have valid query and response data
          if (query.query) {
            this.addMessage(query.query, 'user')
          }
          if (query.response) {
            // Handle response which might be a string or object
            const responseMessage = typeof query.response === 'string' 
              ? query.response 
              : query.response.message || JSON.stringify(query.response)
            this.addMessage(responseMessage, 'ai')
          }
        })
      }
    } catch (error) {
      console.error('Failed to load chat history:', error)
    }
  }
  
  getCurrentContext() {
    return {
      current_page: window.location.pathname,
      dashboard_metrics: this.extractDashboardMetrics(),
      active_filters: this.extractActiveFilters(),
      timestamp: new Date().toISOString()
    }
  }
  
  extractDashboardMetrics() {
    // Extract visible metrics from the page
    const metrics = {}
    
    document.querySelectorAll('[data-metric]').forEach(element => {
      const metricName = element.dataset.metric
      const metricValue = element.dataset.value || element.textContent
      metrics[metricName] = metricValue
    })
    
    return metrics
  }
  
  extractActiveFilters() {
    // Extract active filters from the page
    const filters = {}
    
    document.querySelectorAll('[data-filter]').forEach(element => {
      const filterName = element.dataset.filter
      const filterValue = element.value || element.dataset.value
      if (filterValue) {
        filters[filterName] = filterValue
      }
    })
    
    return filters
  }
  
  handleWebSocketMessage(data) {
    switch (data.type) {
      case 'chat_response':
        this.handleAiResponse(data.response)
        break
        
      case 'action_update':
        this.handleActionUpdate(data)
        break
        
      case 'insight_generated':
        this.handleNewInsight(data)
        break
    }
  }
  
  handleActionUpdate(data) {
    this.addMessage(`Update: ${data.message}`, 'ai')
  }
  
  handleNewInsight(data) {
    this.showNotification(`New insight: ${data.insight.title}`, 'info')
  }
  
  showLoading() {
    this.loadingIndicatorTarget.classList.remove('hidden')
    this.sendButtonTarget.disabled = true
  }
  
  hideLoading() {
    this.loadingIndicatorTarget.classList.add('hidden')
    this.sendButtonTarget.disabled = false
  }
  
  showError(message) {
    this.addMessage(`❌ ${message}`, 'ai')
  }
  
  showNotification(message, type = 'info') {
    // This would integrate with your flash message system
    console.log(`${type}: ${message}`)
  }
  
  scrollToBottom() {
    this.messagesContainerTarget.scrollTop = this.messagesContainerTarget.scrollHeight
  }
  
  formatMessage(content) {
    // Convert markdown-style formatting
    return content
      .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
      .replace(/\*(.*?)\*/g, '<em>$1</em>')
      .replace(/\n/g, '<br>')
  }
  
  formatTime(date) {
    return date.toLocaleTimeString('en-US', { 
      hour: 'numeric', 
      minute: '2-digit' 
    })
  }
  
  formatValue(value) {
    if (typeof value === 'number') {
      if (value >= 1000000) {
        return `$${(value / 1000000).toFixed(1)}M`
      } else if (value >= 1000) {
        return `$${(value / 1000).toFixed(1)}K`
      } else {
        return `$${value.toFixed(0)}`
      }
    }
    return value
  }
  
  getUserInitials() {
    // This would get from user data
    return 'ME'
  }
  
  getActionIcon(actionType) {
    const icons = {
      send_email: 'M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z',
      generate_report: 'M9 17v-2m3 2v-4m3 4v-6m2 10H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z',
      create_campaign: 'M11 5.882V19.24a1.76 1.76 0 01-3.417.592l-2.147-6.15M18 13a3 3 0 100-6M5.436 13.683A4.001 4.001 0 017 6h1.832c4.1 0 7.625-1.234 9.168-3v14c-1.543-1.766-5.067-3-9.168-3H7a3.988 3.988 0 01-1.564-.317z',
      adjust_pricing: 'M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z'
    }
    
    return icons[actionType] || icons.generate_report
  }
};
