# Enhanced Flash Helper
# Provides convenient methods for creating rich flash messages with titles, actions, and custom settings
module EnhancedFlashHelper
  # Create a simple flash message
  def flash_message(type, message)
    flash[type] = message
  end

  # Create an enhanced flash message with title and optional action
  def enhanced_flash(type, message, options = {})
    flash_data = {
      message: message,
      title: options[:title],
      action_text: options[:action_text],
      action_url: options[:action_url],
      persistent: options[:persistent] || false,
      auto_dismiss: options[:auto_dismiss] || 5000
    }

    flash[type] = flash_data
  end

  # Convenience methods for different flash types
  def flash_success(message, options = {})
    enhanced_flash(:success, message, options)
  end

  def flash_error(message, options = {})
    enhanced_flash(:error, message, options)
  end

  def flash_warning(message, options = {})
    enhanced_flash(:warning, message, options)
  end

  def flash_info(message, options = {})
    enhanced_flash(:info, message, options)
  end

  def flash_notice(message, options = {})
    enhanced_flash(:notice, message, options)
  end

  # Create a persistent flash message (won't auto-dismiss)
  def flash_persistent(type, message, options = {})
    enhanced_flash(type, message, options.merge(persistent: true))
  end

  # Create a flash message with an action button
  def flash_with_action(type, message, action_text, action_url, options = {})
    enhanced_flash(type, message, options.merge(
      action_text: action_text,
      action_url: action_url
    ))
  end

  # Create a flash message with custom auto-dismiss time
  def flash_timed(type, message, milliseconds, options = {})
    enhanced_flash(type, message, options.merge(auto_dismiss: milliseconds))
  end

  # Predefined flash messages for common scenarios
  def flash_saved(resource_name = "Record", options = {})
    flash_success("#{resource_name} saved successfully!", options)
  end

  def flash_updated(resource_name = "Record", options = {})
    flash_success("#{resource_name} updated successfully!", options)
  end

  def flash_deleted(resource_name = "Record", options = {})
    flash_success("#{resource_name} deleted successfully!", options)
  end

  def flash_created(resource_name = "Record", options = {})
    flash_success("#{resource_name} created successfully!", options)
  end

  def flash_validation_errors(resource, options = {})
    if resource.errors.any?
      error_count = resource.errors.count
      message = "#{error_count} #{'error'.pluralize(error_count)} prevented this #{resource.class.name.downcase} from being saved:"

      flash_error(message, options.merge(
        title: "Validation Failed",
        persistent: true
      ))
    end
  end

  def flash_unauthorized(options = {})
    flash_error("You are not authorized to perform this action.", options.merge(
      title: "Access Denied",
      action_text: "Sign In",
      action_url: new_user_session_path
    ))
  end

  def flash_not_found(resource_name = "Resource", options = {})
    flash_error("#{resource_name} not found.", options.merge(
      title: "Not Found"
    ))
  end

  def flash_server_error(options = {})
    flash_error("An unexpected error occurred. Please try again.", options.merge(
      title: "Server Error",
      action_text: "Contact Support",
      action_url: "/support"
    ))
  end

  # Flash message for successful operations with undo functionality
  def flash_with_undo(type, message, undo_url, options = {})
    flash_with_action(type, message, "Undo", undo_url, options.merge(
      auto_dismiss: 10000 # Give more time for undo actions
    ))
  end

  # Flash message for operations that require confirmation
  def flash_confirmation_needed(message, confirm_url, options = {})
    flash_warning(message, options.merge(
      title: "Confirmation Required",
      action_text: "Confirm",
      action_url: confirm_url,
      persistent: true
    ))
  end

  # Flash message for successful file uploads
  def flash_file_uploaded(filename, options = {})
    flash_success("File '#{filename}' uploaded successfully!", options.merge(
      title: "Upload Complete"
    ))
  end

  # Flash message for export/download operations
  def flash_export_ready(download_url, options = {})
    flash_info("Your export is ready for download.", options.merge(
      title: "Export Complete",
      action_text: "Download",
      action_url: download_url,
      auto_dismiss: 15000
    ))
  end

  # Flash message for background job completion
  def flash_job_completed(job_name, result_url = nil, options = {})
    message_options = options.merge(
      title: "Task Complete",
      auto_dismiss: 8000
    )

    if result_url
      message_options.merge!(
        action_text: "View Results",
        action_url: result_url
      )
    end

    flash_success("#{job_name} completed successfully!", message_options)
  end

  # Flash message for maintenance mode
  def flash_maintenance_mode(options = {})
    flash_warning("The system will be undergoing maintenance shortly. Please save your work.", options.merge(
      title: "Maintenance Notice",
      persistent: true
    ))
  end

  # Flash message for feature announcements
  def flash_feature_announcement(message, learn_more_url = nil, options = {})
    message_options = options.merge(
      title: "New Feature",
      auto_dismiss: 12000
    )

    if learn_more_url
      message_options.merge!(
        action_text: "Learn More",
        action_url: learn_more_url
      )
    end

    flash_info(message, message_options)
  end
end
