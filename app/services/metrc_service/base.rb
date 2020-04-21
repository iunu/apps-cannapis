require_relative '../common/base_service_action'

module MetrcService
  class Base < Common::BaseServiceAction
    RETRYABLE_ERRORS = [
      Net::HTTPRetriableError,
      Metrc::RequestError
    ].freeze

    attr_reader :artemis

    delegate :seeding_unit, to: :batch
    delegate :get_batch, :get_items, :get_zone,
             :get_child_completions,
             :get_related_completions,
             to: :artemis

    def initialize(ctx, integration, batch = nil)
      @ctx = ctx
      @relationships = ctx[:relationships]
      @completion_id = ctx[:id]
      @integration = integration
      @attributes  = ctx[:attributes]
      @facility_id = @relationships&.dig(:facility, :data, :id)
      @batch_id = @relationships&.dig(:batch, :data, :id)
      @artemis  = ArtemisService.new(@integration.account, @batch_id, @facility_id)
      @client = build_client
      @batch  = batch if batch

      super
    end

    def run(*)
      super
    rescue BatchCropInvalid
      log("Failed: Crop is not #{CROP} but #{batch.crop}. Batch ID #{@batch_id}, completion ID #{@completion_id}")
      fail!
    rescue InvalidBatch, InvalidOperation => e
      log(e.message)
      fail!
    rescue ServiceActionFailure => e
      log("Failed: batch ID #{@batch_id}, completion ID #{@completion_id}; #{e.inspect}", :error)
      fail!(transaction)
    end

    private

    attr_reader :client

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

    def before
      log("Started: batch ID #{@batch_id}, completion ID #{@completion_id}")

      super

      return if @batch_id.nil?

      validate_batch!
      validate_seeding_unit!
    end

    def call_metrc(method, *args)
      log("[#{method.to_s.upcase}] Metrc API request. URI #{@client.uri}", :debug)
      log(args.to_yaml, :debug)

      response = @client.send(method, @integration.vendor_id, *args)
      JSON.parse(response.body) if response&.body&.present?
    rescue *RETRYABLE_ERRORS => e
      log("METRC: Retryable error: #{e.inspect}", :warn)
      Bugsnag.notify(e)
      requeue!(exception: e)
    rescue Metrc::MissingConfiguration, Metrc::MissingParameter => e
      log("METRC: Configuration error: #{e.inspect}", :error)
      Bugsnag.notify(e)
      fail!(exception: e)
    end

    def state
      config[:state_map].fetch(@integration.state.upcase.to_sym, @integration.state)
    end

    def get_transaction(name, metadata = @attributes)
      Transaction.find_or_create_by(
        vendor: :metrc, account: @integration.account, integration: @integration,
        batch_id: @batch_id, completion_id: @completion_id, type: name
      ) do |transaction|
        transaction.metadata = metadata
      end
    end

    def get_resource_unit(id, include: nil)
      resource_unit = @artemis.get_resource_unit(id, include: include)
      map_resource_unit(resource_unit)
    end

    def get_resource_units(include: nil)
      @artemis.get_resource_units(include: include).map do |resource_unit|
        map_resource_unit(resource_unit)
      end
    end

    def resource_unit(unit_type)
      resource_units = get_resource_units.select do |resource_unit|
        resource_unit.metrc_type == unit_type &&
          resource_unit.strain.match?(batch.crop_variety)
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
        strain: resource_unit.name[/^[\w\s]+,\s([\w\s]+) Cannabis/, 1],
        kind: resource_unit.kind,
        metrc_type: resource_unit&.options&.fetch('metrc', nil)
      )
    end

    def batch
      @batch ||= get_batch
    end

    def batch_tag
      return @tag if @tag

      barcodes = batch.relationships.dig('barcodes', 'data')&.map { |label| label['id'] }

      matches = barcodes&.select { |label| /[A-Z0-9]{24,}/.match?(label) }

      raise InvalidAttributes, "No barcode found for batch '#{batch.arbitrary_id}'" unless barcodes.present?
      raise InvalidAttributes, "Expected barcode for batch '#{batch.arbitrary_id}' to be alphanumeric with 24 characters. Got: '#{barcodes.join(', ')}'" unless matches.present?

      return @tag = matches&.first unless matches&.size > 1

      matches.sort! { |a, b| a <=> b }

      @tag = matches&.first
    end

    def validate_batch!
      raise BatchCropInvalid unless batch.crop == MetrcService::CROP
    end

    def validate_seeding_unit!
      return if ['preprinted', 'none', nil].include?(seeding_unit.item_tracking_method)

      raise InvalidBatch, "Failed: Seeding unit is not valid for Metrc #{seeding_unit.item_tracking_method}. " \
        "Batch ID #{@batch_id}, completion ID #{@completion_id}"
    end

    def config
      @config ||= Rails.application.config_for('providers/metrc')
    end

    # Possible statuses: active, removed, archived
    def completion_status
      @attributes['status']
    end

    def lookup_metrc_harvest(name)
      # TODO: consider date range for lookup - harvest create/finish dates?
      harvests = call_metrc(:list_harvests)
      metrc_harvest = harvests&.find { |harvest| harvest['Name'] == name }
      raise DataMismatch, "expected to find a harvest in Metrc named '#{name}' but it does not exist" if metrc_harvest.nil?

      metrc_harvest
    end

    def lookup_metrc_plant_batch(tag)
      metrc_plant_batches = call_metrc(:list_plant_batches)
      metrc_plant_batch = metrc_plant_batches&.find { |batch| batch['Name'] == tag }
      raise DataMismatch, "expected to find a plant batch in Metrc with the tag '#{tag}' but it does not exist" if metrc_plant_batch.nil?

      metrc_plant_batch
    end


    def resource_completions_by_unit_type(unit_type)
      resource_unit_id = resource_unit(unit_type).id

      batch
        .completions
        .select { |completion| %w[process generate].include?(completion.action_type) }
        .select { |completion| completion.options['resource_unit_id'] == resource_unit_id }
    end
  end
end
