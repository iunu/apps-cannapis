module BaseService
  CROP = 'Cannabis'.freeze

  SEEDING_UNIT_MAP = {
    'testing_package' => 'package',
    'plant_barcoded' => 'plant',
    'plants_barcoded' => 'plant',
    'plant_clone' => 'plant',
    'plants_clone' => 'plant',
    'clones' => 'plant',
    'clone' => 'plant',
    'plants' => 'plant',
    'plant' => 'plant'
  }.freeze

  WEIGHT_UNIT_MAP = {
    'mg' => 'Milligrams',
    'Milligram' => 'Milligrams',
    'g' => 'Grams',
    'Gram' => 'Grams',
    'kg' => 'Kilograms',
    'Kilogram' => 'Kilograms',
    'oz' => 'Ounces',
    'Ounce' => 'Ounces',
    'lb' => 'Pounds',
    'Pound' => 'Pounds'
  }.freeze

  def perform_action(ctx, integration, task = nil)
    Lookup.new(ctx, integration, task).perform_action
  end

  def run_now?(ctx, integration)
    Lookup.new(ctx, integration).run_mode == :now
  end

  def self.included(base)
    base.send(:module_function, :perform_action, :run_now?)
  end

  class Lookup
    def initialize(ctx, integration, task = nil)
      @ctx = ctx
      @integration = integration
      @task = task
    end

    delegate :seeding_unit, to: :batch
    delegate :run_mode, to: :module_for_completion

    def perform_action
      handler = module_for_completion

      @task&.current_action = handler.name.underscore
      handler.call(@ctx, @integration, batch)
    end

    def module_for_completion
      action_type = completion.action_type.camelize

      # We need to call for wet weight and wet waste resources
      # since a resource call was received
      if %w[generate consume].include?(action_type)
        module_name = 'Resource::WetWeight'
      else
        seeding_unit_name = module_name_for_seeding_unit.camelize
        module_name = "#{seeding_unit_name}::#{action_type}"
      end

      @integration.vendor_module.const_get(module_name)
    rescue NameError
      raise InvalidOperation, "Processing not supported for #{seeding_unit.name} #{action_type} completions"
    end

    private

    def module_name_for_seeding_unit
      name = seeding_unit.name.parameterize(separator: '_')
      SEEDING_UNIT_MAP.fetch(name, name)
    end

    def batch
      @batch ||= artemis.get_batch('zone,zone.sub_stage,barcodes,completions,custom_data,seeding_unit,harvest_unit,sub_zone')
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
