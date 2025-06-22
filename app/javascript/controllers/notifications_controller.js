import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "dropdown", "badge", "count", "list"]
  static values = { 
    unreadCount: Number,
    refreshUrl: String 
  }

  connect() {
    this.refreshInterval = setInterval(() => {
      this.fetchUnreadCount()
    }, 30000) // Refresh every 30 seconds

    // Load initial notifications
    this.loadNotifications()
  }

  disconnect() {
    if (this.refreshInterval) {
      clearInterval(this.refreshInterval)
    }
  }

  toggle(event) {
    event.preventDefault()
    
    if (this.dropdownTarget.classList.contains("hidden")) {
      this.show()
    } else {
      this.hide()
    }
  }

  show() {
    this.dropdownTarget.classList.remove("hidden")
    // Load fresh notifications when opening
    this.loadNotifications()
  }

  hide() {
    this.dropdownTarget.classList.add("hidden")
  }

  async loadNotifications() {
    try {
      const response = await fetch('/api/v1/notifications?per_page=10', {
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json'
        }
      })

      if (response.ok) {
        const data = await response.json()
        this.renderNotifications(data.notifications)
        this.updateUnreadCount(data.unread_count)
      }
    } catch (error) {
      console.error('Error loading notifications:', error)
    }
  }

  async fetchUnreadCount() {
    try {
      const response = await fetch('/api/v1/notifications/unread_count', {
        headers: {
          'Accept': 'application/json'
        }
      })

      if (response.ok) {
        const data = await response.json()
        this.updateUnreadCount(data.unread_count)
      }
    } catch (error) {
      console.error('Error fetching unread count:', error)
    }
  }

  updateUnreadCount(count) {
    this.unreadCountValue = count
    
    if (this.hasCountTarget) {
      this.countTarget.textContent = count
    }

    if (this.hasBadgeTarget) {
      if (count > 0) {
        this.badgeTarget.classList.remove("hidden")
        this.badgeTarget.querySelector('.notification-count').textContent = count > 99 ? '99+' : count
      } else {
        this.badgeTarget.classList.add("hidden")
      }
    }
  }

  renderNotifications(notifications) {
    if (!this.hasListTarget) return

    if (notifications.length === 0) {
      this.listTarget.innerHTML = `
        <div class="px-4 py-8 text-center">
          <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" d="M14.857 17.082a23.848 23.848 0 005.454-1.31A8.967 8.967 0 0118 9.75v-.7V9A6 6 0 006 9v.75a8.967 8.967 0 01-2.312 6.022c1.733.64 3.56 1.085 5.455 1.31m5.714 0a24.255 24.255 0 01-5.714 0m5.714 0a3 3 0 11-5.714 0" />
          </svg>
          <p class="mt-2 text-sm text-gray-500">No notifications</p>
        </div>
      `
      return
    }

    const notificationsList = notifications.map(notification => `
      <div class="notification-item flex items-start space-x-3 px-4 py-3 hover:bg-gray-50 ${notification.read ? 'opacity-60' : ''}" 
           data-notification-id="${notification.id}">
        <div class="flex-shrink-0">
          <span class="text-lg">${notification.icon}</span>
        </div>
        <div class="flex-1 min-w-0">
          <div class="flex items-center justify-between">
            <p class="text-sm font-medium text-gray-900 truncate">
              ${notification.title}
            </p>
            <div class="flex items-center space-x-2">
              ${notification.priority === 'high' || notification.priority === 'urgent' ? 
                `<span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-red-100 text-red-800">
                  ${notification.priority}
                </span>` : ''}
              <p class="text-xs text-gray-500">
                ${this.formatTime(notification.created_at)}
              </p>
            </div>
          </div>
          <p class="text-sm text-gray-600 mt-1">
            ${notification.message}
          </p>
          <div class="flex items-center justify-between mt-2">
            <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium ${notification.color_class}">
              ${notification.type.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())}
            </span>
            <div class="flex space-x-2">
              ${!notification.read ? 
                `<button class="text-xs text-blue-600 hover:text-blue-800" 
                         data-action="click->notifications#markAsRead" 
                         data-notification-id="${notification.id}">
                  Mark as read
                </button>` : 
                `<button class="text-xs text-gray-500 hover:text-gray-700" 
                         data-action="click->notifications#markAsUnread" 
                         data-notification-id="${notification.id}">
                  Mark as unread
                </button>`}
              <button class="text-xs text-red-600 hover:text-red-800" 
                      data-action="click->notifications#deleteNotification" 
                      data-notification-id="${notification.id}">
                Delete
              </button>
            </div>
          </div>
        </div>
      </div>
    `).join('')

    this.listTarget.innerHTML = notificationsList

    // Add "View All" and "Mark All as Read" footer if there are notifications
    if (notifications.length > 0) {
      this.listTarget.innerHTML += `
        <div class="border-t border-gray-100 px-4 py-3 bg-gray-50">
          <div class="flex justify-between items-center">
            <button class="text-sm text-blue-600 hover:text-blue-800" 
                    data-action="click->notifications#markAllAsRead">
              Mark all as read
            </button>
            <a href="/notifications" class="text-sm text-blue-600 hover:text-blue-800">
              View all notifications
            </a>
          </div>
        </div>
      `
    }
  }

  async markAsRead(event) {
    event.preventDefault()
    const notificationId = event.target.dataset.notificationId
    
    try {
      const response = await fetch(`/api/v1/notifications/${notificationId}/mark_as_read`, {
        method: 'PATCH',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json'
        }
      })

      if (response.ok) {
        // Reload notifications to reflect changes
        this.loadNotifications()
      }
    } catch (error) {
      console.error('Error marking notification as read:', error)
    }
  }

  async markAsUnread(event) {
    event.preventDefault()
    const notificationId = event.target.dataset.notificationId
    
    try {
      const response = await fetch(`/api/v1/notifications/${notificationId}/mark_as_unread`, {
        method: 'PATCH',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json'
        }
      })

      if (response.ok) {
        // Reload notifications to reflect changes
        this.loadNotifications()
      }
    } catch (error) {
      console.error('Error marking notification as unread:', error)
    }
  }

  async markAllAsRead(event) {
    event.preventDefault()
    
    try {
      const response = await fetch('/api/v1/notifications/mark_all_as_read', {
        method: 'PATCH',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json'
        }
      })

      if (response.ok) {
        // Reload notifications to reflect changes
        this.loadNotifications()
      }
    } catch (error) {
      console.error('Error marking all notifications as read:', error)
    }
  }

  async deleteNotification(event) {
    event.preventDefault()
    const notificationId = event.target.dataset.notificationId
    
    if (!confirm('Are you sure you want to delete this notification?')) {
      return
    }
    
    try {
      const response = await fetch(`/api/v1/notifications/${notificationId}`, {
        method: 'DELETE',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json'
        }
      })

      if (response.ok) {
        // Reload notifications to reflect changes
        this.loadNotifications()
      }
    } catch (error) {
      console.error('Error deleting notification:', error)
    }
  }

  formatTime(timestamp) {
    const date = new Date(timestamp)
    const now = new Date()
    const diffInMinutes = Math.floor((now - date) / 60000)
    
    if (diffInMinutes < 1) {
      return 'Just now'
    } else if (diffInMinutes < 60) {
      return `${diffInMinutes}m ago`
    } else if (diffInMinutes < 1440) {
      return `${Math.floor(diffInMinutes / 60)}h ago`
    } else {
      return `${Math.floor(diffInMinutes / 1440)}d ago`
    }
  }

  // Close dropdown when clicking outside
  clickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.hide()
    }
  }
}