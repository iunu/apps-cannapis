require 'rails_helper'

RSpec.describe AuthorizationController, type: :controller do
  describe 'POST #authorize' do
    it 'returns bad request' do
      post 'authorize'
      expect(response).to have_http_status(:found)
    end
  end

  describe 'GET #callback' do
    it 'returns http success' do
      get :callback
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'POST #unauthorize' do
    it 'returns http success' do
      get :unauthorize
      expect(response).to have_http_status(:bad_request)
    end
  end
end
