// DataFlow Pro - Analytics Platform JavaScript

// Application State
let currentSection = 'dashboard';
let isDarkMode = false;
let charts = {};

// Sample Data (from provided JSON)
const platformData = {
    metrics: {
        connectedSources: 247,
        activePipelines: 18,
        recordsProcessed: "3.2M",
        dataQualityScore: 96,
        monthlyActiveUsers: 1847,
        costSavings: "£127K"
    },
    chartData: {
        revenueGrowth: {
            labels: ["Jan", "Feb", "Mar", "Apr", "May", "Jun"],
            current: [125000, 138000, 142000, 155000, 168000, 175000],
            predicted: [180000, 195000, 208000, 225000, 240000, 255000]
        },
        customerAcquisition: {
            labels: ["Week 1", "Week 2", "Week 3", "Week 4"],
            data: [245, 287, 312, 298]
        },
        pipelinePerformance: {
            successful: 85,
            failed: 12,
            pending: 23
        }
    }
};

// Initialize Application
document.addEventListener('DOMContentLoaded', function() {
    initializeNavigation();
    initializeThemeToggle();
    initializeCharts();
    initializeAIAssistant();
    initializeDragAndDrop();
    initializeInteractiveElements();
    initializeMobileNavigation();
    
    // Add theme transition class for smooth transitions
    document.body.classList.add('theme-transition');
});

// Navigation System
function initializeNavigation() {
    const navItems = document.querySelectorAll('.nav-item');
    const contentSections = document.querySelectorAll('.content-section');
    
    navItems.forEach(item => {
        item.addEventListener('click', function() {
            const targetSection = this.dataset.section;
            switchSection(targetSection);
        });
    });
    
    function switchSection(sectionId) {
        // Update navigation
        navItems.forEach(nav => nav.classList.remove('active'));
        document.querySelector(`[data-section="${sectionId}"]`).classList.add('active');
        
        // Update content
        contentSections.forEach(section => section.classList.remove('active'));
        document.getElementById(sectionId).classList.add('active');
        
        // Update page title
        updatePageTitle(sectionId);
        
        // Initialize section-specific functionality
        initializeSectionSpecific(sectionId);
        
        currentSection = sectionId;
    }
    
    function updatePageTitle(sectionId) {
        const titles = {
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
        };
        
        const pageTitle = document.getElementById('pageTitle');
        const pageSubtitle = document.getElementById('pageSubtitle');
        
        if (titles[sectionId]) {
            pageTitle.textContent = titles[sectionId].title;
            pageSubtitle.textContent = titles[sectionId].subtitle;
        }
    }
}

// Theme Toggle
function initializeThemeToggle() {
    const themeToggle = document.getElementById('themeToggle');
    
    // Check for saved theme preference
    const savedTheme = localStorage.getItem('theme');
    if (savedTheme) {
        document.documentElement.setAttribute('data-color-scheme', savedTheme);
        isDarkMode = savedTheme === 'dark';
        updateThemeToggle();
    }
    
    themeToggle.addEventListener('click', function() {
        isDarkMode = !isDarkMode;
        const newTheme = isDarkMode ? 'dark' : 'light';
        document.documentElement.setAttribute('data-color-scheme', newTheme);
        localStorage.setItem('theme', newTheme);
        updateThemeToggle();
        
        // Update charts with new theme
        updateChartsTheme();
    });
    
    function updateThemeToggle() {
        const themeToggle = document.getElementById('themeToggle');
        themeToggle.textContent = isDarkMode ? '☀️' : '🌙';
    }
}

// Chart Initialization
function initializeCharts() {
    initializeRevenueChart();
    initializeCustomerChart();
    initializeMobileChart();
}

