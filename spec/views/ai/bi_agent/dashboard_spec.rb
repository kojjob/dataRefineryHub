# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ai/bi_agent/dashboard', type: :view do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }

  before do
    # Create a mock organization with data sources
    mock_data_sources = double('data_sources', count: 3)
    mock_organization = double('organization', data_sources: mock_data_sources)

    # Stub the helper methods
    view.extend(Module.new do
      define_method(:current_user) { user }
      define_method(:user_signed_in?) { true }
      define_method(:current_organization) { mock_organization }
    end)

    # Mock the instance variables that the controller sets
    assign(:agent_status, {
      status: 'active',
      insights_count: 5,
      uptime: '24h',
      last_updated: Time.current
    })
    assign(:recent_insights, [
      {
        id: '1',
        title: 'Revenue Growth Opportunity',
        description: 'Product category X shows growth potential',
        priority: 'high',
        created_at: Time.current
      }
    ])
    assign(:weekly_reports, [
      {
        id: '1',
        title: 'Weekly Intelligence Report',
        summary: 'Key findings from this week',
        created_at: Time.current
      }
    ])
  end

  it 'uses DataFlow Pro design system classes' do
    render

    # Check for DataFlow Pro layout structure
    expect(rendered).to include('class="dashboard-content"')
    expect(rendered).to include('class="metrics-grid"')
    expect(rendered).to include('class="metric-card"')
    expect(rendered).to include('content-card insights-section')
    expect(rendered).to include('content-card reports-section')
  end

  it 'renders BI Agent header with proper styling' do
    render

    expect(rendered).to include('class="bi-agent-header"')
    expect(rendered).to include('class="bi-agent-header-content"')
    expect(rendered).to include('class="bi-agent-title-section"')
    expect(rendered).to include('class="bi-agent-icon"')
    expect(rendered).to include('class="bi-agent-controls"')
  end

  it 'renders agent status card with DataFlow Pro styling' do
    render

    expect(rendered).to include('metric-card agent-status-card')
    expect(rendered).to include('agent-status-content')
    expect(rendered).to include('status-icon status-icon--active')
    expect(rendered).to include('status-pulse')
  end

  it 'renders metrics grid with consistent styling' do
    render

    expect(rendered).to include('class="metrics-grid"')
    expect(rendered).to include('Insights Generated')
    expect(rendered).to include('Agent Uptime')
    expect(rendered).to include('Weekly Reports')
    expect(rendered).to include('Data Sources')
  end

  it 'renders insights section with proper structure' do
    render

    expect(rendered).to include('content-card insights-section')
    expect(rendered).to include('content-card-header')
    expect(rendered).to include('content-card-body')
    expect(rendered).to include('insights-grid')
    expect(rendered).to include('insight-card')
    expect(rendered).to include('insight-priority-badge')
  end

  it 'renders weekly reports section with proper structure' do
    render

    expect(rendered).to include('Weekly Intelligence Reports')
    expect(rendered).to include('enterprise-grid')
    expect(rendered).to include('enterprise-card')
    expect(rendered).to include('status-indicator')
    expect(rendered).to include('report-open-btn')
  end

  it 'uses consistent button styling' do
    render

    expect(rendered).to include('btn btn--danger')
    expect(rendered).to include('btn btn--sm btn--secondary')
    expect(rendered).to include('btn btn--primary')
  end

  it 'includes proper page title and subtitle' do
    render

    expect(view.content_for(:page_title)).to eq('Business Intelligence Agent')
    expect(view.content_for(:page_subtitle)).to eq('Autonomous insights and analytics powered by AI')
  end

  it 'renders agent controls based on status' do
    render

    expect(rendered).to include('id="stop-agent-btn"')
    expect(rendered).to include('Stop Agent')
  end

  context 'when agent is inactive' do
    before do
      assign(:agent_status, {
        status: 'inactive',
        insights_count: 0,
        uptime: '0h',
        last_updated: nil
      })
    end

    it 'renders start button instead of stop button' do
      render

      expect(rendered).to include('id="start-agent-btn"')
      expect(rendered).to include('Start Agent')
      expect(rendered).to include('class="status-icon status-icon--inactive"')
    end
  end

  context 'when no insights are available' do
    before do
      assign(:recent_insights, [])
    end

    it 'renders empty state for insights' do
      render

      expect(rendered).to include('empty-state insights-empty')
      expect(rendered).to include('No insights generated yet')
      expect(rendered).to include('empty-state-visual')
    end
  end

  context 'when no reports are available' do
    before do
      assign(:weekly_reports, [])
    end

    it 'renders empty state for reports' do
      render

      expect(rendered).to include('empty-state reports-empty')
      expect(rendered).to include('No reports available yet')
      expect(rendered).to include('empty-state-visual')
    end
  end

  it 'includes JavaScript for agent controls' do
    render

    expect(rendered).to include('document.addEventListener(\'turbo:load\'')
    expect(rendered).to include('start-agent-btn')
    expect(rendered).to include('stop-agent-btn')
    expect(rendered).to include('/ai/bi_agent/start_agent')
    expect(rendered).to include('/ai/bi_agent/stop_agent')
  end

  it 'follows responsive design patterns' do
    render

    # Check that the view uses responsive classes and structure
    expect(rendered).to include('metrics-grid')
    expect(rendered).to include('insights-grid')
    expect(rendered).to include('reports-grid')

    # Ensure no hardcoded Tailwind responsive classes that break consistency
    expect(rendered).not_to include('md:grid-cols-2')
    expect(rendered).not_to include('lg:grid-cols-4')
    expect(rendered).not_to include('sm:px-6')
  end

  it 'uses DataFlow Pro color scheme' do
    render

    # Should not contain Tailwind gradient classes
    expect(rendered).not_to include('bg-gradient-to-br')
    expect(rendered).not_to include('from-slate-50')
    expect(rendered).not_to include('backdrop-blur-xl')
    
    # Should use DataFlow Pro classes instead
    expect(rendered).to include('class="dashboard-content"')
    expect(rendered).to include('class="metric-card"')
  end
end
