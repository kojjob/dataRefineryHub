import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["preview", "previewImage"]

  connect() {
    this.previewTarget.classList.add('hidden')
  }

  handleFileSelect(event) {
    const file = event.target.files[0]
    
    if (!file) {
      this.hidePreview()
      return
    }

    // Validate file type
    const allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif']
    if (!allowedTypes.includes(file.type)) {
      this.showError('Please select a valid image file (JPG, PNG, or GIF)')
      return
    }

    // Validate file size (5MB limit)
    const maxSize = 5 * 1024 * 1024 // 5MB in bytes
    if (file.size > maxSize) {
      this.showError('File size must be less than 5MB')
      return
    }

    // Show preview
    this.showPreview(file)
  }

  showPreview(file) {
    const reader = new FileReader()
    
    reader.onload = (e) => {
      this.previewImageTarget.src = e.target.result
      this.previewTarget.classList.remove('hidden')
      
      // Add a nice animation
      this.previewTarget.style.opacity = '0'
      this.previewTarget.style.transform = 'scale(0.8)'
      
      setTimeout(() => {
        this.previewTarget.style.transition = 'all 0.3s ease'
        this.previewTarget.style.opacity = '1'
        this.previewTarget.style.transform = 'scale(1)'
      }, 50)
    }
    
    reader.readAsDataURL(file)
  }

  hidePreview() {
    this.previewTarget.classList.add('hidden')
  }

  showError(message) {
    // Remove the selected file
    const fileInput = this.element.querySelector('input[type="file"]')
    if (fileInput) {
      fileInput.value = ''
    }
    
    this.hidePreview()
    
    // Show error message (you could enhance this with a toast notification)
    alert(message)
    
    // Or create a more sophisticated error display
    this.showErrorMessage(message)
  }

  showErrorMessage(message) {
    // Remove any existing error messages
    const existingError = this.element.querySelector('.avatar-error-message')
    if (existingError) {
      existingError.remove()
    }

    // Create error message element
    const errorDiv = document.createElement('div')
    errorDiv.className = 'avatar-error-message mt-3 p-3 bg-red-50 border border-red-200 rounded-xl'
    errorDiv.innerHTML = `
      <div class="flex items-center gap-2">
        <svg class="h-4 w-4 text-red-500 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z" />
        </svg>
        <span class="text-sm font-medium text-red-700">${message}</span>
      </div>
    `
    
    // Insert after the file input container
    const fileContainer = this.element.querySelector('.flex.items-center.gap-4')
    if (fileContainer) {
      fileContainer.parentNode.insertBefore(errorDiv, fileContainer.nextSibling)
      
      // Auto-remove after 5 seconds
      setTimeout(() => {
        if (errorDiv.parentNode) {
          errorDiv.remove()
        }
      }, 5000)
    }
  }
}