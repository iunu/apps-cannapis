module NcsService
  class Client < BaseService::Client
    protected

    def parse_response(response)
      response
    end

    def build_client
      debug = !ENV['DEMO'].nil? || Rails.env.development? || Rails.env.test?

      throw "No NCS Analytics API key is available for #{@integration.id}" unless @integration.secret

      NcsAnalytics.configure do |config|
        config.debug = debug
        config.uri   = ENV['NCS_BASE_URI']
        config.api_key = @integration.secret
      end

      NcsAnalytics::Client.new
    end

    def call_vendor(resource, method, *args)
      vendor_client.send(resource).send(method, *args)
    end
  end
end