function initializeRevenueChart() {
    const ctx = document.getElementById('revenueChart');
    if (!ctx) return;
    
    const colors = ['#1FB8CD', '#FFC185', '#B4413C', '#ECEBD5', '#5D878F'];
    
    charts.revenueChart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: platformData.chartData.revenueGrowth.labels,
            datasets: [
                {
                    label: 'Current Revenue',
                    data: platformData.chartData.revenueGrowth.current,
                    borderColor: colors[0],
                    backgroundColor: colors[0] + '20',
                    borderWidth: 3,
                    tension: 0.4,
                    fill: true
                },
                {
                    label: 'Predicted Revenue',
                    data: platformData.chartData.revenueGrowth.predicted,
                    borderColor: colors[1],
                    backgroundColor: colors[1] + '20',
                    borderWidth: 3,
                    borderDash: [5, 5],
                    tension: 0.4,
                    fill: false
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    display: true,
                    position: 'top'
                },
                tooltip: {
                    mode: 'index',
                    intersect: false,
                    callbacks: {
                        label: function(context) {
                            return context.dataset.label + ': £' + context.parsed.y.toLocaleString();
                        }
                    }
                }
            },
            scales: {
                y: {
                    beginAtZero: true,
                    ticks: {
                        callback: function(value) {
                            return '£' + (value / 1000) + 'K';
                        }
                    }
                }
            },
            interaction: {
                mode: 'nearest',
                axis: 'x',
                intersect: false
            }
        }
    });
}

function initializeCustomerChart() {
    const ctx = document.getElementById('customerChart');
    if (!ctx) return;
    
    const colors = ['#1FB8CD', '#FFC185', '#B4413C', '#ECEBD5'];
    
    charts.customerChart = new Chart(ctx, {
        type: 'bar',
        data: {
            labels: platformData.chartData.customerAcquisition.labels,
            datasets: [{
                label: 'New Customers',
                data: platformData.chartData.customerAcquisition.data,
                backgroundColor: colors,
                borderColor: colors.map(color => color + 'CC'),
                borderWidth: 2,
                borderRadius: 8
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    display: false
                },
                tooltip: {
                    callbacks: {
                        label: function(context) {
                            return 'New Customers: ' + context.parsed.y;
                        }
                    }
                }
            },
            scales: {
                y: {
                    beginAtZero: true,
                    ticks: {
                        stepSize: 50
                    }
                }
            }
        }
    });
}

function initializeMobileChart() {
    const ctx = document.getElementById('mobileChart');
    if (!ctx) return;
    
    const colors = ['#1FB8CD', '#FFC185', '#B4413C'];
    
    charts.mobileChart = new Chart(ctx, {
        type: 'doughnut',
        data: {
            labels: ['Successful', 'Failed', 'Pending'],
            datasets: [{
                data: [
                    platformData.chartData.pipelinePerformance.successful,
                    platformData.chartData.pipelinePerformance.failed,
                    platformData.chartData.pipelinePerformance.pending
                ],
                backgroundColor: colors,
                borderWidth: 0
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    position: 'bottom',
                    labels: {
                        padding: 20,
                        font: {
                            size: 10
                        }
                    }
                }
            },
            cutout: '60%'
        }
    });
}

function updateChartsTheme() {
    // Update chart colors based on theme
    Object.values(charts).forEach(chart => {
        if (chart && chart.update) {
            chart.update();
        }
    });
}

// AI Assistant Modal
function initializeAIAssistant() {
    const aiAssistantBtn = document.getElementById('aiAssistant');
    const aiModal = document.getElementById('aiModal');
    const modalClose = document.querySelector('.modal-close');
    const chatInput = document.getElementById('chatInput');
    const sendChatBtn = document.getElementById('sendChat');
    const chatContainer = document.querySelector('.chat-container');
    
    aiAssistantBtn.addEventListener('click', function() {
        aiModal.classList.add('show');
    });
    
    modalClose.addEventListener('click', function() {
        aiModal.classList.remove('show');
    });
    
    aiModal.addEventListener('click', function(e) {
        if (e.target === aiModal) {
            aiModal.classList.remove('show');
        }
    });
    
    sendChatBtn.addEventListener('click', sendMessage);
    chatInput.addEventListener('keypress', function(e) {
        if (e.key === 'Enter') {
            sendMessage();
        }
    });
    
    function sendMessage() {
        const message = chatInput.value.trim();
        if (!message) return;
        
        // Add user message
        addChatMessage(message, 'user');
        chatInput.value = '';
        
        // Simulate AI response
        setTimeout(() => {
            const aiResponse = getAIResponse(message);
            addChatMessage(aiResponse, 'ai');
        }, 1000);
    }
    
    function addChatMessage(message, type) {
        const messageDiv = document.createElement('div');
        messageDiv.className = `chat-message ${type}`;
        messageDiv.innerHTML = `<p>${message}</p>`;
        chatContainer.appendChild(messageDiv);
        chatContainer.scrollTop = chatContainer.scrollHeight;
    }
    
    function getAIResponse(userMessage) {
        const responses = [
            "Based on your current data trends, I recommend focusing on customer retention strategies to improve the 18% churn rate in your enterprise segment.",
            "Your sales forecast shows strong growth potential. Would you like me to create a detailed breakdown by product category?",
            "I've analyzed your marketing spend and identified 3 optimization opportunities that could increase ROI by 25%.",
            "Your data quality score of 96% is excellent. Here are some suggestions to reach 98%+.",
            "I can help you create a custom dashboard for your specific industry. What type of business are you in?",
            "Your pipeline performance shows 85% success rate. Let me show you how to identify bottlenecks in the remaining 15%."
        ];
        
        return responses[Math.floor(Math.random() * responses.length)];
    }
}

