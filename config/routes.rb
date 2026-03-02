require "sidekiq/web"
require "sidekiq/cron/web"

Rails.application.routes.draw do
  # MFA routes
  resource :mfa, controller: "mfa", only: [ :new, :create ] do
    get :verify
    post :verify, to: "mfa#verify_code"
    delete :disable
  end

  mount Lookbook::Engine, at: "/design-system"

  # Uses basic auth - see config/initializers/sidekiq.rb
  mount Sidekiq::Web => "/sidekiq"


  get "changelog", to: "pages#changelog"
  get "feedback", to: "pages#feedback"
  patch "dashboard/preferences", to: "pages#update_preferences"

  resource :current_session, only: %i[update]

  resource :registration, only: %i[new create]
  resources :sessions, only: %i[index new create destroy]
  resource :password_reset, only: %i[new create edit update]
  resource :password, only: %i[edit update]
  resource :email_confirmation, only: :new

  resources :users, only: %i[update destroy] do
    delete :reset, on: :member
    delete :reset_with_sample_data, on: :member
    get :resend_confirmation_email, on: :member
  end

  resource :onboarding, only: :show do
    collection do
      get :preferences
      get :goals
    end
  end

  namespace :settings do
    resource :profile, only: [ :show, :destroy ]
    resource :preferences, only: :show
    resource :hosting, only: %i[show update] do
      delete :clear_cache, on: :collection
    end
    resource :security, only: :show
    resource :api_key, only: [ :show, :new, :create, :destroy ]
    resource :guides, only: :show
    resource :providers, only: %i[show update]
  end

  resources :tags, except: :show do
    resources :deletions, only: %i[new create], module: :tag
    delete :destroy_all, on: :collection
  end


  resources :holdings, only: %i[index new show update destroy] do
    member do
      post :unlock_cost_basis
      patch :remap_security
      post :reset_security
    end
  end
  resources :trades, only: %i[show new create update destroy] do
    member do
      post :unlock
    end
  end
  resources :valuations, only: %i[show new create update destroy] do
    post :confirm_create, on: :collection
    post :confirm_update, on: :member
  end

  resources :accountable_sparklines, only: :show, param: :accountable_type

  direct :entry do |entry, options|
    if entry.new_record?
      route_for entry.entryable_name.pluralize, options
    else
      route_for entry.entryable_name, entry, options
    end
  end


  resources :accounts, only: %i[index new show destroy], shallow: true do
    member do
      post :sync
      get :sparkline
      patch :toggle_active
    end

    collection do
      post :sync_all
    end
  end

  # Convenience routes for polymorphic paths
  # Example: account_path(Account.new(accountable: Crypto.new)) => /cryptos/123
  direct :edit_account do |model, options|
    route_for "edit_#{model.accountable_name}", model, options
  end

  resources :cryptos, only: %i[new create edit update]

  resources :securities, only: :index

  # API routes
  namespace :api do
    namespace :v1 do
      # Production API endpoints
      resources :accounts, only: [ :index, :show ]
      resources :tags, only: %i[index show create update destroy]

      resources :trades, only: [ :index, :show, :create, :update, :destroy ]
      resources :holdings, only: [ :index, :show ]
      resources :valuations, only: [ :create, :update, :show ]
      resource :usage, only: [ :show ], controller: :usage
      post :sync, to: "sync#create"


      delete "users/reset", to: "users#reset"
      delete "users/me", to: "users#destroy"

      # Test routes for API controller testing (only available in test environment)
      if Rails.env.test?
        get "test", to: "test#index"
        get "test_not_found", to: "test#not_found"
        get "test_family_access", to: "test#family_access"
        get "test_scope_required", to: "test#scope_required"
        get "test_multiple_scopes_required", to: "test#multiple_scopes_required"
      end
    end
  end



  resources :currencies, only: %i[show]


  get "redis-configuration-error", to: "pages#redis_configuration_error"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  privacy_url = ENV["LEGAL_PRIVACY_URL"].presence
  terms_url = ENV["LEGAL_TERMS_URL"].presence
  get "privacy", to: privacy_url ? redirect(privacy_url) : "pages#privacy"
  get "terms", to: terms_url ? redirect(terms_url) : "pages#terms"
  get "intro", to: "pages#intro"

  # Admin namespace for super admin functionality
  namespace :admin do
    resources :users, only: [ :index, :update ]
  end

  # Defines the root path route ("/")
  root "pages#dashboard"
end
