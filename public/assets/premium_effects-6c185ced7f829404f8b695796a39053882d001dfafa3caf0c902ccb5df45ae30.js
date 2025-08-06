// Premium Effects and Interactions for Data Refinery Platform

// Magnetic Button Effect
class MagneticButton {
  constructor(element) {
    this.element = element;
    this.boundingRect = this.element.getBoundingClientRect();
    this.magnetStrength = 0.25;
    
    this.init();
  }
  
  init() {
    this.element.addEventListener('mousemove', this.onMouseMove.bind(this));
    this.element.addEventListener('mouseleave', this.onMouseLeave.bind(this));
    window.addEventListener('resize', () => {
      this.boundingRect = this.element.getBoundingClientRect();
    });
  }
  
  onMouseMove(e) {
    const x = e.clientX - this.boundingRect.left - this.boundingRect.width / 2;
    const y = e.clientY - this.boundingRect.top - this.boundingRect.height / 2;
    
    const translateX = x * this.magnetStrength;
    const translateY = y * this.magnetStrength;
    
    this.element.style.transform = `translate(${translateX}px, ${translateY}px)`;
  }
  
  onMouseLeave() {
    this.element.style.transform = 'translate(0, 0)';
  }
}

// Ripple Effect
class RippleEffect {
  constructor(element) {
    this.element = element;
    this.init();
  }
  
  init() {
    this.element.style.position = 'relative';
    this.element.style.overflow = 'hidden';
    this.element.addEventListener('click', this.createRipple.bind(this));
  }
  
  createRipple(e) {
    const ripple = document.createElement('span');
    const rect = this.element.getBoundingClientRect();
    const size = Math.max(rect.width, rect.height);
    const x = e.clientX - rect.left - size / 2;
    const y = e.clientY - rect.top - size / 2;
    
    ripple.style.width = ripple.style.height = size + 'px';
    ripple.style.left = x + 'px';
    ripple.style.top = y + 'px';
    ripple.classList.add('ripple-effect');
    
    this.element.appendChild(ripple);
    
    setTimeout(() => ripple.remove(), 600);
  }
}

// Skeleton Loader
class SkeletonLoader {
  static create(type = 'text', customClass = '') {
    const skeleton = document.createElement('div');
    skeleton.className = `skeleton-loader skeleton-${type} ${customClass}`;
    return skeleton;
  }
  
  static replace(element, content) {
    element.style.opacity = '0';
    setTimeout(() => {
      element.innerHTML = content;
      element.style.opacity = '1';
    }, 300);
  }
}

// Confetti Celebration
class Confetti {
  constructor() {
    this.colors = ['#ff0000', '#00ff00', '#0000ff', '#ffff00', '#ff00ff', '#00ffff'];
    this.particleCount = 100;
  }
  
  celebrate(x = window.innerWidth / 2, y = window.innerHeight / 2) {
    const container = document.createElement('div');
    container.className = 'confetti-container';
    document.body.appendChild(container);
    
    for (let i = 0; i < this.particleCount; i++) {
      this.createParticle(container, x, y);
    }
    
    setTimeout(() => container.remove(), 3000);
  }
  
  createParticle(container, x, y) {
    const particle = document.createElement('div');
    particle.className = 'confetti-particle';
    particle.style.backgroundColor = this.colors[Math.floor(Math.random() * this.colors.length)];
    particle.style.left = x + 'px';
    particle.style.top = y + 'px';
    
    const angle = Math.random() * Math.PI * 2;
    const velocity = 5 + Math.random() * 10;
    const vx = Math.cos(angle) * velocity;
    const vy = Math.sin(angle) * velocity - 10;
    
    particle.style.setProperty('--vx', vx);
    particle.style.setProperty('--vy', vy);
    
    container.appendChild(particle);
  }
}

// Command Palette
class CommandPalette {
  constructor() {
    this.isOpen = false;
    this.commands = [];
    this.filteredCommands = [];
    this.selectedIndex = 0;
    
    this.init();
  }
  
  init() {
    this.createPalette();
    this.registerShortcuts();
    this.loadCommands();
  }
  
  createPalette() {
    const palette = document.createElement('div');
    palette.className = 'command-palette hidden';
    palette.innerHTML = `
      <div class="command-palette-backdrop"></div>
      <div class="command-palette-modal">
        <div class="command-palette-header">
          <input type="text" class="command-palette-input" placeholder="Type a command or search..." />
        </div>
        <div class="command-palette-results"></div>
      </div>
    `;
    
    document.body.appendChild(palette);
    
    this.palette = palette;
    this.input = palette.querySelector('.command-palette-input');
    this.results = palette.querySelector('.command-palette-results');
    this.backdrop = palette.querySelector('.command-palette-backdrop');
    
    this.input.addEventListener('input', this.handleInput.bind(this));
    this.input.addEventListener('keydown', this.handleKeydown.bind(this));
    this.backdrop.addEventListener('click', this.close.bind(this));
  }
  