// Drag and Drop Functionality
function initializeDragAndDrop() {
    const componentItems = document.querySelectorAll('.component-item');
    const dropZone = document.getElementById('dropZone');
    
    if (!dropZone) return;
    
    componentItems.forEach(item => {
        item.addEventListener('dragstart', function(e) {
            e.dataTransfer.setData('text/plain', this.textContent);
            this.style.opacity = '0.5';
        });
        
        item.addEventListener('dragend', function(e) {
            this.style.opacity = '1';
        });
    });
    
    dropZone.addEventListener('dragover', function(e) {
        e.preventDefault();
        this.classList.add('dragover');
    });
    
    dropZone.addEventListener('dragleave', function(e) {
        this.classList.remove('dragover');
    });
    
    dropZone.addEventListener('drop', function(e) {
        e.preventDefault();
        this.classList.remove('dragover');
        
        const componentText = e.dataTransfer.getData('text/plain');
        addComponentToCanvas(componentText);
    });
    
    function addComponentToCanvas(componentText) {
        const demoComponents = dropZone.querySelector('.demo-components');
        const newComponent = document.createElement('div');
        newComponent.className = 'demo-component';
        newComponent.textContent = componentText;
        demoComponents.appendChild(newComponent);
        
        // Add remove functionality
        newComponent.addEventListener('click', function() {
            this.remove();
        });
    }
}

// Interactive Elements
function initializeInteractiveElements() {
    initializeButtons();
    initializeFormElements();
    initializeCards();
}

function initializeButtons() {
    // Template buttons
    const templateButtons = document.querySelectorAll('.template-card .btn');
    templateButtons.forEach(btn => {
        btn.addEventListener('click', function() {
            const templateName = this.closest('.template-card').querySelector('h3').textContent;
            showNotification(`${templateName} template applied successfully!`, 'success');
        });
    });
    
    // ETL Pipeline button
    const pipelineBtn = document.querySelector('.pipeline-canvas .btn');
    if (pipelineBtn) {
        pipelineBtn.addEventListener('click', function() {
            showNotification('New ETL pipeline created successfully!', 'success');
        });
    }
    
    // Insight action buttons
    const insightButtons = document.querySelectorAll('.insight-card .btn');
    insightButtons.forEach(btn => {
        btn.addEventListener('click', function() {
            const action = this.textContent;
            showNotification(`${action} action initiated`, 'info');
        });
    });
    
    // Chart control buttons
    const chartControls = document.querySelectorAll('.chart-controls .btn');
    chartControls.forEach(btn => {
        btn.addEventListener('click', function() {
            // Remove active class from siblings
            this.parentElement.querySelectorAll('.btn').forEach(b => {
                b.classList.remove('btn--primary');
                b.classList.add('btn--outline');
            });
            
            // Add active class to clicked button
            this.classList.remove('btn--outline');
            this.classList.add('btn--primary');
        });
    });
}

