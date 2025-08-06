class ReportBuilderController < DataflowProController
  before_action :authenticate_user!
  before_action :ensure_organization_member
  before_action :set_report_template, only: [ :show, :edit, :update, :destroy, :preview, :duplicate ]

  def index
    @my_templates = current_organization.report_templates
                                      .includes(:user)
                                      .where(user: current_user)
                                      .recent

    @shared_templates = current_organization.report_templates
                                          .includes(:user)
                                          .where.not(user: current_user)
                                          .recent

    @public_templates = ReportTemplate.public_templates
                                    .featured
                                    .includes(:user, :organization)
                                    .most_used
                                    .limit(10)
  end

  def new
    @report_template = current_organization.report_templates.build(
      user: current_user,
      template_type: "custom"
    )
    @data_sources = current_organization.data_sources.active
    @chart_options = ReportTemplate.chart_options
  end

  def create
    @report_template = current_organization.report_templates.build(report_template_params)
    @report_template.user = current_user

    if @report_template.save
      # Add default components if requested
      if params[:add_defaults]
        add_default_components(@report_template)
      end

      redirect_to edit_report_builder_path(@report_template),
                  notice: "Report template created successfully. Start adding components!"
    else
      @data_sources = current_organization.data_sources.active
      @chart_options = ReportTemplate.chart_options
      render :new
    end
  end

  def show
    # Redirect to edit for now (builder interface)
    redirect_to edit_report_builder_path(@report_template)
  end

  def edit
    @components = @report_template.report_components.ordered
    @data_sources = current_organization.data_sources.active
    @chart_options = ReportTemplate.chart_options
    @available_components = {
      charts: ReportTemplate.chart_options,
      widgets: {
        metric: { name: "Single Metric", icon: "🔢", description: "Display a key metric with trend" },
        table: { name: "Data Table", icon: "📋", description: "Show data in tabular format" },
        text: { name: "Text Block", icon: "📝", description: "Add descriptions or notes" },
        filter: { name: "Filter Control", icon: "🎛️", description: "Add interactive filters" },
        image: { name: "Image", icon: "🖼️", description: "Add logos or diagrams" },
        divider: { name: "Divider", icon: "➖", description: "Separate sections" }
      }
    }
  end

  def update
    if @report_template.update(report_template_params)
      respond_to do |format|
        format.html { redirect_to edit_report_builder_path(@report_template), notice: "Report template updated." }
        format.json { render json: { success: true, message: "Report template updated." } }
      end
    else
      respond_to do |format|
        format.html {
          @components = @report_template.report_components.ordered
          @data_sources = current_organization.data_sources.active
          @chart_options = ReportTemplate.chart_options
          render :edit
        }
        format.json { render json: { success: false, errors: @report_template.errors.full_messages } }
      end
    end
  end

  def destroy
    @report_template.destroy
    redirect_to report_builder_index_path, notice: "Report template deleted."
  end

  def preview
    @report_data = @report_template.execute_query(params[:filters] || {})
    @components = @report_template.report_components.ordered

    respond_to do |format|
      format.html { render layout: "report_preview" }
      format.json { render json: @report_data }
    end
  end

  def duplicate
    @new_template = @report_template.clone_for_user(current_user)

    if @new_template.persisted?
      redirect_to edit_report_builder_path(@new_template),
                  notice: "Report template duplicated successfully."
    else
      redirect_to report_builder_index_path,
                  alert: "Failed to duplicate report template."
    end
  end

  # Component management actions
  def add_component
    @report_template = current_organization.report_templates.find(params[:id])
    @component = @report_template.report_components.build(component_params)

    # Set default properties based on type
    @component.properties = ReportComponent.default_properties_for(@component.component_type)

    if @component.save
      render json: {
        success: true,
        component: component_json(@component),
        message: "Component added successfully."
      }
    else
      render json: {
        success: false,
        errors: @component.errors.full_messages
      }
    end
  end

  def update_component
    @report_template = current_organization.report_templates.find(params[:id])
    @component = @report_template.report_components.find(params[:component_id])

    if @component.update(component_params)
      render json: {
        success: true,
        component: component_json(@component),
        message: "Component updated successfully."
      }
    else
      render json: {
        success: false,
        errors: @component.errors.full_messages
      }
    end
  end

  def delete_component
    @report_template = current_organization.report_templates.find(params[:id])
    @component = @report_template.report_components.find(params[:component_id])

    @component.destroy
    render json: {
      success: true,
      message: "Component removed successfully."
    }
  end

  def move_component
    @report_template = current_organization.report_templates.find(params[:id])
    @component = @report_template.report_components.find(params[:component_id])

    if @component.move_to(params[:x].to_i, params[:y].to_i)
      render json: { success: true }
    else
      render json: { success: false, errors: @component.errors.full_messages }
    end
  end

  def resize_component
    @report_template = current_organization.report_templates.find(params[:id])
    @component = @report_template.report_components.find(params[:component_id])

    if @component.resize(params[:width].to_i, params[:height].to_i)
      render json: { success: true }
    else
      render json: { success: false, errors: @component.errors.full_messages }
    end
  end

  # Template gallery
  def gallery
    @categories = {
      "Sales & Revenue" => [ "sales_dashboard", "revenue_analysis", "sales_pipeline" ],
      "Customer Analytics" => [ "customer_overview", "retention_analysis", "segmentation" ],
      "Operations" => [ "inventory_status", "supply_chain", "efficiency_metrics" ],
      "Marketing" => [ "campaign_performance", "channel_analysis", "roi_tracking" ],
      "Finance" => [ "financial_overview", "cash_flow", "expense_analysis" ]
    }

    @featured_templates = ReportTemplate.public_templates.featured.limit(6)
  end

  private

  def set_report_template
    @report_template = current_organization.report_templates.find(params[:id])
    authorize_report_template!
  end

  def authorize_report_template!
    unless @report_template.user == current_user ||
           current_user.organization_admin? ||
           @report_template.is_public?
      redirect_to report_builder_index_path, alert: "Not authorized to access this report template."
    end
  end

  def report_template_params
    params.require(:report_template).permit(
      :name, :description, :template_type, :is_public,
      configuration: {}, query_definition: {}, layout: {}
    )
  end

  def component_params
    params.require(:report_component).permit(
      :component_type, :component_id, :position_x, :position_y,
      :width, :height, :z_index,
      properties: {}, data_source: {}, styling: {}
    )
  end

  def add_default_components(template)
    # Add a title text component
    template.report_components.create!(
      component_type: "text",
      component_id: "title",
      properties: {
        content: "# #{template.name}\n\nCreated on #{Date.current.strftime('%B %d, %Y')}",
        format: "markdown",
        alignment: "center",
        font_size: "large"
      },
      position_x: 0,
      position_y: 0,
      width: 12,
      height: 2
    )

    # Add a date filter
    template.report_components.create!(
      component_type: "filter",
      component_id: "date_filter",
      properties: {
        filter_type: "date_range",
        label: "Date Range",
        default_value: "last_30_days",
        apply_to_all: true
      },
      position_x: 0,
      position_y: 2,
      width: 12,
      height: 1
    )
  end

  def component_json(component)
    {
      id: component.id,
      component_id: component.component_id,
      type: component.component_type,
      position: { x: component.position_x, y: component.position_y },
      size: { width: component.width, height: component.height },
      z_index: component.z_index,
      properties: component.properties,
      data_source: component.data_source,
      styling: component.styling
    }
  end
end
