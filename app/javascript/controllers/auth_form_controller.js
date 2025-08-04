import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["emailInput", "passwordInput", "submitButton"]

  connect() {
    this.setupValidation()
    this.animateFormEntry()
  }

  setupValidation() {
    if (this.hasEmailInputTarget) {
      this.emailInputTarget.addEventListener('blur', () => this.validateEmail())
    }
    if (this.hasPasswordInputTarget) {
      this.passwordInputTarget.addEventListener('input', () => this.validatePassword())
    }
  }

  animateFormEntry() {
    // Animate form elements on page load
    const elements = this.element.querySelectorAll('input, button, .auth-glassmorphic')
    elements.forEach((el, index) => {
      el.style.opacity = '0'
      el.style.transform = 'translateY(20px)'
      
      setTimeout(() => {
        el.style.transition = 'opacity 0.5s ease, transform 0.5s ease'
        el.style.opacity = '1'
        el.style.transform = 'translateY(0)'
      }, index * 100)
    })
  }

  validateEmail() {
    const email = this.emailInputTarget.value
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    
    if (!emailRegex.test(email) && email.length > 0) {
      this.showError(this.emailInputTarget, 'Please enter a valid email address')
    } else {
      this.clearError(this.emailInputTarget)
    }
  }

  validatePassword() {
    const password = this.passwordInputTarget.value
    
    if (password.length > 0 && password.length < 6) {
      this.showError(this.passwordInputTarget, 'Password must be at least 6 characters')
    } else {
      this.clearError(this.passwordInputTarget)
    }
  }

  togglePassword(event) {
    event.preventDefault()
    const type = this.passwordInputTarget.type === 'password' ? 'text' : 'password'
    this.passwordInputTarget.type = type
    
    // Update icon
    const icon = event.currentTarget.querySelector('svg')
    if (type === 'text') {
      icon.innerHTML = `
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21"></path>
      `
    } else {
      icon.innerHTML = `
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path>
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path>
      `
    }
  }

  handleSubmit(event) {
    // Add loading state to button
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.classList.add('auth-loading')
      this.submitButtonTarget.disabled = true
    }

    // Add subtle animation to form
    this.element.classList.add('scale-[0.99]')
    setTimeout(() => {
      this.element.classList.remove('scale-[0.99]')
    }, 200)
  }

  showError(input, message) {
    // Remove any existing error
    this.clearError(input)
    
    // Add error styling
    input.classList.add('border-red-500', 'auth-error-shake')
    
    // Create error message
    const errorDiv = document.createElement('div')
    errorDiv.className = 'text-sm text-red-600 mt-1'
    errorDiv.textContent = message
    errorDiv.id = `${input.id}-error`
    
    input.parentElement.appendChild(errorDiv)
    
    // Remove shake animation after completion
    setTimeout(() => {
      input.classList.remove('auth-error-shake')
    }, 600)
  }

  clearError(input) {
    input.classList.remove('border-red-500')
    const errorDiv = document.getElementById(`${input.id}-error`)
    if (errorDiv) {
      errorDiv.remove()
    }
  }
}