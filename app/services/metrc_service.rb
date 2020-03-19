module MetrcService
  class InvalidBatch < StandardError; end
  class BatchCropInvalid < StandardError; end
  class InvalidOperation < StandardError; end
  class InvalidAttributes < StandardError; end
  class DataMismatch < StandardError; end

  CROP = 'Cannabis'.freeze

  SEEDING_UNIT_MAP = {
    'testing_package' => 'package',
    'plant_barcoded' => 'plant'
  }.freeze

  WEIGHT_UNIT_MAP = {
    'mg' => 'Milligrams',
    'g' => 'Grams',
    'kg' => 'Kilograms',
    'oz' => 'Ounces',
    'lb' => 'Pounds'
  }.freeze

  module_function

  def perform_action(ctx, integration, task = nil)
    Lookup.new(ctx, integration, task).perform_action
  end

  class Lookup
    def initialize(ctx, integration, task = nil)
      @ctx = ctx
      @integration = integration
      @task = task
    end

    delegate :seeding_unit, to: :batch

    def perform_action
      handler = module_for_completion

      @task&.current_action = handler.name.underscore
      handler.call(@ctx, @integration, batch)
    end

    def module_for_completion
      action_type = completion.action_type.camelize
      seeding_unit_name = module_name_for_seeding_unit.camelize

      "MetrcService::#{seeding_unit_name}::#{action_type}".constantize
    rescue NameError
      raise InvalidOperation, "Processing not supported for #{seeding_unit.name} #{action_type} completions"
    end

    private

    def module_name_for_seeding_unit
      name = seeding_unit.name.parameterize(separator: '_')
      SEEDING_UNIT_MAP.fetch(name, name)
    end

    def batch
      @batch ||= artemis.get_batch('zone,barcodes,completions,custom_data,seeding_unit,harvest_unit,sub_zone')
    end

    def completion
      @completion ||= batch.completion(@ctx['id'])
    end

    def artemis
      @artemis ||= begin
                     facility_id = @ctx.dig('relationships', 'facility', 'data', 'id')
                     batch_id = @ctx.dig('relationships', 'batch', 'data', 'id')
                     ArtemisService.new(@integration.account, batch_id, facility_id)
                   end
    end
  end
end
