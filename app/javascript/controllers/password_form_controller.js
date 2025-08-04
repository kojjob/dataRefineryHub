import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["passwordInput", "confirmationInput", "strengthBar", "strengthText"]

  connect() {
    this.setupPasswordStrengthChecker()
    this.setupPasswordMatchChecker()
  }

  setupPasswordStrengthChecker() {
    if (this.hasPasswordInputTarget) {
      this.passwordInputTarget.addEventListener('input', () => this.checkPasswordStrength())
    }
  }

  setupPasswordMatchChecker() {
    if (this.hasConfirmationInputTarget) {
      this.confirmationInputTarget.addEventListener('input', () => this.checkPasswordMatch())
    }
  }

  checkPasswordStrength() {
    const password = this.passwordInputTarget.value
    let strength = 0
    
    // Length check
    if (password.length >= 6) strength += 25
    if (password.length >= 10) strength += 15
    
    // Complexity checks
    if (/[a-z]/.test(password)) strength += 15
    if (/[A-Z]/.test(password)) strength += 15
    if (/[0-9]/.test(password)) strength += 15
    if (/[^A-Za-z0-9]/.test(password)) strength += 15
    
    // Update strength bar
    if (this.hasStrengthBarTarget) {
      this.strengthBarTarget.style.width = `${strength}%`
      
      // Update requirement checkmarks
      const requirements = this.element.querySelectorAll('.password-requirement')
      requirements.forEach((req) => {
        const type = req.dataset.requirement
        const icon = req.querySelector('svg')
        let met = false
        
        switch(type) {
          case 'length':
            met = password.length >= 6
            break
          case 'uppercase':
            met = /[A-Z]/.test(password)
            break
          case 'number-special':
            met = /[0-9]/.test(password) || /[^A-Za-z0-9]/.test(password)
            break
        }
        
        if (met) {
          icon.classList.remove('text-gray-400')
          icon.classList.add('text-green-500')
        } else {
          icon.classList.remove('text-green-500')
          icon.classList.add('text-gray-400')
        }
      })
    }
  }

  checkPasswordMatch() {
    if (!this.hasPasswordInputTarget || !this.hasConfirmationInputTarget) return
    
    const password = this.passwordInputTarget.value
    const confirmation = this.confirmationInputTarget.value
    
    if (confirmation.length > 0) {
      if (password === confirmation) {
        this.confirmationInputTarget.classList.remove('border-red-500')
        this.confirmationInputTarget.classList.add('border-green-500')
        // Update icon color
        const icon = this.confirmationInputTarget.previousElementSibling?.querySelector('svg')
        if (icon) {
          icon.classList.remove('text-gray-400')
          icon.classList.add('text-green-500')
        }
      } else {
        this.confirmationInputTarget.classList.remove('border-green-500')
        this.confirmationInputTarget.classList.add('border-red-500')
        // Update icon color
        const icon = this.confirmationInputTarget.previousElementSibling?.querySelector('svg')
        if (icon) {
          icon.classList.remove('text-green-500')
          icon.classList.add('text-gray-400')
        }
      }
    } else {
      this.confirmationInputTarget.classList.remove('border-red-500', 'border-green-500')
      // Reset icon color
      const icon = this.confirmationInputTarget.previousElementSibling?.querySelector('svg')
      if (icon) {
        icon.classList.remove('text-green-500')
        icon.classList.add('text-gray-400')
      }
    }
  }
}