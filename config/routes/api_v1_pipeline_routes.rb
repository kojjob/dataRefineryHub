# API V1 Pipeline and Task Routes
# This file contains all pipeline and task-related API routes

Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      # Pipeline executions API
      resources :pipelines, only: [ :index, :show, :create ] do
        member do
          post :pause
          post :resume
          post :cancel
          post :retry
          get :tasks
          get :logs
        end

        collection do
          get :statistics
        end
      end

      # Tasks API
      resources :tasks, only: [ :index, :show ] do
        member do
          post :execute
          post :approve
          post :reject
          post :assign
          post :unassign
          post :cancel
          post :retry
        end

        collection do
          get :manual_queue
          get :statistics
        end
      end

      # Task templates API
      resources :task_templates do
        member do
          post :duplicate
          post :create_task
        end

        collection do
          get :library
          post :import_from_library
        end
      end

      # Scheduled tasks API
      resources :scheduled_tasks do
        member do
          post :pause
          post :resume
          post :execute_now
          get :runs
        end

        collection do
          get :upcoming
          get :statistics
        end
      end
    end
  end
end
