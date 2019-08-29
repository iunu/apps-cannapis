require 'rails_helper'

RSpec.describe V1::FacilityController, type: :controller do
  describe "PUT #update" do
    it "returns http success" do
      put :update
      expect(response).to have_http_status(:success)
    end
  end

end
