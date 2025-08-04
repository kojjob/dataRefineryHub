class LandingPagesController < DataflowProController
  before_action :authenticate_user!, except: [:preview]
  before_action :ensure_organization_member, except: [:preview]
  before_action :set_project
  before_action :set_landing_page, only: [:show, :edit, :update, :destroy, :preview, :publish]

  def index
    @landing_pages = @project.landing_pages.includes(:user).order(created_at: :desc)
  end

  def show
  end

  def new
    @landing_page = @project.landing_pages.build
    @landing_page.content = default_landing_page_content
  end

  def create
    @landing_page = @project.landing_pages.build(landing_page_params)
    @landing_page.user = current_user

    if @landing_page.save
      redirect_to [@project, @landing_page], notice: 'Landing page was successfully created.'
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @landing_page.update(landing_page_params)
      redirect_to [@project, @landing_page], notice: 'Landing page was successfully updated.'
    else
      render :edit
    end
  end

  def preview
    # This is the route that was missing - render the landing page in preview mode
    render layout: 'landing_page_preview'
  end

  def publish
    @landing_page.update(published: true, published_at: Time.current)
    redirect_to [@project, @landing_page], notice: 'Landing page was successfully published.'
  end

  def destroy
    @landing_page.destroy
    redirect_to [@project, :landing_pages], notice: 'Landing page was successfully deleted.'
  end

  private

  def set_project
    if action_name == 'preview'
      # For preview, find project across all organizations
      @project = Project.find_by!(slug: params[:project_slug])
    else
      # For authenticated actions, scope to current organization
      @project = current_organization.projects.find_by!(slug: params[:project_slug])
    end
  end

  def set_landing_page
    if action_name == 'preview'
      # For preview, only show published landing pages
      @landing_page = @project.landing_pages.published.find_by!(slug: params[:slug])
    else
      # For authenticated actions, show all landing pages
      @landing_page = @project.landing_pages.find_by!(slug: params[:slug])
    end
  end

  def landing_page_params
    params.require(:landing_page).permit(:name, :slug, :title, :description, :content, :meta_description, :settings, :template_type, :published)
  end

  def default_landing_page_content
    {
      hero: {
        title: "Transform Your Business with Data Intelligence",
        subtitle: "Make better decisions with real-time analytics and automated insights",
        cta_text: "Get Started Free",
        background_image: "/assets/hero-bg.jpg"
      },
      features: [
        {
          title: "Real-time Analytics",
          description: "Monitor your business performance with live dashboards",
          icon: "📊"
        },
        {
          title: "Automated Insights", 
          description: "Get AI-powered recommendations and alerts",
          icon: "🤖"
        },
        {
          title: "Easy Integration",
          description: "Connect all your business tools in minutes",
          icon: "🔗"
        }
      ],
      social_proof: {
        title: "Trusted by 1000+ businesses",
        testimonials: [
          {
            quote: "This platform transformed how we understand our customers",
            author: "Sarah Johnson",
            company: "TechCorp"
          }
        ]
      }
    }.to_json
  end
end
