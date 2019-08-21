require 'rails_helper'

RSpec.describe Authorization, type: :controller do
  describe 'POST #authorize' do
    it 'returns bad request' do
      post 'authorize'
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'GET #callback' do
    it 'returns http success' do
      get 'oauth/callback'
      expect(response).to have_http_status(:success)
    end
  end

  describe 'POST #callback' do
    it 'returns http success' do
      get :unauthorize
      expect(response).to have_http_status(:success)
    end
  end
end
