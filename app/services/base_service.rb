module BaseService
  CROP = 'Cannabis'.freeze

  # noop seeding units do not need to be reported to metrc
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
    'plants_mom' => 'plant',
    'bin' => 'noop',
    'plant_cutting' => 'noop',
    'plant_cuttings' => 'noop'
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

    delegate :run_mode, to: :module_for_completion, allow_nil: true

    def perform_action
      if completion.status == 'removed'
        remove_transaction(completion.id)
      else
        handler = module_for_completion
        return unless handler

        @task&.current_action = handler.name.underscore
        handler.call(@ctx, @integration, batch)
      end
    end

    def remove_transaction(completion_id)
      transactions = Transaction.where(completion_id: completion_id)
      transactions.destroy_all
    end

    # Determines the correct cannAPIs module to use for creating a payload to send to metrc.
    # for example `MetrcService::Plant::Move`
    def module_for_completion
      action_type = completion.action_type == 'split' ? 'move' : completion.action_type

      # TODO: add resource endpoints to associated parent service.. move, harvest rather than dealing with them individually.
      if %w[generate consume].include?(action_type)
        module_name = find_resource_module
      else
        raise "seeding_unit is undefined for completion #{completion.id} #{completion.action_type}" unless seeding_unit

        seeding_unit_name = module_name_for_seeding_unit
        # completions using a noop seeding unit do not need to be reported to metrc
        return if seeding_unit_name == 'noop'

        module_name = "#{seeding_unit_name&.camelize}::#{action_type.camelize}"
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
