require 'rails_helper'

RSpec.describe Analytics::RevenueController, type: :controller do
  let(:user) { create(:user) }
  let(:organization) { create(:organization, users: [user]) }
  let(:data_source) { create(:data_source, :shopify, organization: organization) }

  before do
    sign_in user
    allow(controller).to receive(:current_organization).and_return(organization)
  end

  describe "GET #index" do
    it "returns a successful response" do
      get :index
      expect(response).to be_successful
    end

    it "assigns revenue metrics" do
      get :index
      
      expect(assigns(:revenue_metrics)).to include(
        :total_revenue,
        :total_orders,
        :average_order_value,
        :tax_collected,
        :shipping_revenue,
        :discounts_given,
        :revenue_growth,
        :order_growth
      )
    end

    it "assigns fulfillment metrics" do
      get :index
      
      expect(assigns(:fulfillment_metrics)).to include(
        :total_orders,
        :fulfilled_count,
        :pending_count,
        :fulfillment_rate,
        :cancellation_rate,
        :pending_revenue,
        :avg_fulfillment_time
      )
    end

    it "assigns revenue trends" do
      get :index
      
      expect(assigns(:revenue_trends)).to include(
        :daily_revenue,
        :daily_orders
      )
    end

    it "renders the index template" do
      get :index
      expect(response).to render_template(:index)
    end
  end
end