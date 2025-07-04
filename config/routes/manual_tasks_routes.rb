# Manual Tasks Routes
# Routes for managing and executing manual tasks in the pipeline

Rails.application.routes.draw do
  resources :manual_tasks, only: [:index, :show] do
    member do
      get :execute
      post :execute
      get :approve
      post :approve
      get :reject
      post :reject
      post :assign
      post :unassign
      post :cancel
      post :retry
    end
    
    collection do
      post :auto_assign
      post :clear_stale
    end
  end
  
  # Convenience route for manual task queue
  get 'tasks/manual', to: 'manual_tasks#index', as: :manual_task_queue
end