module V1
  class WebhookController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :valid_params, only: :handler
    # FIXME: Use the correct bits to whitelist payloads
    SUPPORTED_ACTIONS = %w[start move discard].freeze

    def handler
      Cannapi::IntegrationService.call(params)

      render json: {}, status: :no_content
    end

    private

    def valid_params
      return render json: {}, status: :bad_request if !params[:data] || (params[:data][:type] != 'actions' && params[:meta][:event_type] != 'creation')
      return render json: {}, status: :not_found unless SUPPORTED_ACTIONS.include? params[:data][:attributes][:action_type]
    end
  end
end
