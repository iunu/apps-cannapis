module MetrcService
  class Client < BaseService::Client
    def get_item_categories
      response = vendor_client.get('items', 'categories')
      parse_response(response).map { |entry| entry['Name'] }
    end

    def get_supported_waste_types
      response = vendor_client.get('harvests', 'waste/types')
      parse_response(response).map { |entry| entry['Name']  }
    end

    protected

    def build_client
      debug = !ENV['DEMO'].nil? || Rails.env.development? || Rails.env.test?
      secret_key = ENV["METRC_SECRET_#{@integration.state.upcase}"]

      throw "No Metrc key is available for #{@integration.state.upcase}" unless secret_key

      Metrc.configure do |config|
        config.api_key  = secret_key
        config.state    = state
        config.sandbox  = debug
      end

      Metrc::Client.new(user_key: @integration.secret, debug: debug)
    end
  end
end