function initializeFormElements() {
    // Search functionality
    const searchInput = document.querySelector('.marketplace-search .form-control');
    const searchBtn = document.querySelector('.marketplace-search .btn');
    
    if (searchInput && searchBtn) {
        searchBtn.addEventListener('click', function() {
            const query = searchInput.value.trim();
            if (query) {
                showNotification(`Searching for "${query}" integrations...`, 'info');
            }
        });
        
        searchInput.addEventListener('keypress', function(e) {
            if (e.key === 'Enter') {
                searchBtn.click();
            }
        });
    }
    
    // Revenue calculator
    const revenueInput = document.querySelector('.calculator-input input[type="number"]');
    if (revenueInput) {
        revenueInput.addEventListener('input', function() {
            const customers = parseInt(this.value) || 0;
            const revenue = customers * 99; // £99 per customer
            const revenueAmount = document.querySelector('.revenue-amount');
            if (revenueAmount) {
                revenueAmount.textContent = `£${revenue.toLocaleString()}`;
            }
        });
    }
}

function initializeCards() {
    // Add hover effects and click interactions
    const cards = document.querySelectorAll('.metric-card, .insight-card, .template-card, .category-card');
    
    cards.forEach(card => {
        card.addEventListener('mouseenter', function() {
            this.style.transform = 'translateY(-4px)';
        });
        
        card.addEventListener('mouseleave', function() {
            this.style.transform = 'translateY(0)';
        });
    });
    
    // Connector tag interactions
    const connectorTags = document.querySelectorAll('.connector-tag');
    connectorTags.forEach(tag => {
        tag.addEventListener('click', function() {
            const connectorName = this.textContent;
            showNotification(`Configuring ${connectorName} integration...`, 'info');
        });
    });
}

// Mobile Navigation
function initializeMobileNavigation() {
    const sidebarToggle = document.getElementById('sidebarToggle');
    const sidebar = document.getElementById('sidebar');
    const mainContent = document.getElementById('mainContent');
    
    if (sidebarToggle && sidebar) {
        sidebarToggle.addEventListener('click', function() {
            sidebar.classList.toggle('open');
        });
        
        // Close sidebar when clicking outside
        document.addEventListener('click', function(e) {
            if (window.innerWidth <= 768 && 
                !sidebar.contains(e.target) && 
                !sidebarToggle.contains(e.target) && 
                sidebar.classList.contains('open')) {
                sidebar.classList.remove('open');
            }
        });
    }
    
    // Handle window resize
    window.addEventListener('resize', function() {
        if (window.innerWidth > 768 && sidebar) {
            sidebar.classList.remove('open');
        }
    });
}

// Section-specific initialization
function initializeSectionSpecific(sectionId) {
    switch(sectionId) {
        case 'dashboard':
            // Refresh dashboard charts
            Object.values(charts).forEach(chart => {
                if (chart && chart.update) {
                    chart.update();
                }
            });
            break;
        case 'predictive':
            animatePredictionCards();
            break;
        case 'builder':
            initializeBuilderTools();
            break;
        case 'mobile':
            // Refresh mobile chart
            if (charts.mobileChart) {
                charts.mobileChart.update();
            }
            break;
    }
}

function animatePredictionCards() {
    const predictionCards = document.querySelectorAll('.prediction-card');
    predictionCards.forEach((card, index) => {
        setTimeout(() => {
            card.style.transform = 'translateY(0)';
            card.style.opacity = '1';
        }, index * 200);
    });
}

function initializeBuilderTools() {
    // Initialize property panel updates
    const propertyInputs = document.querySelectorAll('.properties-panel select, .properties-panel input');
    propertyInputs.forEach(input => {
        input.addEventListener('change', function() {
            updateCanvasPreview();
        });
    });
    
    // Apply changes button
    const applyBtn = document.querySelector('.properties-panel .btn--primary');
    if (applyBtn) {
        applyBtn.addEventListener('click', function() {
            showNotification('Component properties updated successfully!', 'success');
        });
    }
}

function updateCanvasPreview() {
    // Simulate canvas update
    const demoComponents = document.querySelectorAll('.demo-component');
    demoComponents.forEach(component => {
        component.style.transform = 'scale(1.05)';
        setTimeout(() => {
            component.style.transform = 'scale(1)';
        }, 200);
    });
}

