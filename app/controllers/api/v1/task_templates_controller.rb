# API::V1::TaskTemplatesController
# API endpoints for task template management
class Api::V1::TaskTemplatesController < Api::V1::BaseController
  before_action :set_task_template, only: [ :show, :update, :destroy, :duplicate, :create_task ]

  # GET /api/v1/task_templates
  # List all task templates with filtering
  def index
    templates = current_organization.task_templates.includes(:tasks)

    # Apply filters
    templates = templates.active if params[:active] == "true"
    templates = templates.by_category(params[:category]) if params[:category].present?
    templates = templates.by_execution_mode(params[:execution_mode]) if params[:execution_mode].present?
    templates = templates.search(params[:q]) if params[:q].present?

    # Filter by tags
    if params[:tags].present?
      tags = params[:tags].split(",").map(&:strip)
      templates = templates.where("tags ILIKE ANY (ARRAY[?])", tags.map { |t| "%#{t}%" })
    end

    # Apply sorting
    templates = apply_sorting(templates, %w[name created_at updated_at category])

    # Paginate
    templates = paginate(templates)
    pagination_headers(templates)

    render json: templates, each_serializer: Api::V1::TaskTemplateSerializer
  end

  # GET /api/v1/task_templates/library
  # Get common template library
  def library
    library = TaskTemplate.common_templates

    # Filter by category if specified
    if params[:category].present?
      library = library.select { |k, _| k.to_s == params[:category] }
    end

    render json: {
      library: library,
      categories: TaskTemplate::CATEGORIES,
      task_types: Task::TASK_TYPES,
      execution_modes: Task::EXECUTION_MODES
    }
  end

  # GET /api/v1/task_templates/:id
  # Get detailed information about a specific template
  def show
    render json: @task_template, serializer: Api::V1::TaskTemplateDetailSerializer
  end

  # POST /api/v1/task_templates
  # Create a new task template
  def create
    template = current_organization.task_templates.build(task_template_params)

    if template.save
      render json: template, serializer: Api::V1::TaskTemplateSerializer, status: :created
    else
      render_error("Failed to create task template", :unprocessable_entity, template.errors.full_messages)
    end
  end

  # POST /api/v1/task_templates/import_from_library
  # Import templates from the common library
  def import_from_library
    category = params[:category]
    template_names = params[:template_names] || []

    if category.blank? && template_names.empty?
      render_error("Category or template names must be specified", :bad_request)
      return
    end

    imported_templates = []
    errors = []

    # Get templates to import
    library = TaskTemplate.common_templates
    templates_to_import = if category.present?
      library[category.to_sym] || []
    else
      library.values.flatten.select { |t| template_names.include?(t[:name]) }
    end

    # Import each template
    templates_to_import.each do |template_attrs|
      template = current_organization.task_templates.build(
        template_attrs.merge(
          active: true,
          default_timeout: template_attrs[:default_timeout] || 300,
          default_priority: template_attrs[:default_priority] || 0,
          default_weight: template_attrs[:default_weight] || 1
        )
      )

      if template.save
        imported_templates << template
      else
        errors << { name: template_attrs[:name], errors: template.errors.full_messages }
      end
    end

    render json: {
      imported: imported_templates.map { |t| Api::V1::TaskTemplateSerializer.new(t) },
      errors: errors,
      summary: {
        requested: templates_to_import.count,
        imported: imported_templates.count,
        failed: errors.count
      }
    }, status: errors.any? ? :partial_content : :created
  end

  # PATCH/PUT /api/v1/task_templates/:id
  # Update a task template
  def update
    if @task_template.update(task_template_params)
      render json: @task_template, serializer: Api::V1::TaskTemplateSerializer
    else
      render_error("Failed to update task template", :unprocessable_entity, @task_template.errors.full_messages)
    end
  end

  # DELETE /api/v1/task_templates/:id
  # Delete a task template
  def destroy
    # Check if template is in use
    if @task_template.tasks.exists?
      render_error("Cannot delete template that has been used to create tasks", :conflict)
      return
    end

    @task_template.destroy
    head :no_content
  end

  # POST /api/v1/task_templates/:id/duplicate
  # Duplicate a task template
  def duplicate
    new_name = params[:name] || "#{@task_template.name} (Copy)"

    begin
      duplicated = @task_template.duplicate_template(new_name)
      render json: duplicated, serializer: Api::V1::TaskTemplateSerializer, status: :created
    rescue ActiveRecord::RecordInvalid => e
      render_error("Failed to duplicate template", :unprocessable_entity, e.record.errors.full_messages)
    end
  end

  # POST /api/v1/task_templates/:id/create_task
  # Create a task from this template
  def create_task
    pipeline_id = params[:pipeline_execution_id]

    if pipeline_id.blank?
      render_error("Pipeline execution ID is required", :bad_request)
      return
    end

    pipeline = current_organization.pipeline_executions.find(pipeline_id)

    # Create task from template
    begin
      task = @task_template.create_task_from_template(
        pipeline,
        task_overrides
      )

      render json: task, serializer: Api::V1::TaskSerializer, status: :created
    rescue => e
      render_error("Failed to create task from template", :unprocessable_entity, e.message)
    end
  end

  private

  def set_task_template
    @task_template = current_organization.task_templates.find(params[:id])
  end

  def task_template_params
    params.require(:task_template).permit(
      :name,
      :description,
      :task_type,
      :execution_mode,
      :category,
      :tags,
      :active,
      :default_timeout,
      :default_priority,
      :default_weight,
      template_config: {}
    )
  end

  def task_overrides
    params.permit(
      :name,
      :description,
      :timeout_seconds,
      :priority,
      configuration: {}
    ).to_h
  end
end
