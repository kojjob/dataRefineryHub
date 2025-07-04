Rails.application.routes.draw do
  resources :pipeline_dashboard, only: [:index, :show]
  devise_for :users, controllers: {
    registrations: 'users/registrations',
    sessions: 'users/sessions'
  }

  root 'landing#index'
  
  # Debug routes (remove in production)
  get 'debug/session_info', to: 'debug#session_info' unless Rails.env.production?

  # Dashboard routes
  get 'dashboard', to: 'dashboard#index'
  get 'dashboard/analytics', to: 'dashboard#analytics'
  get 'dashboard/reports', to: 'dashboard#reports'
  
  # Include data quality monitoring routes
  load Rails.root.join('config', 'routes', 'data_quality_routes.rb')
  
  # Include manual tasks routes
  load Rails.root.join('config', 'routes', 'manual_tasks_routes.rb')
  
  # Include API pipeline routes
  load Rails.root.join('config', 'routes', 'api_v1_pipeline_routes.rb')

  # Analytics
  get "analytics", to: "analytics#index"
  
  # AI-powered features
  namespace :ai do
    resources :presentations do
      member do
        get :download
        get :status
      end
      collection do
        post :generate
        get :preview
      end
    end
    
    resources :queries, only: [:index] do
      collection do
        post :process_query
        get :suggestions
        post :validate
        get :examples
        post :export
      end
    end
    
    resources :real_time_analytics, only: [] do
      collection do
        get :dashboard
        get :live_data
        get :anomalies
        get :alerts
        get :insights
        get :predictions
        get :performance_metrics
        post :start_monitoring
        post :stop_monitoring
        post :configure_alerts
        post :dismiss_alert
        post :snooze_alert
        get :export_analytics
        get :health_check
      end
    end
    
    resources :bi_agent, only: [] do
      collection do
        get :dashboard
        post :start_agent
        post :stop_agent
        post :generate_insights
        post :weekly_report
        post :customer_analysis
        post :competitive_analysis
        post :scenario_planning
        get :agent_status
        post :configure_agent
        get :learning_status
        post :feedback
        get :export_insights
      end
    end
    
    resources :data_integration, only: [] do
      collection do
        get :dashboard
        get :dashboard_stats
        post :analyze_source
        post :generate_field_mapping
        post :optimize_data_source
        post :suggest_new_sources
        post :validate_integration_quality
        post :preview_integration
        get :integration_recommendations
        get :export_integration_plan
        post :optimize_all
        post :validate_quality
      end
    end
    
    resources :interactive_presentations, only: [] do
      collection do
        get :dashboard
        get :dashboard_stats
        post :create_presentation
        post :create_interactive
        post :create_live_dashboard
        post :create_data_story
        post :generate_content
        post :analyze_data
        post :suggest_visualizations
        get :presentation_templates
        get :export_presentation
        post :save_presentation
        post :share_presentation
        get :presentation_analytics
        post :duplicate_presentation
        delete :delete_presentation
      end
      
      member do
        get :show
        get :edit
        patch :update
        get :preview
        post :publish
        post :unpublish
        get :analytics
        post :clone
      end
    end
  end

  # Organization management
  resource :organization, only: [ :show, :edit, :update ] do
    member do
      get :billing
      get :usage_stats
      get :audit_logs
    end
  end

  # User management - constrain ID to numeric to avoid conflicts with Devise routes
  resources :users, constraints: { id: /\d+/ } do
    member do
      patch :change_role
      delete :remove_avatar
    end
  end

  # Data sources
  resources :data_sources do
    collection do
      post :test_connection
      post :auto_save
      get :quality  # Add quality dashboard as collection route
      post :run_quality_check  # Add quality check endpoint
      get :download_sample_csv
      get :download_sample_excel
      get :download_sample_json
    end

    member do
      post :sync_now
      post :process_files
      get "preview_file/:file_id", action: :preview_file, as: :preview_file
      get "analyze_file/:file_id", action: :analyze_file, as: :analyze_file
      get "enhanced_preview/:file_id", action: :enhanced_preview, as: :enhanced_preview
      # Data quality routes
      get :quality, to: 'data_quality#show'
      post :validate_quality, to: 'data_quality#validate'
      get 'quality/reports/:report_id', to: 'data_quality#report', as: :quality_report
    end

    # Scheduled uploads
    resources :scheduled_uploads do
      member do
        patch :toggle_status
        post :execute_now
      end
    end

    # Logs for all scheduled uploads in a data source
    get "scheduled_uploads_logs", to: "scheduled_uploads#logs", as: :scheduled_uploads_logs
  end

  # API Routes
  namespace :api do
    namespace :v1 do
      # Authentication endpoints
      post "auth/login", to: "authentication#login"
      delete "auth/logout", to: "authentication#logout"
      post "auth/refresh", to: "authentication#refresh"
      get "auth/me", to: "authentication#me"

      # Organization endpoints
      resource :organization, only: [ :show, :update ] do
        get :usage_stats
        get :audit_logs
        get :billing_info
      end

      # Data Sources API
      resources :data_sources, except: [ :new, :edit ] do
        member do
          post :test_connection
          post :sync_now
          get :sync_status
          get :sync_history
          get :metrics
        end

        # Nested resources for data source configuration
        resources :extraction_jobs, only: [ :index, :show, :create, :destroy ] do
          member do
            post :retry
            post :cancel
          end
        end

        # Scheduled uploads API
        resources :scheduled_uploads, only: [ :index, :show, :create, :update, :destroy ] do
          member do
            patch :toggle_status
            post :execute_now
          end

          resources :upload_logs, only: [ :index, :show ]
        end
      end

      # Extraction Jobs API
      resources :extraction_jobs, only: [ :index, :show ] do
        member do
          post :retry
          post :cancel
          get :logs
        end
      end

      # Analytics and Reporting API
      namespace :analytics do
        get :dashboard_stats
        get :revenue_metrics
        get :customer_metrics
        get :product_metrics
        get :order_metrics
        get :trend_analysis

        # Time-series data endpoints
        get :revenue_over_time
        get :orders_over_time
        get :customers_over_time

        # Export endpoints
        post :export_report
        get "export_status/:job_id", action: :export_status
        get "download_export/:job_id", action: :download_export
      end

      # Visualizations API
      resources :visualizations, only: [ :index, :show, :create, :destroy ]

      # Notifications API
      resources :notifications do
        collection do
          get 'unread_count'
          patch 'mark_all_as_read'
        end
        member do
          patch 'mark_as_read'
          patch 'mark_as_unread'
        end
      end

      # Raw Data Access API
      resources :customers, only: [ :index, :show ] do
        collection do
          get :search
          get :segments
        end
      end

      resources :orders, only: [ :index, :show ] do
        collection do
          get :search
          get :by_status
          get :by_date_range
        end
      end

      resources :products, only: [ :index, :show ] do
        collection do
          get :search
          get :by_category
          get :low_stock
        end
      end

      # Real-time data endpoints
      namespace :realtime do
        get :metrics_stream
        get :job_status_stream
        get :notifications_stream
      end

      # Webhook endpoints for external integrations
      namespace :webhooks do
        post :shopify
        post :woocommerce
        post :stripe
        post :mailchimp
      end
    end
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
