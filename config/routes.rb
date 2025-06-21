Rails.application.routes.draw do
  devise_for :users, controllers: {
    registrations: 'users/registrations'
  }
  
  root "landing#index"
  
  # Dashboard
  get "dashboard", to: "dashboard#index"
  
  # Analytics
  get "analytics", to: "analytics#index"
  
  # Organization management
  resource :organization, only: [:show, :edit, :update] do
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
    end
  end
  
  # Data sources
  resources :data_sources do
    member do
      post :test_connection
      post :sync_now
    end
  end
  
  # API Routes
  namespace :api do
    namespace :v1 do
      # Authentication endpoints
      post 'auth/login', to: 'authentication#login'
      delete 'auth/logout', to: 'authentication#logout'
      post 'auth/refresh', to: 'authentication#refresh'
      get 'auth/me', to: 'authentication#me'
      
      # Organization endpoints
      resource :organization, only: [:show, :update] do
        get :usage_stats
        get :audit_logs
        get :billing_info
      end
      
      # Data Sources API
      resources :data_sources, except: [:new, :edit] do
        member do
          post :test_connection
          post :sync_now
          get :sync_status
          get :sync_history
          get :metrics
        end
        
        # Nested resources for data source configuration
        resources :extraction_jobs, only: [:index, :show, :create, :destroy] do
          member do
            post :retry
            post :cancel
          end
        end
      end
      
      # Extraction Jobs API
      resources :extraction_jobs, only: [:index, :show] do
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
        get 'export_status/:job_id', action: :export_status
        get 'download_export/:job_id', action: :download_export
      end
      
      # Raw Data Access API
      resources :customers, only: [:index, :show] do
        collection do
          get :search
          get :segments
        end
      end
      
      resources :orders, only: [:index, :show] do
        collection do
          get :search
          get :by_status
          get :by_date_range
        end
      end
      
      resources :products, only: [:index, :show] do
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
