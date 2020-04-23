module V1
  class FacilityController < ApplicationController
    before_action :validate, only: :update

    def update
      integration = Integration.find_or_create_by(account_id: session[:current_account_id], facility_id: params[:id])
      timezone = ActiveSupport::TimeZone.new(params.dig(:facility, :timezone))&.formatted_offset || '+00:00'
      integration.update(vendor: params.dig(:facility, :vendor)&.downcase,
                         license: params.dig(:facility, :license_number),
                         secret: params.dig(:facility, :api_secret),
                         state: params.dig(:facility, :state)&.downcase,
                         eod: "#{params.dig(:facility, :eod)}:00",
                         timezone: timezone)

      # Subscribe the facility to the integration webhook
      SubscriptionJob.perform_later(request.base_url, integration)

      redirect_to root_path
    end

    private

    def validate
      redirect_to root_path unless params[:facility] && session[:current_account_id] && params.dig(:facility, :state)
    end
  end
end
