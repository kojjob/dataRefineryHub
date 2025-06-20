Rails.application.routes.draw do
  devise_for :users, controllers: {
    registrations: 'users/registrations'
  }
  
  root "landing#index"
  
  # Dashboard
  get "dashboard", to: "dashboard#index"
  
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
  
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
