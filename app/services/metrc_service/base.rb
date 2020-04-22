require_relative '../common/base'

module MetrcService
  class Base < Common::Base
    RETRYABLE_ERRORS = [
      Net::HTTPRetriableError,
      Metrc::RequestError
    ].freeze

    private

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

    protected

    def call_metrc(method, *args)
      log("[#{method.to_s.upcase}] Metrc API request. URI #{@client.uri}", :debug)
      log(args.to_yaml, :debug)

      response = @client.send(method, @integration.license, *args)
      JSON.parse(response.body) if response&.body&.present?
    rescue *RETRYABLE_ERRORS => e
      log("METRC: Retryable error: #{e.inspect}", :warn)
      Bugsnag.notify(e)
      requeue!(exception: e)
    rescue Metrc::MissingConfiguration, Metrc::MissingParameter => e
      Bugsnag.notify(e)
      log("METRC: Configuration error: #{e.inspect}", :error)
      fail!(exception: e)
    end

    def resource_unit(unit_type)
      resource_units = get_resource_units.select do |resource_unit|
        resource_unit.metrc_type == unit_type &&
          resource_unit.strain&.match?(batch.crop_variety)
      end

      raise InvalidAttributes, "Ambiguous resource unit for #{unit_type} calculation. Expected 1 resource_unit, found #{resource_units.count}" if resource_units.count > 1
      raise InvalidAttributes, "#{unit_type} resource unit not found" if resource_units.count.zero?

      resource_units.first
    end

    # Artemis API delivers resource_unit#name in the following formats:
    # (correct as of 2020-04-07)
    #
    #   (a):  [unit] of [resource type], [strain]
    #   (b):  [resource type], [strain]
    #
    # Here we are expecting format (a)
    def map_resource_unit(resource_unit)
      artemis_unit = resource_unit.unit_name
      metrc_unit = MetrcService::WEIGHT_UNIT_MAP.fetch(artemis_unit, artemis_unit)

      OpenStruct.new(
        id: resource_unit.id,
        name: resource_unit.name,
        unit: metrc_unit,
        label: resource_unit.product_modifier.presence || resource_unit.unit_name,
        strain: resource_unit.crop_variety&.name,
        kind: resource_unit.kind,
        item_type: determine_item_type(resource_unit),
        metrc_type: resource_unit&.options&.fetch('metrc', nil)
      )
    end

    def lookup_metrc_harvest(name)
      # TODO: consider date range for lookup - harvest create/finish dates?
      harvests = call_metrc(:list_harvests)
      metrc_harvest = harvests&.find { |harvest| harvest['Name'] == name }
      raise DataMismatch, "expected to find a harvest in Metrc named '#{name}' but it does not exist" if metrc_harvest.nil?

      metrc_harvest
    end
  end
end
