# frozen_string_literal: true

# Data Quality Monitoring Routes
# This file contains all routes related to data quality monitoring functionality

Rails.application.routes.draw do
  # Data Quality Monitoring Routes
  scope '/data-quality' do
    # Main data quality dashboard
    get '/', to: 'data_quality#index', as: :data_quality_index
    
    # Real-time metrics API endpoint
    get '/metrics', to: 'data_quality#metrics_api', as: :metrics_api_data_quality_index
    
    # Data source specific quality routes
    scope '/sources/:data_source_id' do
      # Individual data source quality details
      get '/', to: 'data_quality#show', as: :data_quality
      
      # Trigger data quality validation
      post '/validate', to: 'data_quality#validate', as: :validate_data_quality
      
      # Quality reports
      get '/reports/:report_id', to: 'data_quality#report', as: :report_data_quality
      
      # Export quality report as PDF
      get '/reports/:report_id/export', to: 'data_quality#report', defaults: { format: 'pdf' }, as: :export_data_quality_report
    end
  end
  
  # Note: data_sources routes are defined in main routes.rb
  # Quality routes for data sources are added there to avoid conflicts
  
  # API routes for data quality
  namespace :api do
    namespace :v1 do
      resources :data_quality, only: [:index, :show] do
        collection do
          get :metrics
          get :trends
          get :alerts
        end
        
        member do
          post :validate
          get :history
          get :recommendations
        end
      end
      
      # Real-time data quality endpoints
      scope '/data-quality' do
        get '/real-time/:data_source_id', to: 'data_quality#real_time_metrics'
        post '/webhook/:data_source_id', to: 'data_quality#webhook_validation'
      end
    end
  end
end