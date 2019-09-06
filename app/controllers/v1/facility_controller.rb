module V1
  class FacilityController < ApplicationController
    before_action :validate, only: :update

    def update
      integration = Integration.find_or_create_by(account_id: session[:current_account_id], facility_id: params[:id])
      integration.update(vendor: params.dig(:facility, :vendor),
                         vendor_id: params.dig(:facility, :license_number),
                         key: params.dig(:facility, :api_key),
                         secret: params.dig(:facility, :api_secret),
                         state: params.dig(:facility, :state)&.downcase)

      redirect_to root_path
    end

    private

    def validate
      redirect_to root_path unless params[:facility] && session[:current_account_id]
    end
  end
end
