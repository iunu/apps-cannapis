require 'rails_helper'

RSpec.describe V1::WebhookController, type: :controller do
  describe 'GET #handler' do
    it 'returns bad request' do
      post :handler
      expect(response).to have_http_status(:bad_request)
    end
  end
end
