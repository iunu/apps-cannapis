module V1
  class FacilityController < ApplicationController
    def update
      account_id = session[:current_account_id]
      redirect_to root_path unless account_id

      integration           = Integration.find_or_create_by(account_id: account_id, facility_id: params[:id])
      integration.vendor    = params[:facility][:vendor]
      integration.vendor_id = params[:facility][:license_number]
      integration.key       = params[:facility][:api_key]
      integration.secret    = params[:facility][:api_secret]
      integration.state     = params[:facility][:state]&.downcase
      integration.save

      redirect_to root_path
    end
  end
end
