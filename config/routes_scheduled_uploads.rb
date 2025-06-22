# Scheduled Uploads Routes
# Include this file in your main routes.rb file

Rails.application.routes.draw do
  resources :data_sources do
    resources :scheduled_uploads do
      member do
        patch :toggle_status
        post :execute_now
      end
    end

    # Logs for all scheduled uploads in a data source
    get "scheduled_uploads_logs", to: "scheduled_uploads#logs", as: :scheduled_uploads_logs
  end

  # API endpoints for scheduled uploads
  namespace :api do
    namespace :v1 do
      resources :data_sources, only: [] do
        resources :scheduled_uploads, only: [ :index, :show, :create, :update, :destroy ] do
          member do
            patch :toggle_status
            post :execute_now
          end

          resources :upload_logs, only: [ :index, :show ]
        end
      end
    end
  end
end
