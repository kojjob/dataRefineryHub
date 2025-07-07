# Base controller for DataFlow Pro design system
class DataflowProController < ApplicationController
  layout 'dataflow_pro'
  
  before_action :set_dataflow_navigation
  
  private
  
  def set_dataflow_navigation
    @dataflow_sections = [
      { id: 'dashboard', icon: '📊', text: 'Dashboard', path: dashboard_path },
      { id: 'predictive', icon: '🔮', text: 'Predictive Analytics', path: analytics_path },
      { id: 'builder', icon: '🛠️', text: 'Analytics Builder', path: analytics_dashboard_path },
      { id: 'etl', icon: '🔄', text: 'ETL Pipelines', path: pipeline_dashboard_index_path },
      { id: 'templates', icon: '📋', text: 'Industry Templates', path: '#' },
      { id: 'marketplace', icon: '🛍️', text: 'Integration Marketplace', path: data_sources_path },
      { id: 'collaboration', icon: '👥', text: 'Team Collaboration', path: '#' },
      { id: 'mobile', icon: '📱', text: 'Mobile Dashboard', path: '#' },
      { id: 'partner', icon: '🏢', text: 'Partner Portal', path: organization_path },
      { id: 'costs', icon: '💰', text: 'Cost Optimization', path: billing_organization_path },
      { id: 'security', icon: '🔒', text: 'Security & Compliance', path: audit_logs_organization_path }
    ]
    
    # Set active section based on controller
    @active_section = case controller_name
    when 'dashboard'
      'dashboard'
    when 'analytics'
      'predictive'
    when 'pipeline_dashboard', 'pipeline_monitoring'
      'etl'
    when 'data_sources'
      'marketplace'
    when 'organizations'
      case action_name
      when 'billing'
        'costs'
      when 'audit_logs'
        'security'
      else
        'partner'
      end
    else
      'dashboard'
    end
  end
end