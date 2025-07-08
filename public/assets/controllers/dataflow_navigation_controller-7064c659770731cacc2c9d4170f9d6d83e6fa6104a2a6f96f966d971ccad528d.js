import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "pageTitle", "pageSubtitle", "content"]
  
  connect() {
    this.currentSection = 'dashboard'
    this.titles = {
      dashboard: { title: 'Executive Dashboard', subtitle: 'Real-time insights and AI-powered analytics for your business' },
      predictive: { title: 'Predictive Analytics', subtitle: 'Advanced forecasting and trend analysis powered by machine learning' },
      builder: { title: 'Analytics Builder', subtitle: 'Drag and drop to create custom dashboards without coding' },
      etl: { title: 'ETL Pipeline Builder', subtitle: 'Visual workflow designer with 200+ data connectors' },
      templates: { title: 'Industry Templates', subtitle: 'Pre-built analytics templates for your industry' },
      marketplace: { title: 'Integration Marketplace', subtitle: 'Connect with 200+ business tools and data sources' },
      collaboration: { title: 'Team Collaboration', subtitle: 'Work together on analytics projects with real-time collaboration' },
      mobile: { title: 'Mobile Dashboard', subtitle: 'Touch-optimized mobile experience for on-the-go analytics' },
      partner: { title: 'Partner Portal', subtitle: 'Complete branding customization for resellers and partners' },
      costs: { title: 'Cost Optimization', subtitle: 'Monitor and optimize your data platform spending' },
      security: { title: 'Security & Compliance', subtitle: 'GDPR compliance tools and security monitoring' }
    }
  }
  
  toggleSidebar() {
    this.sidebarTarget.classList.toggle('open')
  }
  
  switchSection(event) {
    const section = event.currentTarget.dataset.section
    if (!section || section === this.currentSection) return
    
    // Update navigation active state
    const navItems = this.element.querySelectorAll('.nav-item')
    navItems.forEach(item => item.classList.remove('active'))
    event.currentTarget.classList.add('active')
    
    // Update page title
    const titleInfo = this.titles[section]
    if (titleInfo) {
      this.pageTitleTarget.textContent = titleInfo.title
      this.pageSubtitleTarget.textContent = titleInfo.subtitle
    }
    
    // Update content visibility
    const sections = this.contentTarget.querySelectorAll('.content-section')
    sections.forEach(s => s.classList.remove('active'))
    
    const targetSection = this.contentTarget.querySelector(`#${section}`)
    if (targetSection) {
      targetSection.classList.add('active')
    }
    
    this.currentSection = section
    
    // Close sidebar on mobile after navigation
    if (window.innerWidth <= 768) {
      this.sidebarTarget.classList.remove('open')
    }
    
    // Dispatch custom event for other controllers to listen to
    this.dispatch('sectionChanged', { detail: { section } })
  }
  
  handleResize() {
    if (window.innerWidth > 768) {
      this.sidebarTarget.classList.remove('open')
    }
  }
};
