require 'rails_helper'

RSpec.describe PipelineMonitoringController, type: :controller do
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
    
    it "assigns active executions" do
      active_execution = create(:pipeline_execution, 
        organization: organization, 
        status: 'running'
      )
      completed_execution = create(:pipeline_execution, 
        organization: organization, 
        status: 'completed'
      )
      
      get :index
      expect(assigns(:active_executions)).to include(active_execution)
      expect(assigns(:active_executions)).not_to include(completed_execution)
    end
    
    it "calculates pipeline stats" do
      get :index
      expect(assigns(:pipeline_stats)).to be_a(Hash)
      expect(assigns(:pipeline_stats)).to include(
        :total_executions,
        :successful_executions,
        :failed_executions,
        :success_rate
      )
    end
  end
  
  describe "GET #show" do
    let(:execution) { create(:pipeline_execution, organization: organization) }
    
    it "returns a successful response" do
      get :show, params: { id: execution.id }
      expect(response).to be_successful
    end
    
    it "assigns the requested execution" do
      get :show, params: { id: execution.id }
      expect(assigns(:execution)).to eq(execution)
    end
    
    it "responds to json format" do
      get :show, params: { id: execution.id }, format: :json
      expect(response.content_type).to match(/json/)
    end
  end
  
  describe "GET #system_health" do
    it "returns system health metrics" do
      get :system_health
      expect(response).to be_successful
      expect(assigns(:queue_metrics)).to be_present
      expect(assigns(:worker_status)).to be_present
    end
  end
  
  describe "GET #alerts" do
    it "returns pipeline alerts" do
      get :alerts
      expect(response).to be_successful
    end
  end
end