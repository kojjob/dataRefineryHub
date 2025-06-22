class Api::V1::VisualizationsController < Api::V1::BaseController
  before_action :set_data_source, only: [:create]

  def create
    @visualization = current_organization.visualizations.build(visualization_params)
    @visualization.data_source = @data_source
    @visualization.user = current_user

    if @visualization.save
      render json: { 
        success: true, 
        message: 'Visualization saved successfully',
        visualization: @visualization.as_json(only: [:id, :title, :chart_type, :created_at])
      }, status: :created
    else
      render json: { 
        success: false, 
        message: 'Failed to save visualization',
        errors: @visualization.errors.full_messages 
      }, status: :unprocessable_entity
    end
  end

  def index
    @visualizations = current_organization.visualizations
                                        .includes(:data_source, :user)
                                        .order(created_at: :desc)
    
    render json: {
      visualizations: @visualizations.map do |viz|
        {
          id: viz.id,
          title: viz.title,
          chart_type: viz.chart_type,
          data_source: viz.data_source&.name,
          created_by: viz.user&.name,
          created_at: viz.created_at
        }
      end
    }
  end

  def show
    @visualization = current_organization.visualizations.find(params[:id])
    
    render json: {
      visualization: @visualization.as_json(
        include: {
          data_source: { only: [:id, :name] },
          user: { only: [:id, :name] }
        }
      )
    }
  end

  def destroy
    @visualization = current_organization.visualizations.find(params[:id])
    
    if @visualization.user == current_user || current_user.admin?
      @visualization.destroy
      render json: { success: true, message: 'Visualization deleted successfully' }
    else
      render json: { success: false, message: 'Unauthorized' }, status: :forbidden
    end
  end

  private

  def set_data_source
    if params[:visualization][:data_source_id].present?
      @data_source = current_organization.data_sources.find(params[:visualization][:data_source_id])
    end
  end

  def visualization_params
    params.require(:visualization).permit(
      :title, :chart_type, :x_column, :y_column, :aggregation, 
      :filter_column, :filter_value, :data_source_id,
      config: {}
    )
  end
end