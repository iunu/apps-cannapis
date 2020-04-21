Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  root to: 'home#index'

  get 'authorize'      => 'authorization#authorize'
  get 'oauth/callback' => 'authorization#callback'
  get 'logout'         => 'authorization#logout'

  namespace :v1 do
    post 'webhook'      => 'webhook#handler'
    post 'facility/:id' => 'facility#update'
    post 'test_mailer'  => 'webhook#test_mailer'
  end
end
