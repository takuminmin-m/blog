Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "static_pages#index"

  get "about", to: "static_pages#about"

  resources :articles, only: [ :index, :show ], param: :filename
  resources :article_tags, only: [ :index, :show ], param: :name
  # An artwork's name is its filename without the extension, and it may hold dots.
  resources :artworks, only: [ :index, :show ], path: "gallery", param: :name, constraints: { name: %r{[^/]+} }, format: false

  # Only the Active Storage routes that serve variants, copied from activestorage's
  # config/routes.rb (config.active_storage.draw_routes is off). The rest would serve a picture's
  # original, which has no watermark and keeps all its EXIF (GPS position included), to anyone
  # with the signed blob ID in a variant URL, or store anyone's uploads.
  scope ActiveStorage.routes_prefix do
    get "/representations/redirect/:signed_blob_id/:variation_key/*filename" => "active_storage/representations/redirect#show", as: :rails_blob_representation
    get "/representations/proxy/:signed_blob_id/:variation_key/*filename" => "active_storage/representations/proxy#show", as: :rails_blob_representation_proxy
    get "/disk/:encoded_key/*filename" => "active_storage/disk#show", as: :rails_disk_service
  end

  # url_for(variant), as activestorage's routes resolve it but for variants only and without URL
  # expiry: by redirect, or by proxy if config.active_storage.resolve_model_to_route says so.
  resolve("ActiveStorage::VariantWithRecord") { |variant, options| route_for(ActiveStorage.resolve_model_to_route, variant, options) }

  direct :rails_storage_redirect do |variant, options|
    route_for(:rails_blob_representation, variant.blob.signed_id, variant.variation.key, variant.blob.filename, options)
  end

  direct :rails_storage_proxy do |variant, options|
    route_for(:rails_blob_representation_proxy, variant.blob.signed_id, variant.variation.key, variant.blob.filename, options)
  end
end
