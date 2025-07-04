require 'rails_helper'

RSpec.describe "ManualTasks", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/manual_tasks/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /show" do
    it "returns http success" do
      get "/manual_tasks/show"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /execute" do
    it "returns http success" do
      get "/manual_tasks/execute"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /approve" do
    it "returns http success" do
      get "/manual_tasks/approve"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /reject" do
    it "returns http success" do
      get "/manual_tasks/reject"
      expect(response).to have_http_status(:success)
    end
  end

end
