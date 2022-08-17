Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      namespace :admin do
        resource :consolidation_center, controller: :consolidation_center, only: [] do
          get :list
          get :search
          patch :scan
          patch :update_consolidation_center_state
          patch :revert_consolidation_center_state
          get :drop_prepare
          patch :drop_confirm
          post :return_label
        end
      end
      resources :session do
        post :create
      end
    end
  end
end
