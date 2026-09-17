Rails.application.routes.draw do
  get  "/healthz", to: "health#show"
  get  "/readyz",  to: "health#ready"

  resources :invoices, only: [:index, :show, :create]

  root "invoices#index"
end
