// Professional Data Reflow Landing Page JavaScript

document.addEventListener('DOMContentLoaded', function() {
    // Initialize all functionality
    initNavigation();
    initScrollAnimations();
    initCTAHandlers();
    initMobileMenu();
    initSmoothScrolling();
});

// Navigation functionality
function initNavigation() {
    const header = document.querySelector('.header');
    const navLinks = document.querySelectorAll('.nav__link');
    
    // Add scroll effect to header
    window.addEventListener('scroll', function() {
        if (window.scrollY > 50) {
            header.classList.add('header--scrolled');
        } else {
            header.classList.remove('header--scrolled');
        }
    });
    
    // Highlight active navigation link
    window.addEventListener('scroll', function() {
        const sections = document.querySelectorAll('section[id]');
        const scrollPos = window.scrollY + 100;
        
        sections.forEach(section => {
            const sectionTop = section.offsetTop;
            const sectionHeight = section.offsetHeight;
            const sectionId = section.getAttribute('id');
            
            if (scrollPos >= sectionTop && scrollPos < sectionTop + sectionHeight) {
                navLinks.forEach(link => {
                    link.classList.remove('nav__link--active');
                    if (link.getAttribute('href') === `#${sectionId}`) {
                        link.classList.add('nav__link--active');
                    }
                });
            }
        });
    });
}

// Smooth scrolling for navigation links
function initSmoothScrolling() {
    const navLinks = document.querySelectorAll('a[href^="#"]');
    
    navLinks.forEach(link => {
        link.addEventListener('click', function(e) {
            e.preventDefault();
            
            const targetId = this.getAttribute('href').substring(1);
            const targetElement = document.getElementById(targetId);
            
            if (targetElement) {
                const headerHeight = document.querySelector('.header').offsetHeight;
                const targetPosition = targetElement.offsetTop - headerHeight;
                
                window.scrollTo({
                    top: targetPosition,
                    behavior: 'smooth'
                });
                
                // Close mobile menu if open
                const mobileMenu = document.querySelector('.nav__menu');
                const navToggle = document.querySelector('.nav__toggle');
                mobileMenu.classList.remove('nav__menu--open');
                navToggle.classList.remove('nav__toggle--open');
            }
        });
    });
}

// Mobile menu functionality
function initMobileMenu() {
    const navToggle = document.querySelector('.nav__toggle');
    const navMenu = document.querySelector('.nav__menu');
    
    if (navToggle && navMenu) {
        navToggle.addEventListener('click', function() {
            navMenu.classList.toggle('nav__menu--open');
            navToggle.classList.toggle('nav__toggle--open');
        });
        
        // Close menu when clicking outside
        document.addEventListener('click', function(e) {
            if (!navToggle.contains(e.target) && !navMenu.contains(e.target)) {
                navMenu.classList.remove('nav__menu--open');
                navToggle.classList.remove('nav__toggle--open');
            }
        });
    }
}

// Scroll animations
function initScrollAnimations() {
    const observerOptions = {
        threshold: 0.1,
        rootMargin: '0px 0px -50px 0px'
    };
    
    const observer = new IntersectionObserver(function(entries) {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('animate-in');
            }
        });
    }, observerOptions);
    
    // Observe elements for animation
    const animateElements = document.querySelectorAll('.testimonial, .feature, .dashboard__item, .pricing__card');
    animateElements.forEach(element => {
        observer.observe(element);
    });
    
    // Counter animation for metrics
    const counters = document.querySelectorAll('.metric__number, .roi__number');
    const counterObserver = new IntersectionObserver(function(entries) {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                animateCounter(entry.target);
            }
        });
    }, { threshold: 0.5 });
    
    counters.forEach(counter => {
        counterObserver.observe(counter);
    });
}

