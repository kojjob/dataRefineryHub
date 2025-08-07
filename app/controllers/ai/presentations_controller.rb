# frozen_string_literal: true

module Ai
  class PresentationsController < ApplicationController
    before_action :ensure_organization_member
    before_action :set_presentation, only: [ :show, :download ]

    def index
      @presentations = policy_scope(Presentation).recent.includes(:organization)
      @templates = Ai::PresentationGeneratorService::TEMPLATE_TYPES
      @formats = Ai::PresentationGeneratorService::SUPPORTED_FORMATS
    end

    def new
      @presentation = Presentation.new
      @templates = Ai::PresentationGeneratorService::TEMPLATE_TYPES
      @formats = Ai::PresentationGeneratorService::SUPPORTED_FORMATS
    end

    def create
      @presentation = current_organization.presentations.build(presentation_params)
      @presentation.status = "generating"

      if @presentation.save
        # Generate presentation asynchronously
        GeneratePresentationJob.perform_later(@presentation.id)

        render json: {
          success: true,
          presentation_id: @presentation.id,
          status: @presentation.status,
          message: "Presentation generation started. You'll be notified when it's ready."
        }
      else
        render json: {
          success: false,
          errors: @presentation.errors.full_messages
        }, status: :unprocessable_entity
      end
    end

    def show
      @presentation_data = JSON.parse(@presentation.content) if @presentation.content.present?
      @slides = @presentation_data&.dig("slides") || []
    end

    def generate
      template_type = params[:template_type] || "executive_summary"
      output_format = params[:output_format] || "pdf"

      begin
        # Generate insights data first
        insights_service = Ai::InsightsEngineService.new(organization: current_organization)
        insights_data = insights_service.generate_insights

        # Generate presentation
        presentation_service = Ai::PresentationGeneratorService.new(
          organization: current_organization,
          insights_data: insights_data,
          template_type: template_type,
          output_format: output_format
        )

        result = presentation_service.generate_presentation

        # Save presentation record
        presentation = current_organization.presentations.create!(
          title: result[:metadata][:title],
          template_type: template_type,
          output_format: output_format,
          status: "completed",
          file_path: result[:file_path],
          download_url: result[:download_url] || result[:view_url],
          content: result[:slides_data].to_json,
          generated_at: Time.current
        )

        render json: {
          success: true,
          presentation: {
            id: presentation.id,
            title: presentation.title,
            template_type: presentation.template_type,
            output_format: presentation.output_format,
            status: presentation.status,
            download_url: presentation.download_url,
            generated_at: presentation.generated_at.iso8601
          },
          slides_count: result[:slides_data][:total_slides],
          message: "Presentation generated successfully!"
        }
      rescue => e
        Rails.logger.error "Presentation generation failed: #{e.message}"

        render json: {
          success: false,
          error: "Failed to generate presentation: #{e.message}"
        }, status: :internal_server_error
      end
    end

    def download
      # SECURITY FIX: Validate file path to prevent directory traversal
      if @presentation.file_path.present? && File.exist?(@presentation.file_path)
        begin
          # Validate file path is within allowed directories
          safe_file_path = validate_presentation_file_path!(@presentation.file_path)
          safe_filename = sanitize_filename("#{@presentation.title.parameterize}.#{@presentation.output_format}")

          send_file(safe_file_path,
                    filename: safe_filename,
                    type: content_type_for_format(@presentation.output_format))
        rescue SecurityError => e
          Rails.logger.warn "File access denied: #{e.message}"
          redirect_to ai_presentations_path, alert: "File access denied for security reasons."
        rescue ArgumentError => e
          Rails.logger.warn "Invalid file: #{e.message}"
          redirect_to ai_presentations_path, alert: "Presentation file not found."
        end
      else
        redirect_to ai_presentations_path, alert: "Presentation file not found."
      end
    end

    def status
      presentation = current_organization.presentations.find(params[:id])

      render json: {
        id: presentation.id,
        status: presentation.status,
        progress: presentation.progress_percentage || 0,
        message: status_message(presentation.status),
        download_url: presentation.status == "completed" ? presentation.download_url : nil
      }
    end

    def preview
      template_type = params[:template_type] || "executive_summary"

      # Generate preview data without creating actual files
      insights_service = Ai::InsightsEngineService.new(organization: current_organization)
      insights_data = insights_service.generate_insights

      presentation_service = Ai::PresentationGeneratorService.new(
        organization: current_organization,
        insights_data: insights_data,
        template_type: template_type,
        output_format: "html"
      )

      slides_data = presentation_service.generate_slides_data

      render json: {
        success: true,
        preview: {
          title: slides_data[:presentation_metadata][:title],
          slides_count: slides_data[:total_slides],
          slides: slides_data[:slides].first(3), # Preview first 3 slides
          template_type: template_type,
          generated_at: slides_data[:generated_at]
        }
      }
    end

    private

    def set_presentation
      @presentation = policy_scope(Presentation).find(params[:id])
    end

    def presentation_params
      params.require(:presentation).permit(:title, :template_type, :output_format, :description)
    end

    def content_type_for_format(format)
      case format
      when "pdf"
        "application/pdf"
      when "powerpoint"
        "application/vnd.openxmlformats-officedocument.presentationml.presentation"
      when "html"
        "text/html"
      else
        "application/octet-stream"
      end
    end

    def status_message(status)
      case status
      when "generating"
        "Generating your presentation..."
      when "completed"
        "Presentation ready for download"
      when "failed"
        "Generation failed. Please try again."
      else
        "Unknown status"
      end
    end

    # SECURITY METHODS: File validation
    def validate_presentation_file_path!(file_path)
      return nil if file_path.blank?

      # Define allowed directories for presentation files
      allowed_dirs = [
        Rails.root.join("tmp", "presentations").to_s,
        Rails.root.join("storage", "presentations").to_s,
        Rails.root.join("public", "presentations").to_s
      ]

      # Resolve absolute path to prevent path traversal
      resolved_path = File.expand_path(file_path)

      # Check if path is within allowed directories
      unless allowed_dirs.any? { |dir| resolved_path.start_with?(File.expand_path(dir)) }
        raise SecurityError, "File access denied: path outside allowed directories"
      end

      # Check if file exists and is a regular file
      unless File.exist?(resolved_path) && File.file?(resolved_path)
        raise ArgumentError, "Invalid file: #{file_path}"
      end

      # Check file size (50MB limit)
      if File.size(resolved_path) > 50.megabytes
        raise ArgumentError, "File too large: #{file_path}"
      end

      resolved_path
    end

    def sanitize_filename(filename)
      return "presentation" if filename.blank?

      # Remove dangerous characters and normalize
      safe_name = filename.gsub(/[^a-zA-Z0-9\-_\.]/, "_")
      safe_name = safe_name.gsub(/_{2,}/, "_") # Remove multiple underscores
      safe_name.truncate(100)
    end
  end
end