  registerShortcuts() {
    document.addEventListener('keydown', (e) => {
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault();
        this.toggle();
      }
    });
  }
  
  loadCommands() {
    // Default commands - can be extended
    this.commands = [
      { name: 'Dashboard', action: () => window.location.href = '/dashboard', icon: '📊' },
      { name: 'Data Sources', action: () => window.location.href = '/data_sources', icon: '🗄️' },
      { name: 'Analytics', action: () => window.location.href = '/analytics', icon: '📈' },
      { name: 'Pipelines', action: () => window.location.href = '/pipelines', icon: '🔄' },
      { name: 'AI Queries', action: () => window.location.href = '/ai/queries', icon: '🤖' },
      { name: 'Settings', action: () => window.location.href = '/settings', icon: '⚙️' },
      { name: 'Toggle Dark Mode', action: () => this.toggleDarkMode(), icon: '🌙' },
      { name: 'Keyboard Shortcuts', action: () => this.showShortcuts(), icon: '⌨️' },
    ];
    
    this.filteredCommands = [...this.commands];
  }
  
  handleInput(e) {
    const query = e.target.value.toLowerCase();
    this.filteredCommands = this.commands.filter(cmd => 
      cmd.name.toLowerCase().includes(query)
    );
    this.selectedIndex = 0;
    this.renderResults();
  }
  
  handleKeydown(e) {
    switch(e.key) {
      case 'ArrowDown':
        e.preventDefault();
        this.selectedIndex = Math.min(this.selectedIndex + 1, this.filteredCommands.length - 1);
        this.renderResults();
        break;
      case 'ArrowUp':
        e.preventDefault();
        this.selectedIndex = Math.max(this.selectedIndex - 1, 0);
        this.renderResults();
        break;
      case 'Enter':
        e.preventDefault();
        if (this.filteredCommands[this.selectedIndex]) {
          this.executeCommand(this.filteredCommands[this.selectedIndex]);
        }
        break;
      case 'Escape':
        this.close();
        break;
    }
  }
  
  renderResults() {
    this.results.innerHTML = this.filteredCommands.map((cmd, index) => `
      <div class="command-palette-item ${index === this.selectedIndex ? 'selected' : ''}" data-index="${index}">
        <span class="command-palette-icon">${cmd.icon}</span>
        <span class="command-palette-name">${cmd.name}</span>
      </div>
    `).join('');
    
    // Add click handlers
    this.results.querySelectorAll('.command-palette-item').forEach(item => {
      item.addEventListener('click', () => {
        const index = parseInt(item.dataset.index);
        this.executeCommand(this.filteredCommands[index]);
      });
    });
  }
  
  executeCommand(command) {
    command.action();
    this.close();
  }
  
  toggle() {
    this.isOpen ? this.close() : this.open();
  }
  
  open() {
    this.isOpen = true;
    this.palette.classList.remove('hidden');
    this.input.value = '';
    this.filteredCommands = [...this.commands];
    this.selectedIndex = 0;
    this.renderResults();
    this.input.focus();
  }
  
  close() {
    this.isOpen = false;
    this.palette.classList.add('hidden');
  }
  
  toggleDarkMode() {
    document.documentElement.classList.toggle('dark');
    localStorage.setItem('darkMode', document.documentElement.classList.contains('dark'));
  }
  
  showShortcuts() {
    alert('Keyboard Shortcuts:\n\nCMD+K: Open command palette\nESC: Close dialogs\n/: Focus search');
  }
}

// Page Transitions
class PageTransitions {
  constructor() {
    this.init();
  }
  
  init() {
    document.addEventListener('turbo:before-visit', this.beforeVisit.bind(this));
    document.addEventListener('turbo:load', this.afterLoad.bind(this));
  }
  
  beforeVisit() {
    document.body.classList.add('page-transition-out');
  }
  
  afterLoad() {
    document.body.classList.remove('page-transition-out');
    document.body.classList.add('page-transition-in');
    
    setTimeout(() => {
      document.body.classList.remove('page-transition-in');
    }, 500);
  }
}

// Initialize Premium Effects
document.addEventListener('turbo:load', () => {
  // Initialize magnetic buttons
  document.querySelectorAll('.magnetic-button, .group[class*="hover:-translate-y"]').forEach(button => {
    new MagneticButton(button);
  });
  
  // Initialize ripple effects
  document.querySelectorAll('button, .btn, a[class*="inline-flex"]').forEach(element => {
    new RippleEffect(element);
  });
  
  // Initialize command palette (singleton)
  if (!window.commandPalette) {
    window.commandPalette = new CommandPalette();
  }
  
  // Initialize page transitions (singleton)
  if (!window.pageTransitions) {
    window.pageTransitions = new PageTransitions();
  }
  
  // Initialize confetti (singleton)
  if (!window.confetti) {
    window.confetti = new Confetti();
  }
});

// Export for use in other files
export { MagneticButton, RippleEffect, SkeletonLoader, Confetti, CommandPalette, PageTransitions };