// Notification System
function showNotification(message, type = 'info') {
    const notification = document.createElement('div');
    notification.className = `notification notification--${type}`;
    notification.innerHTML = `
        <div class="notification-content">
            <span class="notification-icon">${getNotificationIcon(type)}</span>
            <span class="notification-message">${message}</span>
        </div>
        <button class="notification-close">&times;</button>
    `;
    
    // Add notification styles
    notification.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        background: var(--color-surface);
        border: 1px solid var(--color-border);
        border-radius: var(--radius-md);
        padding: var(--space-16);
        box-shadow: var(--shadow-lg);
        z-index: 3000;
        display: flex;
        align-items: center;
        gap: var(--space-12);
        min-width: 300px;
        max-width: 500px;
        transform: translateX(100%);
        transition: transform var(--duration-normal) var(--ease-standard);
    `;
    
    const notificationContent = notification.querySelector('.notification-content');
    notificationContent.style.cssText = `
        display: flex;
        align-items: center;
        gap: var(--space-8);
        flex: 1;
    `;
    
    const notificationClose = notification.querySelector('.notification-close');
    notificationClose.style.cssText = `
        background: none;
        border: none;
        font-size: var(--font-size-lg);
        cursor: pointer;
        color: var(--color-text-secondary);
        padding: 0;
        width: 20px;
        height: 20px;
    `;
    
    document.body.appendChild(notification);
    
    // Animate in
    setTimeout(() => {
        notification.style.transform = 'translateX(0)';
    }, 100);
    
    // Close functionality
    notificationClose.addEventListener('click', function() {
        closeNotification(notification);
    });
    
    // Auto close after 5 seconds
    setTimeout(() => {
        closeNotification(notification);
    }, 5000);
}

function closeNotification(notification) {
    notification.style.transform = 'translateX(100%)';
    setTimeout(() => {
        if (notification.parentElement) {
            notification.parentElement.removeChild(notification);
        }
    }, 300);
}

function getNotificationIcon(type) {
    const icons = {
        success: '✅',
        error: '❌',
        warning: '⚠️',
        info: 'ℹ️'
    };
    return icons[type] || icons.info;
}

// Keyboard Navigation
document.addEventListener('keydown', function(e) {
    // ESC key to close modals
    if (e.key === 'Escape') {
        const modal = document.querySelector('.modal.show');
        if (modal) {
            modal.classList.remove('show');
        }
    }
    
    // Ctrl/Cmd + K to open AI assistant
    if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
        e.preventDefault();
        document.getElementById('aiAssistant').click();
    }
});

// Performance Monitoring
function initializePerformanceMonitoring() {
    // Monitor chart rendering performance
    if (window.performance && window.performance.mark) {
        window.performance.mark('charts-start');
        
        // Check when all charts are rendered
        const checkChartsReady = setInterval(() => {
            if (Object.keys(charts).length >= 3) {
                window.performance.mark('charts-end');
                window.performance.measure('charts-render', 'charts-start', 'charts-end');
                clearInterval(checkChartsReady);
            }
        }, 100);
    }
}

// Analytics Tracking (placeholder)
function trackUserInteraction(action, category, label) {
    // This would integrate with your analytics platform
    console.log(`Analytics: ${category} - ${action} - ${label}`);
}

// Error Handling
window.addEventListener('error', function(e) {
    console.error('Application Error:', e.error);
    showNotification('An error occurred. Please try again.', 'error');
});

// Initialize performance monitoring
initializePerformanceMonitoring();

// Add event listeners for analytics tracking
document.addEventListener('click', function(e) {
    if (e.target.classList.contains('btn')) {
        const buttonText = e.target.textContent.trim();
        const section = currentSection;
        trackUserInteraction('click', 'button', `${section}-${buttonText}`);
    }
});

// Smooth scrolling for internal links
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function(e) {
        e.preventDefault();
        const target = document.querySelector(this.getAttribute('href'));
        if (target) {
            target.scrollIntoView({
                behavior: 'smooth',
                block: 'start'
            });
        }
    });
});

// Add loading states
function showLoading(element) {
    element.classList.add('loading');
}

function hideLoading(element) {
    element.classList.remove('loading');
}

// Simulate data loading
function simulateDataLoading() {
    const loadingElements = document.querySelectorAll('.chart-container, .metric-card');
    loadingElements.forEach(el => showLoading(el));
    
    setTimeout(() => {
        loadingElements.forEach(el => hideLoading(el));
    }, 1500);
}

// Initialize data loading simulation
setTimeout(simulateDataLoading, 500);