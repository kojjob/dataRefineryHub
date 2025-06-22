import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="navbar"
export default class extends Controller {
  showShortcuts(event) {
    event.preventDefault()
    this.showModal('Keyboard Shortcuts', `
      <div class="space-y-4">
        <div class="grid grid-cols-2 gap-4">
          <div>
            <div class="font-medium text-gray-900 mb-2">Navigation</div>
            <div class="space-y-1 text-sm text-gray-600">
              <div class="flex justify-between"><span>Dashboard</span><kbd class="px-2 py-1 bg-gray-100 rounded text-xs">G + D</kbd></div>
              <div class="flex justify-between"><span>Analytics</span><kbd class="px-2 py-1 bg-gray-100 rounded text-xs">G + A</kbd></div>
              <div class="flex justify-between"><span>Data Sources</span><kbd class="px-2 py-1 bg-gray-100 rounded text-xs">G + S</kbd></div>
            </div>
          </div>
          <div>
            <div class="font-medium text-gray-900 mb-2">Actions</div>
            <div class="space-y-1 text-sm text-gray-600">
              <div class="flex justify-between"><span>Search</span><kbd class="px-2 py-1 bg-gray-100 rounded text-xs">Cmd + K</kbd></div>
              <div class="flex justify-between"><span>Add Source</span><kbd class="px-2 py-1 bg-gray-100 rounded text-xs">A + S</kbd></div>
              <div class="flex justify-between"><span>Invite User</span><kbd class="px-2 py-1 bg-gray-100 rounded text-xs">I + U</kbd></div>
            </div>
          </div>
        </div>
      </div>
    `)
  }
  
  showModal(title, content) {
    const modal = document.createElement('div')
    modal.className = 'fixed inset-0 z-50 overflow-y-auto'
    modal.innerHTML = `
      <div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity" onclick="this.closest('.fixed').remove()"></div>
        <div class="relative transform overflow-hidden rounded-lg bg-white text-left shadow-xl transition-all sm:my-8 sm:w-full sm:max-w-lg">
          <div class="bg-white px-4 pb-4 pt-5 sm:p-6 sm:pb-4">
            <div class="flex items-center justify-between mb-4">
              <h3 class="text-lg font-semibold text-gray-900">${title}</h3>
              <button class="text-gray-400 hover:text-gray-600" onclick="this.closest('.fixed').remove()">
                <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
            <div>${content}</div>
          </div>
        </div>
      </div>
    `
    document.body.appendChild(modal)
  }
}