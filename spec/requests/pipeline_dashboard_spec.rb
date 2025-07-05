require 'rails_helper'

RSpec.describe "PipelineDashboards", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/pipeline_dashboard/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /show" do
    it "returns http success" do
      get "/pipeline_dashboard/show"
      expect(response).to have_http_status(:success)
    end
  end
end
