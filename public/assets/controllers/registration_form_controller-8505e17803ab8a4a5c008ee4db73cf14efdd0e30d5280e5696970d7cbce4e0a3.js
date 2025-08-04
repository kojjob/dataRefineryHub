import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "organizationInput", 
    "firstNameInput", 
    "lastNameInput", 
    "passwordInput", 
    "passwordConfirmationInput",
    "passwordStrength",
    "passwordStrengthBar"
  ]

  connect() {
    this.setupPasswordStrengthChecker()
    this.setupFormAnimation()
  }

  setupPasswordStrengthChecker() {
    if (this.hasPasswordInputTarget) {
      this.passwordInputTarget.addEventListener('input', () => this.checkPasswordStrength())
    }
    
    if (this.hasPasswordConfirmationInputTarget) {
      this.passwordConfirmationInputTarget.addEventListener('input', () => this.checkPasswordMatch())
    }
  }

  setupFormAnimation() {
    // Stagger form field animations
    const inputs = this.element.querySelectorAll('input')
    inputs.forEach((input, index) => {
      input.style.opacity = '0'
      input.style.transform = 'translateX(-20px)'
      
      setTimeout(() => {
        input.style.transition = 'opacity 0.5s ease, transform 0.5s ease'
        input.style.opacity = '1'
        input.style.transform = 'translateX(0)'
      }, index * 50)
    })
  }

  checkPasswordStrength() {
    const password = this.passwordInputTarget.value
    let strength = 0
    let feedback = ''
    
    // Length check
    if (password.length >= 8) strength += 25
    if (password.length >= 12) strength += 15
    
    // Complexity checks
    if (/[a-z]/.test(password)) strength += 15
    if (/[A-Z]/.test(password)) strength += 15
    if (/[0-9]/.test(password)) strength += 15
    if (/[^A-Za-z0-9]/.test(password)) strength += 15
    
    // Update strength bar
    if (this.hasPasswordStrengthBarTarget) {
      this.passwordStrengthBarTarget.style.width = `${strength}%`
      
      // Color coding
      if (strength < 40) {
        this.passwordStrengthBarTarget.style.background = 'linear-gradient(to right, #ef4444, #f87171)'
        feedback = 'Weak'
      } else if (strength < 70) {
        this.passwordStrengthBarTarget.style.background = 'linear-gradient(to right, #f59e0b, #fbbf24)'
        feedback = 'Fair'
      } else {
        this.passwordStrengthBarTarget.style.background = 'linear-gradient(to right, #10b981, #34d399)'
        feedback = 'Strong'
      }
    }
    
    // Update strength text
    if (this.hasPasswordStrengthTarget) {
      this.passwordStrengthTarget.textContent = feedback
      this.passwordStrengthTarget.style.color = strength < 40 ? '#ef4444' : strength < 70 ? '#f59e0b' : '#10b981'
    }
  }

  checkPasswordMatch() {
    if (!this.hasPasswordInputTarget || !this.hasPasswordConfirmationInputTarget) return
    
    const password = this.passwordInputTarget.value
    const confirmation = this.passwordConfirmationInputTarget.value
    
    if (confirmation.length > 0) {
      if (password === confirmation) {
        this.passwordConfirmationInputTarget.classList.remove('border-red-500')
        this.passwordConfirmationInputTarget.classList.add('border-green-500')
      } else {
        this.passwordConfirmationInputTarget.classList.remove('border-green-500')
        this.passwordConfirmationInputTarget.classList.add('border-red-500')
      }
    } else {
      this.passwordConfirmationInputTarget.classList.remove('border-red-500', 'border-green-500')
    }
  }
};
