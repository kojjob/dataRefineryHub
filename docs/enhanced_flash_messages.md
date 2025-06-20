# Enhanced Flash Messages Documentation

The Enhanced Flash Messages system provides a robust, visually appealing, and feature-rich way to display notifications to users in your Rails application.

## Features

- **Rich Visual Design**: Beautiful gradient backgrounds with smooth animations
- **Auto-dismiss**: Configurable auto-dismiss timers with progress bars
- **Persistent Messages**: Option to create messages that don't auto-dismiss
- **Action Buttons**: Add clickable actions to flash messages
- **Accessibility**: Full keyboard navigation and screen reader support
- **Responsive**: Works perfectly on mobile and desktop
- **Pause on Hover**: Auto-dismiss pauses when user hovers over message
- **Multiple Types**: Support for success, error, warning, info, notice, alert, and default
- **Programmatic Creation**: Create flash messages from JavaScript

## Basic Usage

### Simple Flash Messages

```ruby
# In your controller
flash[:success] = "Record saved successfully!"
flash[:error] = "Something went wrong."
flash[:warning] = "Please review your input."
flash[:info] = "New feature available!"
flash[:notice] = "Welcome back!"
```

### Enhanced Flash Messages with Helper

```ruby
# Include the helper in your controller or application controller
include EnhancedFlashHelper

# Simple enhanced messages
flash_success("Data exported successfully!")
flash_error("Failed to process request.")
flash_warning("Your session will expire soon.")

# Messages with titles
flash_success("Export completed!", title: "Success")
flash_error("Validation failed", title: "Error")

# Messages with action buttons
flash_with_action(:info, "New version available", "Update Now", "/update")

# Persistent messages (won't auto-dismiss)
flash_persistent(:warning, "Maintenance scheduled for tonight")

# Custom auto-dismiss time (in milliseconds)
flash_timed(:success, "Quick notification", 3000)
```

## Advanced Usage

### Complex Flash Messages

```ruby
# Full-featured flash message
enhanced_flash(:success, "Your report has been generated successfully!", {
  title: "Export Complete",
  action_text: "Download Report",
  action_url: "/reports/download/123",
  auto_dismiss: 10000,  # 10 seconds
  persistent: false
})
```

### Predefined Helper Methods

```ruby
# Common CRUD operations
flash_saved("User profile")
flash_updated("Settings")
flash_deleted("Document")
flash_created("New project")

# Validation errors
flash_validation_errors(@user)

# Common scenarios
flash_unauthorized
flash_not_found("Page")
flash_server_error

# File operations
flash_file_uploaded("document.pdf")
flash_export_ready("/downloads/export.csv")

# Background jobs
flash_job_completed("Data import", "/imports/results")

# Undo functionality
flash_with_undo(:success, "Item deleted", "/items/123/restore")

# Confirmations
flash_confirmation_needed("This action cannot be undone", "/confirm")

# Announcements
flash_feature_announcement("Try our new dashboard!", "/features/dashboard")
flash_maintenance_mode
```

## JavaScript Integration

### Creating Flash Messages from JavaScript

```javascript
// Simple message
createFlashMessage('success', 'Operation completed!');

// Message with options
createFlashMessage('info', 'New notification', {
  title: 'Update Available',
  actionText: 'Learn More',
  actionUrl: '/updates',
  autoDismiss: 8000,
  persistent: false
});
```

### Stimulus Controller Integration

```javascript
// In your Stimulus controller
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  showSuccess() {
    createFlashMessage('success', 'Action completed successfully!');
  }
  
  showError() {
    createFlashMessage('error', 'Something went wrong', {
      title: 'Error',
      persistent: true
    });
  }
}
```

## Message Types and Styling

### Available Types

- **success**: Green gradient, for successful operations
- **error**: Red gradient, for errors and failures
- **warning**: Orange gradient, for warnings and cautions
- **info**: Blue gradient, for informational messages
- **notice**: Purple gradient, for general notices
- **alert**: Orange gradient, for alerts requiring attention
- **default**: Gray gradient, for neutral messages

### Visual Features

- Gradient backgrounds with subtle animations
- Left border accent colors
- Icons for each message type
- Progress bars for auto-dismiss timing
- Smooth slide-in/slide-out animations
- Hover effects and focus states
- Backdrop blur effects

## Configuration Options

### Auto-dismiss Settings

