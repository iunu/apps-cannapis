require_relative '../common/base_service_action'

module NcsService
  class Base < Common::BaseServiceAction
    RETRYABLE_ERRORS = [
      Net::HTTPRetriableError,
      NcsAnalytics::Errors::RequestError,
      NcsAnalytics::Errors::TooManyRequests,
      NcsAnalytics::Errors::InternalServerError
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
      log("[NCS_SERVICE_ACTION_FAILURE] Failed: batch ID #{@batch_id}, completion ID #{@completion_id}; #{e.inspect}", :error)
      fail!(transaction)
    rescue StandardError => e
      log("[NCS_SERVICE_FAILURE] Failed: batch ID #{@batch_id}, completion ID #{@completion_id}; #{e.inspect}", :error)
      fail!(transaction)
    end

    private

    attr_reader :client

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

    protected

    def before
      log("Started: batch ID #{@batch_id}, completion ID #{@completion_id}")

      super

      return if @batch_id.nil?

      validate_batch!
      validate_seeding_unit!
    end

    def call_ncs(resource, method, *args)
      log("[#{resource}##{method.to_s.upcase}] NCS Analytics API request. URI #{@client.uri}", :debug)
      log(args.to_yaml, :debug)

      @client.send(resource).send(method, *args)
    rescue *RETRYABLE_ERRORS => e
      log("NCS Analytics: Retryable error: #{e.inspect}", :warn)
      Bugsnag.notify(e)
      requeue!(exception: e)
    rescue NcsAnalytics::Errors::MissingConfiguration, NcsAnalytics::Errors::MissingParameter => e
      log("NCS Analytics: Configuration error: #{e.inspect}", :error)
      Bugsnag.notify(e)
      fail!(exception: e)
    rescue StandardError => e
      log("NCS Analytics: #{e.inspect}", :error)
      Bugsnag.notify(e)
      fail!(exception: e)
    end

    def get_transaction(name, metadata = @attributes)
      Transaction.find_or_create_by(
        vendor: :ncs, account: @integration.account, integration: @integration,
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
        resource_unit.name =~ /#{unit_type}(,\s|\s-\s)#{batch.crop_variety}/
      end

      raise InvalidAttributes, "Ambiguous resource unit for #{unit_type} calculation. Expected 1 resource_unit, found #{resource_units.count}" if resource_units.count > 1
      raise InvalidAttributes, "#{unit_type} resource unit not found" if resource_units.count.zero?

      resource_units.first
    end

    # Artemis API delivers resource_unit#name in the following formats:
    # (correct as of 2020-03-24)
    #
    #   (a):  [unit] of [resource type], [strain]
    #   (b):  [resource type], [strain]
    #
    # Here we are expecting format (a)
    def map_resource_unit(resource_unit)
      artemis_unit = resource_unit.name[/^(\w+)/, 1]
      service_unit = NcsService::WEIGHT_UNIT_MAP.fetch(artemis_unit, artemis_unit)

      OpenStruct.new(
        id: resource_unit.id,
        name: resource_unit.name,
        unit: service_unit,
        label: resource_unit.name[/^([\w\s]+)(,\s|\s-\s)/, 1],
        strain: batch.crop_variety,
        kind: resource_unit.kind,
        conversion_si: resource_unit.conversion_si
      )
    end

    def batch
      @batch ||= get_batch
    end

    def batch_tag
      batch.relationships.dig('barcodes', 'data', 0, 'id')
    end

    def validate_batch!
      raise BatchCropInvalid unless batch.crop == NcsService::CROP
    end

    def validate_seeding_unit!
      return if ['preprinted', 'none', nil].include?(seeding_unit.item_tracking_method)

      raise InvalidBatch, "Failed: Seeding unit is not valid for NCS #{seeding_unit.item_tracking_method}. " \
        "Batch ID #{@batch_id}, completion ID #{@completion_id}"
    end

    # Possible statuses: active, removed, archived
    def completion_status
      @attributes['status']
    end

    def lookup_harvest(name)
      # TODO: consider date range for lookup - harvest create/finish dates?
      harvests = call_ncs(:harvest, :active)
      ncs_harvest = harvests.find { |harvest| harvest['Name'] == name }
      raise DataMismatch, "expected to find a harvest in NCS named '#{name}' but it does not exist" if ncs_harvest.nil?

      ncs_harvest
    end

    def lookup_plant_batch(tag)
      plant_batches = call_ncs(:plant_batch, :all)
      plant_batch = plant_batches.find { |batch| batch['Name'] == tag }
      raise DataMismatch, "expected to find a plant batch in Metrc with the tag '#{tag}' but it does not exist" if plant_batch.nil?

      plant_batch
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
