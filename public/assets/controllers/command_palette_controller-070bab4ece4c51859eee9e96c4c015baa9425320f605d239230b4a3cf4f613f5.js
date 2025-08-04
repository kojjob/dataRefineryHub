import { Controller } from "@hotwired/stimulus"

// Command palette for quick navigation (CMD+K)
export default class extends Controller {
  static targets = ["modal", "input", "results", "backdrop"]
  
  connect() {
    this.selectedIndex = 0
    this.commands = this.loadCommands()
    this.filteredCommands = [...this.commands]
    
    // Register global keyboard shortcut
    this.keydownHandler = (e) => {
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault()
        this.toggle()
      }
    }
    document.addEventListener('keydown', this.keydownHandler)
  }
  
  disconnect() {
    document.removeEventListener('keydown', this.keydownHandler)
  }
  
  loadCommands() {
    return [
      { name: 'Dashboard', path: '/dashboard', icon: '📊', keywords: ['home', 'overview'] },
      { name: 'Data Sources', path: '/data_sources', icon: '🗄️', keywords: ['connections', 'integrations'] },
      { name: 'Analytics', path: '/analytics', icon: '📈', keywords: ['reports', 'insights'] },
      { name: 'Pipeline Dashboard', path: '/pipeline_dashboard', icon: '🔄', keywords: ['etl', 'workflows'] },
      { name: 'Manual Tasks', path: '/manual_tasks', icon: '✋', keywords: ['queue', 'pending'] },
      { name: 'AI Queries', path: '/ai/queries', icon: '🤖', keywords: ['artificial intelligence', 'nlp'] },
      { name: 'BI Agent', path: '/ai/bi_agent/dashboard', icon: '🧠', keywords: ['business intelligence'] },
      { name: 'Real-time Analytics', path: '/ai/real_time_analytics/dashboard', icon: '⚡', keywords: ['live', 'streaming'] },
      { name: 'Data Quality', path: '/data_sources/quality', icon: '✅', keywords: ['validation', 'integrity'] },
      { name: 'New Data Source', path: '/data_sources/new', icon: '➕', keywords: ['add', 'connect'] },
      { name: 'Settings', path: '/settings', icon: '⚙️', keywords: ['preferences', 'configuration'] },
      { name: 'Toggle Dark Mode', action: 'toggleDarkMode', icon: '🌙', keywords: ['theme', 'appearance'] },
      { name: 'Keyboard Shortcuts', action: 'showShortcuts', icon: '⌨️', keywords: ['help', 'hotkeys'] },
      { name: 'Sign Out', path: '/users/sign_out', method: 'delete', icon: '🚪', keywords: ['logout', 'exit'] },
    ]
  }
  
  toggle() {
    if (this.modalTarget.classList.contains('hidden')) {
      this.open()
    } else {
      this.close()
    }
  }
  
  open() {
    this.modalTarget.classList.remove('hidden')
    this.modalTarget.classList.add('flex')
    this.inputTarget.value = ''
    this.filteredCommands = [...this.commands]
    this.selectedIndex = 0
    this.renderResults()
    this.inputTarget.focus()
    
    // Add animation classes
    requestAnimationFrame(() => {
      this.modalTarget.classList.add('command-palette-open')
    })
  }
  
  close() {
    this.modalTarget.classList.remove('command-palette-open')
    
    setTimeout(() => {
      this.modalTarget.classList.add('hidden')
      this.modalTarget.classList.remove('flex')
    }, 200)
  }
  
  filter(event) {
    const query = event.target.value.toLowerCase()
    this.filteredCommands = this.commands.filter(cmd => {
      const inName = cmd.name.toLowerCase().includes(query)
      const inKeywords = cmd.keywords?.some(k => k.includes(query)) || false
      return inName || inKeywords
    })
    this.selectedIndex = 0
    this.renderResults()
  }
  
  navigate(event) {
    switch(event.key) {
      case 'ArrowDown':
        event.preventDefault()
        this.selectedIndex = Math.min(this.selectedIndex + 1, this.filteredCommands.length - 1)
        this.renderResults()
        break
      case 'ArrowUp':
        event.preventDefault()
        this.selectedIndex = Math.max(this.selectedIndex - 1, 0)
        this.renderResults()
        break
      case 'Enter':
        event.preventDefault()
        if (this.filteredCommands[this.selectedIndex]) {
          this.executeCommand(this.filteredCommands[this.selectedIndex])
        }
        break
      case 'Escape':
        this.close()
        break
    }
  }
  
  renderResults() {
    if (this.filteredCommands.length === 0) {
      this.resultsTarget.innerHTML = `
        <div class="p-8 text-center text-gray-500">
          <p class="text-lg font-medium">No results found</p>
          <p class="text-sm mt-2">Try a different search term</p>
        </div>
      `
      return
    }
    
    this.resultsTarget.innerHTML = this.filteredCommands.map((cmd, index) => `
      <div class="command-result ${index === this.selectedIndex ? 'selected' : ''}" 
           data-action="click->command-palette#selectCommand"
           data-command-palette-index-param="${index}">
        <span class="command-icon">${cmd.icon}</span>
        <span class="command-name">${cmd.name}</span>
        ${cmd.keywords ? `<span class="command-keywords">${cmd.keywords.join(', ')}</span>` : ''}
      </div>
    `).join('')
  }
  
  selectCommand(event) {
    const index = parseInt(event.params.index)
    this.executeCommand(this.filteredCommands[index])
  }
  
  executeCommand(command) {
    if (command.action) {
      // Execute action methods
      switch(command.action) {
        case 'toggleDarkMode':
          this.toggleDarkMode()
          break
        case 'showShortcuts':
          this.showShortcuts()
          break
      }
    } else if (command.path) {
      // Navigate to path
      if (command.method === 'delete') {
        // Handle logout
        const form = document.createElement('form')
        form.method = 'POST'
        form.action = command.path
        form.innerHTML = `
          <input type="hidden" name="_method" value="delete">
          <input type="hidden" name="authenticity_token" value="${this.getCSRFToken()}">
        `
        document.body.appendChild(form)
        form.submit()
      } else {
        Turbo.visit(command.path)
      }
    }
    this.close()
  }
  
  toggleDarkMode() {
    document.documentElement.classList.toggle('dark')
    localStorage.setItem('darkMode', document.documentElement.classList.contains('dark'))
  }
  
  showShortcuts() {
    // You could open a modal here instead
    alert(`Keyboard Shortcuts:
    
⌘K / Ctrl+K: Open command palette
↑↓: Navigate results
Enter: Select command
Escape: Close palette
/: Focus search (on pages with search)`)
  }
  
  getCSRFToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
  
  backdropClick() {
    this.close()
  }
};
