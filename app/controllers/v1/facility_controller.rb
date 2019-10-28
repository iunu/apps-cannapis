module V1
  class FacilityController < ApplicationController
    before_action :validate, only: :update

    def update
      integration = Integration.find_or_create_by(account_id: session[:current_account_id], facility_id: params[:id])
      p integration.inspect
      integration.update(vendor: params.dig(:facility, :vendor),
                         vendor_id: params.dig(:facility, :license_number),
                         key: params.dig(:facility, :api_key),
                         secret: params.dig(:facility, :api_secret),
                         state: params.dig(:facility, :state)&.downcase,
                         eod: "#{params.dig(:facility, :eod)}:00")

      integration.save
      p integration.inspect
      # Subscribe the facility to the integration webhook
      SubscriptionJob.perform_later(request.base_url, integration)

      redirect_to root_path
    end

    private

    def validate
      redirect_to root_path unless params[:facility] && session[:current_account_id]
    end
  end
end
