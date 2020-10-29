module V1
  class WebhookController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :valid_params, only: :handler
    COMPLETION_TYPES = %w[start move discard harvest generate split].freeze

    def handler
      IntegrationService.call(completion_params)

      render json: {}, status: :no_content
    end

    def test_mailer
      TaskRunner.simulate_failure
    end

    private

    def valid_params
      return render json: {}, status: :bad_request unless params[:data]
      return render json: {}, status: :bad_request if params[:data][:type] != 'completions'
      return render json: {}, status: :not_found unless COMPLETION_TYPES.include? params[:data][:attributes][:action_type]
    end

    def completion_params
      params.require(:data).permit!
    end
  end
end
