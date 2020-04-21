require_relative '../common/logging'

module BaseService
  class Client
    include Common::Logging

    def initialize(integration)
      @integration = integration
    end

    def call(method, *args)
      log("[#{method.to_s.upcase}] API request. URI #{vendor_client.uri}", :debug)
      log(args.to_yaml, :debug)

      response = call_vendor(method, *args)

      JSON.parse(response.body) if response&.body&.present?
    end

    protected

    def call_vendor(method, *args)
      vendor_client.send(method, @integration.vendor_id, *args)
    end

    def vendor_client
      @vendor_client ||= build_client
    end

    def build_client
      raise 'override +build_client+ in the subclass'
    end

    def state
      config[:state_map].fetch(@integration.state.upcase.to_sym, @integration.state)
    end

    def config
      @config ||= Rails.application.config_for('providers/metrc')
    end
  end
end
