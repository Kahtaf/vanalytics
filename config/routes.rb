require "sidekiq/web"
require "sidekiq/cron/web"

Rails.application.routes.draw do
  use_doorkeeper
  # MFA routes
  resource :mfa, controller: "mfa", only: [ :new, :create ] do
    get :verify
    post :verify, to: "mfa#verify_code"
    delete :disable
  end

  mount Lookbook::Engine, at: "/design-system"

  # Uses basic auth - see config/initializers/sidekiq.rb
  mount Sidekiq::Web => "/sidekiq"


  resources :family_exports, only: %i[new create index destroy] do
    member do
      get :download
    end
  end

  get "changelog", to: "pages#changelog"
  get "feedback", to: "pages#feedback"
  patch "dashboard/preferences", to: "pages#update_preferences"

  resource :current_session, only: %i[update]

  resource :registration, only: %i[new create]
  resources :sessions, only: %i[index new create destroy]
  get "/auth/mobile/:provider", to: "sessions#mobile_sso_start"
  match "/auth/:provider/callback", to: "sessions#openid_connect", via: %i[get post]
  match "/auth/failure", to: "sessions#failure", via: %i[get post]
  get "/auth/logout/callback", to: "sessions#post_logout"
  resource :oidc_account, only: [] do
    get :link, on: :collection
    post :create_link, on: :collection
    get :new_user, on: :collection
    post :create_user, on: :collection
  end
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
      get :trial
    end
  end

  namespace :settings do
    resource :profile, only: [ :show, :destroy ]
    resource :preferences, only: :show
    resource :hosting, only: %i[show update] do
      delete :clear_cache, on: :collection
    end
    resource :payment, only: :show
    resource :security, only: :show
    resources :sso_identities, only: :destroy
    resource :api_key, only: [ :show, :new, :create, :destroy ]
    resource :guides, only: :show
    resource :bank_sync, only: :show, controller: "bank_sync"
    resource :providers, only: %i[show update]
  end

  resource :subscription, only: %i[new show create] do
    collection do
      get :upgrade
      get :success
    end
  end

  resources :tags, except: :show do
    resources :deletions, only: %i[new create], module: :tag
    delete :destroy_all, on: :collection
  end


  resources :reports, only: %i[index] do
    patch :update_preferences, on: :collection
    get :export_transactions, on: :collection
    get :google_sheets_instructions, on: :collection
    get :print, on: :collection
  end


  resources :transfers, only: %i[new create destroy show update]

  resources :imports, only: %i[index new show create update destroy] do
    member do
      post :publish
      put :revert
      put :apply_template
    end

    resource :upload, only: %i[show update], module: :import
    resource :configuration, only: %i[show update], module: :import
    resource :clean, only: :show, module: :import
    resource :confirm, only: :show, module: :import

    resources :rows, only: %i[show update], module: :import
    resources :mappings, only: :update, module: :import
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

  namespace :transactions do
    resource :bulk_deletion, only: :create
    resource :bulk_update, only: %i[new create]
  end

  resources :transactions, only: %i[index new create show update destroy] do
    resource :transfer_match, only: %i[new create]

    collection do
      delete :clear_filter
      patch :update_preferences
    end

    member do
      get :convert_to_trade
      post :create_trade_from_transaction
      post :merge_duplicate
      post :dismiss_duplicate
      post :unlock
    end
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
      get :select_provider
      get :confirm_unlink
      delete :unlink
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

  resources :invite_codes, only: %i[index create destroy]

  resources :invitations, only: [ :new, :create, :destroy ] do
    get :accept, on: :member
  end

  # API routes
  namespace :api do
    namespace :v1 do
      # Authentication endpoints
      post "auth/signup", to: "auth#signup"
      post "auth/login", to: "auth#login"
      post "auth/refresh", to: "auth#refresh"
      post "auth/sso_exchange", to: "auth#sso_exchange"

      # Production API endpoints
      resources :accounts, only: [ :index, :show ]
      resources :tags, only: %i[index show create update destroy]

      resources :transactions, only: [ :index, :show, :create, :update, :destroy ]
      resources :trades, only: [ :index, :show, :create, :update, :destroy ]
      resources :holdings, only: [ :index, :show ]
      resources :valuations, only: [ :create, :update, :show ]
      resources :imports, only: [ :index, :show, :create ]
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

  resources :impersonation_sessions, only: [ :create ] do
    post :join, on: :collection
    delete :leave, on: :collection

    member do
      put :approve
      put :reject
      put :complete
    end
  end


  get "redis-configuration-error", to: "pages#redis_configuration_error"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  get "imports/:import_id/upload/sample_csv", to: "import/uploads#sample_csv", as: :import_upload_sample_csv

  privacy_url = ENV["LEGAL_PRIVACY_URL"].presence
  terms_url = ENV["LEGAL_TERMS_URL"].presence
  get "privacy", to: privacy_url ? redirect(privacy_url) : "pages#privacy"
  get "terms", to: terms_url ? redirect(terms_url) : "pages#terms"
  get "intro", to: "pages#intro"

  # Admin namespace for super admin functionality
  namespace :admin do
    resources :sso_providers do
      member do
        patch :toggle
        post :test_connection
      end
    end
    resources :users, only: [ :index, :update ]
  end

  # Defines the root path route ("/")
  root "pages#dashboard"
end
