class ProjectsController < DataflowProController
  before_action :authenticate_user!
  before_action :ensure_organization_member
  before_action :set_project, only: [ :show, :edit, :update, :destroy ]

  def index
    @projects = current_organization.projects.includes(:user).order(created_at: :desc)
  end

  def show
    @landing_pages = @project.landing_pages.order(created_at: :desc)
  end

  def new
    @project = current_organization.projects.build
  end

  def create
    @project = current_organization.projects.build(project_params)
    @project.user = current_user

    if @project.save
      redirect_to @project, notice: "Project was successfully created."
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @project.update(project_params)
      redirect_to @project, notice: "Project was successfully updated."
    else
      render :edit
    end
  end

  def destroy
    @project.destroy
    redirect_to projects_url, notice: "Project was successfully deleted."
  end

  private

  def set_project
    @project = current_organization.projects.find_by!(slug: params[:slug])
  end

  def project_params
    params.require(:project).permit(:name, :description, :slug, :status, :settings)
  end
end
