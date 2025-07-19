# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'shared/_unified_navigation', type: :view do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }

  before do
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:user_signed_in?).and_return(true)
    allow(view).to receive(:controller_name).and_return('dashboard')
    allow(view).to receive(:controller_path).and_return('dashboard')
    allow(view).to receive(:action_name).and_return('index')

    # Mock path helpers
    allow(view).to receive(:dashboard_path).and_return('/dashboard')
    allow(view).to receive(:analytics_path).and_return('/analytics')
    allow(view).to receive(:data_sources_path).and_return('/data_sources')
    allow(view).to receive(:industry_templates_path).and_return('/industry_templates')
    allow(view).to receive(:pipeline_dashboard_index_path).and_return('/pipeline_dashboard')
    allow(view).to receive(:analytics_revenue_index_path).and_return('/analytics/revenue')
    allow(view).to receive(:analytics_customers_path).and_return('/analytics/customers')
    allow(view).to receive(:analytics_products_path).and_return('/analytics/products')
    allow(view).to receive(:dashboard_ai_bi_agent_index_path).and_return('/ai/bi_agent')
    allow(view).to receive(:history_ai_chat_index_path).and_return('/ai/chat')
    allow(view).to receive(:ai_automated_actions_path).and_return('/ai/automated_actions')
    allow(view).to receive(:ai_predictions_path).and_return('/ai/predictions')
    allow(view).to receive(:analytics_risks_path).and_return('/analytics/risks')
    allow(view).to receive(:organization_path).and_return('/organization')
    allow(view).to receive(:billing_organization_path).and_return('/organization/billing')
    allow(view).to receive(:audit_logs_organization_path).and_return('/organization/audit_logs')
    allow(view).to receive(:destroy_user_session_path).and_return('/users/sign_out')
  end

  it 'renders the sidebar header with correct title and subtitle' do
    render

    expect(rendered).to include('class="sidebar-header"')
    expect(rendered).to include('class="sidebar-logo"')
    expect(rendered).to include('class="sidebar-title"')
    expect(rendered).to include('DataFlow Pro')
    expect(rendered).to include('class="sidebar-subtitle"')
    expect(rendered).to include('Data Refinery Platform')
  end

  it 'renders the sidebar toggle button with proper accessibility' do
    render

    expect(rendered).to include('class="sidebar-toggle"')
    expect(rendered).to include('aria-label="Toggle navigation"')
    expect(rendered).to include('aria-hidden="true"')
  end

  it 'includes all navigation sections' do
    render

    expect(rendered).to include('Overview')
    expect(rendered).to include('Data Management')
    expect(rendered).to include('AI & Intelligence')
    expect(rendered).to include('Features')
    expect(rendered).to include('Management')
  end

  it 'renders user profile section' do
    render

    expect(rendered).to include('nav-user-profile')
    expect(rendered).to include('user-profile-card')
    expect(rendered).to include(user.full_name)
    expect(rendered).to include(user.email)
  end

  it 'includes proper data controller attributes' do
    render

    expect(rendered).to include('id="unified-sidebar"')
    expect(rendered).to include('data-controller="dataflow-navigation"')
    expect(rendered).to include('data-dataflow-navigation-target="sidebar"')
  end
end
