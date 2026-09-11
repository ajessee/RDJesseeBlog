Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  
  get 'password_resets/new'

  get 'password_resets/edit'

  root 'welcome#welcome'

  get 'login' => 'sessions#new'
  post 'login' => 'sessions#create'
  delete 'logout' => 'sessions#destroy'

  get 'welcome' => 'welcome#welcome'
  get 'about' => 'welcome#about'
  get 'signup' => 'users#new'
  get 'blog' => 'stories#index'
  get 'tag_cloud' => 'tags#show'

  post 'email_responses/bounce' => 'email_responses#bounce'
  post 'email_responses/complaint' => 'email_responses#complaint'

  get '/admin',   to: 'admin_pages#main'
  get '/admin/users',   to: 'admin_pages#admin_users'
  get '/admin/stories',   to: 'admin_pages#admin_stories'

  get 'stories/sort' => 'stories#sort'
  get 'stories/search' => 'stories#search'

  resources :users do
    resources :stories
    resources :comments
    resources :pictures
    resources :videos
    resources :recordings
  end

  resources :stories do
    resources :comments
    resources :pictures
    resources :videos
    resources :recordings
  end

  resources :comments do
    resources :comments
  end

  resources :pictures do
    resources :comments
  end

  resources :videos do
    resources :comments
  end

  resources :recordings do
    post :retry_conversion, on: :member
    resources :comments
  end
  
  resources :account_activations, only: [:edit]
  resources :password_resets,     only: [:new, :create, :edit, :update]
  resources :tags
end
