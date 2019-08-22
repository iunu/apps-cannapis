require 'rails_helper'

RSpec.describe HomeController, type: :controller do
  describe.skip 'GET #index' do
    it 'returns http success' do
      # assigns(:current_account)

      # render template: 'home/index.html.erb'

      get :index
      expect(response).to render_template(:index)
    end
  end
end
