# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

# static routes must be declared first
match '/custom_tables/permissions/workflows', :to => 'table_permissions#index', :via => :get
match '/custom_tables/permissions', :to => 'table_permissions#permissions', :via => [:get, :post]
match '/custom_tables/permissions/copy', :to => 'table_permissions#copy', :via => [:get, :post]

resources :custom_tables
resources :custom_tables do
  collection do
    get :context_menu
    get '/:id/csv/example', to: 'custom_tables#csv_example', as: :csv_example, defaults: { format: 'csv' }
  end
end

resources :table_fields
resources :custom_entities do
  collection do
    get :bulk_edit
    post :bulk_update
    post :context_export
    get :context_menu
    delete :index, action: :destroy
    post :upload
  end
  member do
    get :add_belongs_to
    get :new_note
  end
end

resources :journals, only: [] do
  member do
    get 'edit_note'
  end
end
