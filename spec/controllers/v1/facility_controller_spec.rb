require 'rails_helper'

RSpec.describe V1::FacilityController, type: :controller do
  describe 'POST #update' do
    it 'redirects to home' do
      post :update, params: { id: 1 }
      expect(response).to redirect_to(root_path)
    end
  end
end
