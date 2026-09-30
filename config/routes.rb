Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "intake/controllers/imports#new"
  get "catalog/export", to: "intake/controllers/catalog_exports#show", as: :catalog_export
  get "catalog/export/download", to: "intake/controllers/catalog_exports#download", as: :catalog_export_download
  resource :import, only: %i[new create], controller: "intake/controllers/imports"
  resources :batches, only: %i[index show], controller: "intake/controllers/batches"
  resources :review_cases, only: %i[index show], controller: "intake/controllers/review_cases" do
    member do
      post :approve
      post :reject
      post :correct
      post :create_product
      post :reassign_candidate
      post :create_for_reassignment
      post :keep_existing
      post :replace_existing
    end
  end
end
