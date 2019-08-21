Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  root to: 'home#index'

  post 'authorize'      => 'authorization#authorize'
  get  'oauth/callback' => 'authorization#callback'
  post 'unauthorize'    => 'authorization#unauthorize'
end
