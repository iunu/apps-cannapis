require_relative './base_service_action'

module Common
  class Base < BaseServiceAction
    extend Memoist

    RETRYABLE_ERRORS = [
      Net::HTTPRetriableError
    ].freeze
    STATES_WITH_ARBITRARY_BATCH_ID = %i[ma mo].freeze

    attr_reader :artemis

    delegate :seeding_unit, to: :batch
    delegate :get_batch, :get_items,
             :get_zone, :get_completion,
             :get_child_completions,
             :get_related_completions,
             to: :artemis

    def initialize(ctx, integration, batch = nil)
      @ctx = ctx
      @relationships = ctx[:relationships]
      @completion_id = ctx[:id]
      @integration = integration
      @attributes = ctx[:attributes]
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
      log("Failed: Crop is not #{@integration.vendor_module::CROP} but #{batch.crop}. Batch ID #{@batch_id}, completion ID #{@completion_id}")
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
      raise NotImplementedError
    end

    protected

    def before
      log("Started: batch ID #{@batch_id}, completion ID #{@completion_id}")

      super

      return if @batch_id.nil?

      validate_batch!
      validate_seeding_unit!
    end

    def state
      # state map will override the integration's state. Used if metrc has not yet created an endpoint for the state.
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

    def determine_item_type(resource_unit)
      options = resource_unit.options

      if options.present?
        return options['metrc_item_name'] if options['metrc_item_name']
        return "#{resource_unit.crop_variety&.name} #{options['metrc_item_suffix']}" if options['metrc_item_suffix'].present?
      end

      resource_unit.crop_variety&.name
    end

    def batch
      get_batch
    end
    memoize :batch

    def batch_tag # rubocop:disable Metrics/PerceivedComplexity
      barcodes = batch.relationships.dig('barcodes', 'data')&.map { |label| label['id'] }

      raise InvalidAttributes, "Missing barcode for batch '#{batch.arbitrary_id}'" if barcodes.blank?

      matches = barcodes&.select { |label| /[A-Z0-9]{24,24}(-split)?/.match?(label) }&.sort
      arbitrary_id_allowed = STATES_WITH_ARBITRARY_BATCH_ID.include?(@integration.state.to_sym)

      # In some states, you can send our batch
      # arbitrary ID instead of a Metrc tag
      raise InvalidAttributes, "Expected barcode for batch '#{batch.arbitrary_id}' to be alphanumeric with 24 characters. Got: #{barcodes.join(', ')}" if matches.blank? && !arbitrary_id_allowed

      return batch.arbitrary_id if matches.blank? && arbitrary_id_allowed

      Common::Utils.normalize_barcode(matches&.first)
    end
    memoize :batch_tag

    def validate_batch!
      raise BatchCropInvalid unless batch.crop == @integration.vendor_module::CROP
    end

    def validate_seeding_unit!
      return if ['preprinted', 'none', nil].include?(item_tracking_method)

      raise InvalidBatch, "Failed: Seeding unit is not valid for Metrc #{item_tracking_method}. " \
        "Batch ID #{@batch_id}, completion ID #{@completion_id}"
    end

    def config
      @config ||= Rails.application.config_for('providers/metrc')
    end

    # Possible statuses: active, removed, archived
    def completion_status
      @attributes['status']
    end

    def resource_completions_by_unit_id(resource_unit_id)
      batch
        .completions
        .select { |completion| %w[process generate].include?(completion.action_type) }
        .select { |completion| completion.options['resource_unit_id'] == resource_unit_id }
    end

    def location_name
      Common::Utils.normalize_zone_name(batch.zone&.name)
    end

    def item_tracking_method
      seeding_unit&.item_tracking_method
    end

    def harvest_disabled?
      @integration.disable_harvest
    end
  end
end
