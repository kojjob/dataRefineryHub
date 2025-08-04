# Base controller for DataFlow Pro design system
class DataflowProController < ApplicationController
  layout 'dataflow_pro'
  
  before_action :set_dataflow_navigation
  
  private
  
  def set_dataflow_navigation
    @dataflow_sections = [
      { id: 'dashboard', icon: '📊', text: 'Dashboard', path: '/dashboard' },
      { id: 'analytics', icon: '📈', text: 'Analytics Dashboard', path: '/analytics' },
      { id: 'revenue', icon: '💰', text: 'Revenue Analytics', path: '/analytics/revenue' },
      { id: 'customers', icon: '👥', text: 'Customer Analytics', path: '/analytics/customers' },
      { id: 'products', icon: '📦', text: 'Product Analytics', path: '/analytics/products' },
      { id: 'risks', icon: '⚠️', text: 'Risk Analysis', path: '/analytics/risks' },
      { id: 'bi_agent', icon: '🤖', text: 'BI Agent', path: '/ai/bi_agent/dashboard' },
      { id: 'ai_chat', icon: '💬', text: 'AI Chat', path: '/ai/chat/history' },
      { id: 'predictive', icon: '🔮', text: 'Predictive Analytics', path: '/ai/predictions' },
      { id: 'etl', icon: '🔄', text: 'ETL Pipelines', path: '/pipeline_dashboard' },
      { id: 'templates', icon: '📋', text: 'Industry Templates', path: '/industry_templates' },
      { id: 'marketplace', icon: '🛍️', text: 'Integration Marketplace', path: '/data_sources' },
      { id: 'collaboration', icon: '🤝', text: 'Team Collaboration', path: '#' },
      { id: 'mobile', icon: '📱', text: 'Mobile Dashboard', path: '#' },
      { id: 'partner', icon: '🏢', text: 'Partner Portal', path: '/organization' },
      { id: 'costs', icon: '💸', text: 'Cost Optimization', path: '/organization/billing' },
      { id: 'security', icon: '🔒', text: 'Security & Compliance', path: '/organization/audit_logs' }
    ]
    
    # Set active section based on controller
    @active_section = case controller_name
    when 'dashboard'
      'dashboard'
    when 'analytics'
      'analytics'
    when 'revenue'
      'revenue'
    when 'customers'
      'customers'
    when 'products'
      'products'
    when 'risks'
      'risks'
    when 'bi_agent'
      'bi_agent'
    when 'chat'
      'ai_chat'
    when 'predictions'
      'predictive'
    when 'pipeline_dashboard', 'pipeline_monitoring'
      'etl'
    when 'industry_templates'
      'templates'
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