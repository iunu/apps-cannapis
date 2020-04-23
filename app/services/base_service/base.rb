require_relative '../common/base_service_action'

module BaseService
  class Base < Common::BaseServiceAction
    RETRYABLE_ERRORS = [
      Net::HTTPRetriableError,
    ].freeze

    FATAL_ERRORS = [].freeze

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
      @vendor = scope::Client.new(@integration)
      @batch  = batch if batch
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
      log("#{@integration.vendor.upcase}_SERVICE_ACTION_FAILURE Failed: batch ID #{@batch_id}, completion ID #{@completion_id}; #{e.inspect}", :error)
      fail!(transaction)
    end

    def call_vendor(*args)
      @vendor.call(*args)
    rescue *self.class::RETRYABLE_ERRORS => e
      Bugsnag.notify(e)
      log("#{integration.vendor.upcase}: Retryable error: #{e.inspect}", :warn)
      requeue!(exception: e)
    rescue *self.class::FATAL_ERRORS => e
      Bugsnag.notify(e)
      log("#{integration.vendor.upcase}: Configuration error: #{e.inspect}", :error)
      fail!(exception: e)
    end

    private

    def before
      log("Started: batch ID #{@batch_id}, completion ID #{@completion_id}")

      super

      return if @batch_id.nil?

      validate_batch!
      validate_seeding_unit!
    end

    def get_transaction(name, metadata = @attributes)
      Transaction.find_or_create_by(
        vendor: @integration.vendor, account: @integration.account, integration: @integration,
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
        # TODO: make this generic for cannapis, with overrides possible based on vendor name
        return options['metrc_item_name'] if options['metrc_item_name']
        return "#{resource_unit.name} #{options['metrc_item_suffix']}" if options['metrc_item_suffix'].present?
      end

      resource_unit.crop_variety&.name
    end


    def batch
      @batch ||= get_batch
    end

    def batch_tag
      return @tag if @tag

      barcodes = batch.relationships.dig('barcodes', 'data')&.map { |label| label['id'] }

      matches = barcodes&.select { |label| /[A-Z0-9]{24,}/.match?(label) }

      raise InvalidAttributes, "Missing barcode for batch '#{batch.arbitrary_id}'" if barcodes.blank?
      raise InvalidAttributes, "Expected barcode for batch '#{batch.arbitrary_id}' to be alphanumeric with 24 characters. Got: #{barcodes.join(', ')}" if matches.blank?

      return @tag = matches&.first unless matches&.size > 1

      matches.sort! { |a, b| a <=> b }

      @tag = matches&.first
    end

    def validate_batch!
      raise BatchCropInvalid unless batch.crop == @integration.vendor_module::CROP
    end

    def validate_seeding_unit!
      return if ['preprinted', 'none', nil].include?(seeding_unit.item_tracking_method)

      raise InvalidBatch, "Failed: Seeding unit is not valid for #{@integration.vendor_name} #{seeding_unit.item_tracking_method}. " \
        "Batch ID #{@batch_id}, completion ID #{@completion_id}"
    end

    # Possible statuses: active, removed, archived
    def completion_status
      @attributes['status']
    end

    def resource_completions_by_unit_type(unit_type)
      resource_unit_id = resource_unit(unit_type).id

      batch
        .completions
        .select { |completion| %w[process generate].include?(completion.action_type) }
        .select { |completion| completion.options['resource_unit_id'] == resource_unit_id }
    end

    def scope
      self.class.name.split('::').first.constantize
    end
  end
end
