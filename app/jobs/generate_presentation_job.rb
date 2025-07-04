# frozen_string_literal: true

class GeneratePresentationJob < ApplicationJob
  queue_as :default
  
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  
  def perform(presentation_id)
    presentation = Presentation.find(presentation_id)
    
    Rails.logger.info "Starting presentation generation for ID: #{presentation_id}"
    
    begin
      # Update status
      presentation.update!(status: 'generating', progress_percentage: 10)
      
      # Generate insights data
      insights_service = Ai::InsightsEngineService.new(organization: presentation.organization)
      insights_data = insights_service.generate_insights
      
      presentation.update!(progress_percentage: 40)
      
      # Generate presentation
      presentation_service = Ai::PresentationGeneratorService.new(
        organization: presentation.organization,
        insights_data: insights_data,
        template_type: presentation.template_type,
        output_format: presentation.output_format
      )
      
      presentation.update!(progress_percentage: 70)
      
      result = presentation_service.generate_presentation
      
      # Update presentation with results
      presentation.update!(
        status: 'completed',
        progress_percentage: 100,
        file_path: result[:file_path],
        download_url: result[:download_url] || result[:view_url],
        content: result[:slides_data].to_json,
        generated_at: Time.current
      )
      
      Rails.logger.info "Presentation generation completed for ID: #{presentation_id}"
      
      # Send notification (if notification service exists)
      send_completion_notification(presentation) if defined?(NotificationService)
      
      # Broadcast completion via ActionCable
      broadcast_completion(presentation)
      
    rescue => e
      Rails.logger.error "Presentation generation failed for ID: #{presentation_id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      presentation.update!(
        status: 'failed',
        error_message: e.message,
        failed_at: Time.current
      )
      
      # Send failure notification
      send_failure_notification(presentation, e) if defined?(NotificationService)
      
      # Broadcast failure
      broadcast_failure(presentation, e)
      
      raise e # Re-raise to trigger retry logic if needed
    end
  end
  
  private
  
  def send_completion_notification(presentation)
    # This would integrate with the notification service
    # NotificationService.new.send_presentation_ready(presentation)
    Rails.logger.info "Would send completion notification for presentation: #{presentation.id}"
  end
  
  def send_failure_notification(presentation, error)
    # This would integrate with the notification service
    # NotificationService.new.send_presentation_failed(presentation, error)
    Rails.logger.info "Would send failure notification for presentation: #{presentation.id}"
  end
  
  def broadcast_completion(presentation)
    ActionCable.server.broadcast(
      "presentation_generation_#{presentation.organization_id}",
      {
        type: 'presentation_completed',
        presentation_id: presentation.id,
        title: presentation.title,
        download_url: presentation.download_url,
        slides_count: presentation.slides_count,
        generated_at: presentation.generated_at.iso8601
      }
    )
  end
  
  def broadcast_failure(presentation, error)
    ActionCable.server.broadcast(
      "presentation_generation_#{presentation.organization_id}",
      {
        type: 'presentation_failed',
        presentation_id: presentation.id,
        title: presentation.title,
        error_message: error.message
      }
    )
  end
end