// Counter animation function
function animateCounter(element) {
    const text = element.textContent;
    const hasPlus = text.includes('+');
    const hasPercent = text.includes('%');
    const hasK = text.includes('K');
    const hasPound = text.includes('£');
    
    let numericValue = parseFloat(text.replace(/[^\d.]/g, ''));
    
    // Handle special cases
    if (hasK) {
        numericValue = numericValue * 1000;
    }
    
    const duration = 2000;
    const startTime = performance.now();
    
    function updateCounter(currentTime) {
        const elapsed = currentTime - startTime;
        const progress = Math.min(elapsed / duration, 1);
        
        // Easing function
        const easeOutQuart = 1 - Math.pow(1 - progress, 4);
        const currentValue = numericValue * easeOutQuart;
        
        let displayValue = Math.floor(currentValue);
        
        // Format the display value
        if (hasK && displayValue >= 1000) {
            displayValue = (displayValue / 1000).toFixed(1) + 'K';
        } else if (hasPercent) {
            displayValue = Math.floor(currentValue) + '%';
        } else if (hasPound) {
            displayValue = '£' + Math.floor(currentValue / 1000) + 'K';
        } else if (hasPlus) {
            displayValue = displayValue + '+';
        } else if (text === '99.9%') {
            displayValue = (currentValue / 10).toFixed(1) + '%';
        }
        
        element.textContent = displayValue;
        
        if (progress < 1) {
            requestAnimationFrame(updateCounter);
        } else {
            element.textContent = text; // Reset to original text
        }
    }
    
    requestAnimationFrame(updateCounter);
}

// CTA handlers
function initCTAHandlers() {
    const trialButtons = document.querySelectorAll('a[href="#trial"]');
    const demoButtons = document.querySelectorAll('a[href="#demo"]');
    
    trialButtons.forEach(button => {
        button.addEventListener('click', function(e) {
            e.preventDefault();
            handleTrialClick();
        });
    });
    
    demoButtons.forEach(button => {
        button.addEventListener('click', function(e) {
            e.preventDefault();
            handleDemoClick();
        });
    });
}

// Trial button handler
function handleTrialClick() {
    // Create modal for trial signup
    const modal = createModal({
        title: 'Start Your Free Trial',
        content: `
            <div class="trial-form">
                <p>Get started with Data Reflow today. No credit card required.</p>
                <form class="trial-form__form">
                    <div class="form-group">
                        <label for="trial-email" class="form-label">Business Email</label>
                        <input type="email" id="trial-email" class="form-control" placeholder="your@company.com" required>
                    </div>
                    <div class="form-group">
                        <label for="trial-company" class="form-label">Company Name</label>
                        <input type="text" id="trial-company" class="form-control" placeholder="Your Company" required>
                    </div>
                    <div class="form-group">
                        <label for="trial-size" class="form-label">Company Size</label>
                        <select id="trial-size" class="form-control" required>
                            <option value="">Select size</option>
                            <option value="1-10">1-10 employees</option>
                            <option value="11-50">11-50 employees</option>
                            <option value="51-200">51-200 employees</option>
                            <option value="201-500">201-500 employees</option>
                            <option value="500+">500+ employees</option>
                        </select>
                    </div>
                    <button type="submit" class="btn btn--primary btn--full-width">Start Free Trial</button>
                </form>
            </div>
        `
    });
    
    // Handle form submission
    const form = modal.querySelector('.trial-form__form');
    form.addEventListener('submit', function(e) {
        e.preventDefault();
        
        const email = document.getElementById('trial-email').value;
        const company = document.getElementById('trial-company').value;
        const size = document.getElementById('trial-size').value;
        
        if (email && company && size) {
            // Simulate API call
            showSuccessMessage('Trial account created! Check your email for next steps.');
            closeModal();
        }
    });
}

// Demo button handler
function handleDemoClick() {
    const modal = createModal({
        title: 'Schedule a Demo',
        content: `
            <div class="demo-form">
                <p>See Data Reflow in action with a personalized demo.</p>
                <form class="demo-form__form">
                    <div class="form-group">
                        <label for="demo-email" class="form-label">Business Email</label>
                        <input type="email" id="demo-email" class="form-control" placeholder="your@company.com" required>
                    </div>
                    <div class="form-group">
                        <label for="demo-name" class="form-label">Full Name</label>
                        <input type="text" id="demo-name" class="form-control" placeholder="Your Name" required>
                    </div>
                    <div class="form-group">
                        <label for="demo-phone" class="form-label">Phone Number</label>
                        <input type="tel" id="demo-phone" class="form-control" placeholder="+44 123 456 7890" required>
                    </div>
                    <div class="form-group">
                        <label for="demo-time" class="form-label">Preferred Time</label>
                        <select id="demo-time" class="form-control" required>
                            <option value="">Select time</option>
                            <option value="morning">Morning (9-12 PM)</option>
                            <option value="afternoon">Afternoon (12-5 PM)</option>
                            <option value="evening">Evening (5-8 PM)</option>
                        </select>
                    </div>
                    <button type="submit" class="btn btn--primary btn--full-width">Schedule Demo</button>
                </form>
            </div>
        `
    });
    
    // Handle form submission
    const form = modal.querySelector('.demo-form__form');
    form.addEventListener('submit', function(e) {
        e.preventDefault();
        
        const email = document.getElementById('demo-email').value;
        const name = document.getElementById('demo-name').value;
        const phone = document.getElementById('demo-phone').value;
        const time = document.getElementById('demo-time').value;
        
        if (email && name && phone && time) {
            // Simulate API call
            showSuccessMessage('Demo scheduled! We\'ll contact you within 24 hours.');
            closeModal();
        }
    });
}

