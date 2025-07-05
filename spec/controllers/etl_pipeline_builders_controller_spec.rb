require 'rails_helper'

RSpec.describe EtlPipelineBuildersController, type: :controller do
  let(:user) { create(:user) }
  let(:organization) { user.organization }

  before do
    sign_in user
  end

  describe "GET #index" do
    it "returns a successful response" do
      get :index
      expect(response).to be_successful
    end

    it "assigns pipeline configurations" do
      pipeline = create(:pipeline_configuration, organization: organization)

      get :index
      expect(assigns(:pipelines)).to include(pipeline)
    end
  end

  describe "GET #new" do
    it "returns a successful response" do
      get :new
      expect(response).to be_successful
    end

    it "assigns a new pipeline configuration" do
      get :new
      expect(assigns(:pipeline)).to be_a_new(PipelineConfiguration)
    end
  end

  describe "POST #create" do
    let(:valid_attributes) do
      {
        name: "Test ETL Pipeline",
        description: "Test pipeline for specs",
        pipeline_type: "etl",
        source_config: { type: "api" },
        destination_config: { type: "warehouse" }
      }
    end

    context "with valid parameters" do
      it "creates a new PipelineConfiguration" do
        expect {
          post :create, params: { pipeline_configuration: valid_attributes }
        }.to change(PipelineConfiguration, :count).by(1)
      end

      it "redirects to the created pipeline" do
        post :create, params: { pipeline_configuration: valid_attributes }
        expect(response).to redirect_to(etl_pipeline_builder_path(PipelineConfiguration.last))
      end
    end

    context "with invalid parameters" do
      it "does not create a new PipelineConfiguration" do
        expect {
          post :create, params: { pipeline_configuration: { name: "" } }
        }.not_to change(PipelineConfiguration, :count)
      end

      it "renders the new template" do
        post :create, params: { pipeline_configuration: { name: "" } }
        expect(response).to render_template(:new)
      end
    end
  end

  describe "GET #show" do
    let(:pipeline) { create(:pipeline_configuration, organization: organization) }

    it "returns a successful response" do
      get :show, params: { id: pipeline.id }
      expect(response).to be_successful
    end
  end

  describe "POST #execute" do
    let(:pipeline) { create(:pipeline_configuration, organization: organization) }

    it "executes the pipeline" do
      post :execute, params: { id: pipeline.id }
      expect(response).to redirect_to(etl_pipeline_builder_path(pipeline))
    end
  end

  describe "POST #test" do
    let(:pipeline) { create(:pipeline_configuration, organization: organization) }

    it "tests the pipeline and returns JSON" do
      post :test, params: { id: pipeline.id }
      expect(response.content_type).to match(/json/)
    end
  end
end
