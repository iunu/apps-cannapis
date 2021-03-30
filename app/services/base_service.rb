module BaseService
  CROP = 'Cannabis'.freeze

  SEEDING_UNIT_MAP = {
    'testing_package' => 'package',
    'clone' => 'plant',
    'clones' => 'plant',
    'plant' => 'plant',
    'plants' => 'plant',
    'plant_barcoded' => 'plant',
    'plants_barcoded' => 'plant',
    'plant_clone' => 'plant',
    'plants_clone' => 'plant',
    'plant_mom' => 'plant',
    'plants_mom' => 'plant'
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

    delegate :run_mode, to: :module_for_completion

    def perform_action
      handler = module_for_completion
      return unless handler

      @task&.current_action = handler.name.underscore
      handler.call(@ctx, @integration, batch)
    end

    def module_for_completion
      action_type = completion.action_type == 'split' ? 'move' : completion.action_type

      # TODO: add resource endpoints to associated parent service.. move, harvest rather than dealing with them individually.
      if %w[generate consume].include?(action_type)
        module_name = find_resource_module
      else
        raise "seeding_unit is undefined for completion #{completion.id} #{completion.action_type}" unless seeding_unit

        seeding_unit_name = module_name_for_seeding_unit.camelize
        module_name = "#{seeding_unit_name}::#{action_type.camelize}"
      end
      return unless module_name

      @integration.vendor_module.const_get(module_name)
    rescue NameError => e
      raise InvalidOperation, "Processing not supported for #{seeding_unit.name} #{action_type} completion #{completion.id}. #{e.inspect}"
    end

    private

    def module_name_for_seeding_unit
      name = seeding_unit.name.parameterize(separator: '_')
      SEEDING_UNIT_MAP.fetch(name, name)
    end

    # return the correct resource service based on the resource unit name.
    def find_resource_module
      resource_unit = artemis.get_resource_unit(completion.options&.dig('resource_unit_id'))
      if resource_unit.name.downcase.include?('wet weight')
        'Resource::WetWeight'
      elsif resource_unit.name.downcase.include?('waste')
        'Resource::WetWaste'
      end
    end

    def batch
      @batch ||= artemis.get_batch
    end

    def completion
      @completion ||= artemis.get_completion(@ctx['id'])
    end

    def seeding_unit
      completion.included&.dig(:seeding_units)&.first
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
