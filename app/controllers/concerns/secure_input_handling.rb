# frozen_string_literal: true

# Controller concern for secure input handling and validation
module SecureInputHandling
  extend ActiveSupport::Concern

  included do
    before_action :sanitize_params, if: :params_present?
    rescue_from InputValidatorService::ValidationError, with: :handle_validation_error
  end

  private

  def sanitize_params
    # Automatically sanitize common parameters
    if params[:q].present?
      params[:q] = InputValidatorService.sanitize_string(
        params[:q], 
        max_length: 200,
        prevent_sql_injection: true,
        prevent_xss: true
      )
    end

    if params[:search].present?
      params[:search] = InputValidatorService.sanitize_string(
        params[:search],
        max_length: 200,
        prevent_sql_injection: true,
        prevent_xss: true
      )
    end

    # Sanitize sort parameters
    if params[:sort_by].present?
      validate_sort_params
    end

    # Sanitize pagination parameters
    if params[:page].present? || params[:per_page].present?
      validate_pagination_params
    end
  end

  def validate_sort_params
    allowed_sort_columns = controller_allowed_sort_columns
    
    unless allowed_sort_columns.include?(params[:sort_by].to_s)
      params[:sort_by] = allowed_sort_columns.first
    end

    if params[:sort_direction].present?
      unless %w[asc desc].include?(params[:sort_direction].to_s.downcase)
        params[:sort_direction] = 'asc'
      end
    end
  end

  def validate_pagination_params
    if params[:page].present?
      page = params[:page].to_i
      params[:page] = page > 0 ? page : 1
    end

    if params[:per_page].present?
      per_page = params[:per_page].to_i
      params[:per_page] = per_page.clamp(1, 100)
    end
  end

  def controller_allowed_sort_columns
    # Override in specific controllers to define allowed columns
    %w[created_at updated_at name]
  end

  def params_present?
    params.keys.any? { |key| !%w[controller action].include?(key.to_s) }
  end

  def handle_validation_error(exception)
    respond_to do |format|
      format.html do
        flash[:error] = "Validation error: #{exception.message}"
        redirect_back(fallback_location: root_path)
      end
      format.json do
        render json: { 
          error: 'Validation Error', 
          message: exception.message 
        }, status: :unprocessable_entity
      end
    end
  end

  # Helper methods for common validations

  def validate_email_param(email)
    InputValidatorService.validate_email(email)
  end

  def validate_url_param(url, options = {})
    InputValidatorService.validate_url(url, options)
  end

  def validate_json_param(json_string, schema = nil)
    InputValidatorService.validate_json(json_string, schema)
  end

  def validate_file_upload(file, options = {})
    InputValidatorService.validate_file_upload(file, options)
  end

  def sanitize_text_input(text, options = {})
    InputValidatorService.sanitize_string(
      text,
      options.merge(
        prevent_sql_injection: true,
        prevent_xss: true
      )
    )
  end

  def validate_and_sanitize_params(validations)
    InputValidatorService.validate_batch(validations)
  end

  # Strong parameters with validation
  def validated_params_for(model_name, allowed_attributes)
    raw_params = params.require(model_name).permit(*allowed_attributes)
    
    # Apply validation to each parameter
    validated = {}
    raw_params.each do |key, value|
      validated[key] = case value
                      when String
                        sanitize_text_input(value, max_length: 10_000)
                      when ActionDispatch::Http::UploadedFile
                        validate_file_upload(value)
                      else
                        value
                      end
    end
    
    ActionController::Parameters.new(validated).permit!
  end
end
