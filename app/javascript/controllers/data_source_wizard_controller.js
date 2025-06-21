import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["step", "nextButton", "prevButton", "submitButton", "progressBar", "stepIndicator"]
  static values = { currentStep: Number, totalSteps: Number }

  connect() {
    this.currentStepValue = 1
    this.totalStepsValue = 4
    this.updateStepDisplay()
    this.updateButtons()
  }

  nextStep() {
    if (this.validateCurrentStep()) {
      if (this.currentStepValue < this.totalStepsValue) {
        this.currentStepValue++
        this.updateStepDisplay()
        this.updateButtons()
        this.scrollToTop()
      }
    }
  }

  prevStep() {
    if (this.currentStepValue > 1) {
      this.currentStepValue--
      this.updateStepDisplay()
      this.updateButtons()
      this.scrollToTop()
    }
  }

  goToStep(event) {
    const targetStep = parseInt(event.currentTarget.dataset.step)
    if (targetStep <= this.currentStepValue || this.canNavigateToStep(targetStep)) {
      this.currentStepValue = targetStep
      this.updateStepDisplay()
      this.updateButtons()
      this.scrollToTop()
    }
  }

  updateStepDisplay() {
    // Hide all steps
    this.stepTargets.forEach((step, index) => {
      if (index + 1 === this.currentStepValue) {
        step.classList.remove('hidden')
        step.classList.add('animate-fade-in')
      } else {
        step.classList.add('hidden')
        step.classList.remove('animate-fade-in')
      }
    })

    // Update step indicators
    this.stepIndicatorTargets.forEach((indicator, index) => {
      const stepNumber = index + 1
      const circle = indicator.querySelector('.step-circle')
      const text = indicator.querySelector('.step-text')
      
      if (stepNumber < this.currentStepValue) {
        // Completed step
        circle.className = 'step-circle w-8 h-8 rounded-full flex items-center justify-center bg-indigo-600 text-white text-sm font-medium'
        circle.innerHTML = '<svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"></path></svg>'
        text.classList.add('text-indigo-600')
        text.classList.remove('text-gray-500')
      } else if (stepNumber === this.currentStepValue) {
        // Current step
        circle.className = 'step-circle w-8 h-8 rounded-full flex items-center justify-center bg-indigo-600 text-white text-sm font-medium'
        circle.textContent = stepNumber
        text.classList.add('text-indigo-600')
        text.classList.remove('text-gray-500')
      } else {
        // Future step
        circle.className = 'step-circle w-8 h-8 rounded-full flex items-center justify-center border-2 border-gray-300 text-gray-500 text-sm font-medium'
        circle.textContent = stepNumber
        text.classList.add('text-gray-500')
        text.classList.remove('text-indigo-600')
      }
    })

    // Update progress bar
    if (this.hasProgressBarTarget) {
      const progress = ((this.currentStepValue - 1) / (this.totalStepsValue - 1)) * 100
      this.progressBarTarget.style.width = `${progress}%`
    }
  }

  updateButtons() {
    // Previous button
    if (this.hasPrevButtonTarget) {
      if (this.currentStepValue === 1) {
        this.prevButtonTarget.classList.add('hidden')
      } else {
        this.prevButtonTarget.classList.remove('hidden')
      }
    }

    // Next button
    if (this.hasNextButtonTarget) {
      if (this.currentStepValue === this.totalStepsValue) {
        this.nextButtonTarget.classList.add('hidden')
      } else {
        this.nextButtonTarget.classList.remove('hidden')
      }
    }

    // Submit button
    if (this.hasSubmitButtonTarget) {
      if (this.currentStepValue === this.totalStepsValue) {
        this.submitButtonTarget.classList.remove('hidden')
      } else {
        this.submitButtonTarget.classList.add('hidden')
      }
    }
  }

  validateCurrentStep() {
    const currentStepElement = this.stepTargets[this.currentStepValue - 1]
    const requiredFields = currentStepElement.querySelectorAll('[required]')
    let isValid = true

    // Clear previous validation errors
    currentStepElement.querySelectorAll('.error-message').forEach(error => {
      error.remove()
    })

    requiredFields.forEach(field => {
      if (!field.value.trim()) {
        this.showFieldError(field, 'This field is required')
        isValid = false
      }
    })

    // Custom validation for specific steps
    switch (this.currentStepValue) {
      case 1:
        isValid = this.validateSourceSelection() && isValid
        break
      case 2:
        isValid = this.validateConfiguration() && isValid
        break
      case 3:
        isValid = this.validateDataPreview() && isValid
        break
    }

    return isValid
  }

  validateSourceSelection() {
    const sourceTypeInputs = document.querySelectorAll('input[name="data_source[source_type]"]')
    const isSelected = Array.from(sourceTypeInputs).some(input => input.checked)
    
    if (!isSelected) {
      this.showStepError('Please select a data source type')
      return false
    }
    return true
  }

  validateConfiguration() {
    // This will be implemented based on the selected source type
    return true
  }

  validateDataPreview() {
    // This will be implemented for file uploads and API connections
    return true
  }

  showFieldError(field, message) {
    const errorDiv = document.createElement('div')
    errorDiv.className = 'error-message text-red-600 text-sm mt-1'
    errorDiv.textContent = message
    field.parentNode.appendChild(errorDiv)
    field.classList.add('border-red-300', 'focus:border-red-500', 'focus:ring-red-500')
  }

  showStepError(message) {
    const currentStepElement = this.stepTargets[this.currentStepValue - 1]
    const errorDiv = document.createElement('div')
    errorDiv.className = 'error-message bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded mb-4'
    errorDiv.textContent = message
    currentStepElement.insertBefore(errorDiv, currentStepElement.firstChild)
  }

  canNavigateToStep(targetStep) {
    // Allow navigation to previous steps or next step if current is valid
    return targetStep <= this.currentStepValue || (targetStep === this.currentStepValue + 1 && this.validateCurrentStep())
  }

  scrollToTop() {
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  // Handle form submission
  submitForm(event) {
    if (!this.validateCurrentStep()) {
      event.preventDefault()
      return false
    }

    // Show loading state
    const submitButton = event.target
    const originalText = submitButton.textContent
    submitButton.disabled = true
    submitButton.innerHTML = `
      <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      Creating Data Source...
    `

    // Reset button after 30 seconds as fallback
    setTimeout(() => {
      submitButton.disabled = false
      submitButton.textContent = originalText
    }, 30000)
  }
}