```ruby
# Default auto-dismiss times by type (in milliseconds)
DEFAULT_DISMISS_TIMES = {
  success: 5000,   # 5 seconds
  error: 0,        # Persistent by default
  warning: 8000,   # 8 seconds
  info: 6000,      # 6 seconds
  notice: 5000,    # 5 seconds
  alert: 0,        # Persistent by default
  default: 5000    # 5 seconds
}
```

### Customization

```ruby
# Custom auto-dismiss time
flash_success("Quick message", auto_dismiss: 3000)

# Disable auto-dismiss
flash_error("Important error", persistent: true)

# Custom styling (add CSS classes)
flash_info("Custom message", class: "flash-large flash-custom")
```

## Accessibility Features

- **Keyboard Navigation**: Press `Escape` to dismiss focused messages
- **Screen Reader Support**: Proper ARIA labels and live regions
- **Focus Management**: Messages are focusable for keyboard users
- **High Contrast Support**: Adapts to high contrast mode preferences
- **Reduced Motion**: Respects user's motion preferences
- **Color Blind Friendly**: Uses icons and patterns, not just colors

## Best Practices

### When to Use Each Type

- **Success**: Completed actions, saved data, successful operations
- **Error**: Failed operations, validation errors, system errors
- **Warning**: Potential issues, confirmations needed, expiring sessions
- **Info**: New features, helpful tips, status updates
- **Notice**: General notifications, welcome messages
- **Alert**: Urgent attention needed, security warnings

### Message Content Guidelines

1. **Be Concise**: Keep messages short and actionable
2. **Be Specific**: Clearly state what happened or what's needed
3. **Provide Actions**: Include relevant action buttons when appropriate
4. **Use Appropriate Timing**: Match auto-dismiss time to message importance
5. **Consider Context**: Use persistent messages for critical information

### Performance Considerations

- Flash messages are rendered server-side for better SEO and accessibility
- CSS animations use hardware acceleration for smooth performance
- Auto-dismiss timers are paused when the page is not visible
- Messages are automatically cleaned up when dismissed

## Troubleshooting

### Common Issues

1. **Messages not appearing**: Check that the flash messages container exists in your layout
2. **Styling issues**: Ensure the enhanced_flash_messages.css is included
3. **JavaScript errors**: Verify the Stimulus controller is properly loaded
4. **Auto-dismiss not working**: Check that the controller is connected to the element

### Debug Mode

```javascript
// Enable debug logging in development
if (Rails.env === 'development') {
  window.flashDebug = true;
}
```

## Migration from Standard Flash

The enhanced flash system is backward compatible with standard Rails flash messages. Existing flash messages will automatically use the new styling and features.

```ruby
# This still works
flash[:notice] = "Standard message"

# But this provides more features
flash_notice("Enhanced message", title: "Notice")
```

## Examples

### User Registration

```ruby
class UsersController < ApplicationController
  include EnhancedFlashHelper
  
  def create
    @user = User.new(user_params)
    
    if @user.save
      flash_success("Welcome to DataReflow!", {
        title: "Account Created",
        action_text: "Complete Profile",
        action_url: edit_user_path(@user)
      })
      redirect_to dashboard_path
    else
      flash_validation_errors(@user)
      render :new
    end
  end
end
```

### File Upload

```ruby
class DocumentsController < ApplicationController
  include EnhancedFlashHelper
  
  def create
    @document = Document.new(document_params)
    
    if @document.save
      flash_file_uploaded(@document.filename, {
        action_text: "View Document",
        action_url: document_path(@document)
      })
    else
      flash_error("Failed to upload file. Please try again.")
    end
    
    redirect_to documents_path
  end
end
```

### Background Job Completion

```ruby
class DataImportJob < ApplicationJob
  include EnhancedFlashHelper
  
  def perform(user_id, file_path)
    user = User.find(user_id)
    
    begin
      # Process import...
      
      # Store flash message in session for next request
      user.session[:flash] = {
        success: enhanced_flash_data(:success, "Data import completed successfully!", {
          title: "Import Complete",
          action_text: "View Results",
          action_url: "/imports/#{import.id}"
        })
      }
    rescue => e
      user.session[:flash] = {
        error: enhanced_flash_data(:error, "Import failed: #{e.message}", {
          title: "Import Error",
          persistent: true
        })
      }
    end
  end
end
```

This enhanced flash message system provides a professional, accessible, and feature-rich way to communicate with your users while maintaining the simplicity of Rails' built-in flash system.