// Modal creation utility
function createModal({ title, content }) {
    const modalHTML = `
        <div class="modal-overlay">
            <div class="modal">
                <div class="modal__header">
                    <h3 class="modal__title">${title}</h3>
                    <button class="modal__close" aria-label="Close modal">&times;</button>
                </div>
                <div class="modal__content">
                    ${content}
                </div>
            </div>
        </div>
    `;
    
    document.body.insertAdjacentHTML('beforeend', modalHTML);
    const modal = document.querySelector('.modal-overlay');
    
    // Close modal handlers
    const closeBtn = modal.querySelector('.modal__close');
    closeBtn.addEventListener('click', closeModal);
    
    modal.addEventListener('click', function(e) {
        if (e.target === modal) {
            closeModal();
        }
    });
    
    // Escape key handler
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape') {
            closeModal();
        }
    });
    
    return modal;
}

// Close modal utility
function closeModal() {
    const modal = document.querySelector('.modal-overlay');
    if (modal) {
        modal.remove();
    }
}

// Success message utility
function showSuccessMessage(message) {
    const successHTML = `
        <div class="success-message">
            <div class="success-message__content">
                <div class="success-message__icon">✓</div>
                <div class="success-message__text">${message}</div>
            </div>
        </div>
    `;
    
    document.body.insertAdjacentHTML('beforeend', successHTML);
    const successEl = document.querySelector('.success-message');
    
    // Auto-hide after 5 seconds
    setTimeout(() => {
        if (successEl) {
            successEl.remove();
        }
    }, 5000);
    
    // Click to dismiss
    successEl.addEventListener('click', function() {
        successEl.remove();
    });
}

// Testimonial carousel functionality (if needed)
function initTestimonialCarousel() {
    const testimonials = document.querySelectorAll('.testimonial');
    let currentIndex = 0;
    
    function showTestimonial(index) {
        testimonials.forEach((testimonial, i) => {
            testimonial.classList.toggle('testimonial--active', i === index);
        });
    }
    
    // Auto-rotate testimonials every 5 seconds
    setInterval(() => {
        currentIndex = (currentIndex + 1) % testimonials.length;
        showTestimonial(currentIndex);
    }, 5000);
}

// Performance optimization
function optimizeImages() {
    const images = document.querySelectorAll('img');
    
    images.forEach(img => {
        // Add loading attribute for better performance
        img.setAttribute('loading', 'lazy');
        
        // Add error handling
        img.addEventListener('error', function() {
            this.style.display = 'none';
        });
    });
}

// Initialize performance optimizations
document.addEventListener('DOMContentLoaded', function() {
    optimizeImages();
    
    // Add smooth scrolling behavior
    document.documentElement.style.scrollBehavior = 'smooth';
});

// Handle contact form submissions
function handleContactForm(form) {
    const formData = new FormData(form);
    const data = Object.fromEntries(formData);
    
    // Simulate API call
    return new Promise((resolve) => {
        setTimeout(() => {
            console.log('Form submitted:', data);
            resolve({ success: true });
        }, 1000);
    });
}

// Add loading states to buttons
function addLoadingState(button) {
    const originalText = button.textContent;
    button.textContent = 'Loading...';
    button.disabled = true;
    
    return function removeLoadingState() {
        button.textContent = originalText;
        button.disabled = false;
    };
}

// Analytics tracking (placeholder)
function trackEvent(eventName, eventData) {
    // Placeholder for analytics tracking
    console.log('Track event:', eventName, eventData);
}

// Initialize analytics tracking
document.addEventListener('DOMContentLoaded', function() {
    // Track page view
    trackEvent('page_view', { page: 'landing' });
    
    // Track CTA clicks
    document.querySelectorAll('.btn').forEach(button => {
        button.addEventListener('click', function() {
            trackEvent('cta_click', { 
                button_text: this.textContent.trim(),
                button_class: this.className 
            });
        });
    });
});