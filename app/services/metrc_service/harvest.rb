module MetrcService
  class Harvest < MetrcService::Base
    def call
      seeding_unit_id = @attributes.dig(:options, :seeding_unit_id)
      items           = get_items(seeding_unit_id)
      next_step       = complete? ? :harvest_plants : :manicure_plants
      payload         = send "build_#{next_step}_payload", items, batch

      call_metrc(next_step, payload)

      call_metrc(:finish_harvest, harvest_complete_payload) if complete?

      transaction.success = true

      transaction
    end

    private

    def transaction
      @transaction ||= get_transaction(:harvest_batch)
    end

    def build_manicure_plants_payload(items, batch) # rubocop:disable Lint/UnusedMethodArgument
      average_weight = calculate_average_weight(items)

      items.map do |item|
        {
          DryingRoom: @attributes.dig(:options, :zone_name),
          PatientLicenseNumber: nil,
          ActualDate: harvest_date,
          Plant: item.relationships.dig('barcode', 'data', 'id'),
          Weight: average_weight,
          UnitOfWeight: item.attributes['secondary_harvest_unit'],
          HarvestName: nil
        }
      end
    end

    def build_harvest_plants_payload(items, batch)
      harvest_name = batch.arbitrary_id
      average_weight = calculate_average_weight(items)

      items.map do |item|
        {
          DryingRoom: @attributes.dig(:options, :zone_name),
          PatientLicenseNumber: nil,
          ActualDate: harvest_date,
          Plant: item.relationships.dig('barcode', 'data', 'id'),
          Weight: average_weight,
          UnitOfWeight: unit_of_weight(item),
          HarvestName: harvest_name
        }
      end
    end

    def harvest_complete_payload
      [{
        Id: batch.arbitrary_id,
        ActualDate: harvest_date
      }]
    end

    def harvest_date
      @attributes.dig(:start_time)
    end

    def unit_of_weight(_item)
      # TODO: apply per-item resource lookup when available on Artemis API
      # resource_unit = get_resource_unit(item.resource_unit_id)
      # resource_unit.name

      wet_weight_resource_unit.name
    end

    def total_wet_weight
      wet_weight_process_completions.sum do |completion|
        completion.options['processed_quantity']
      end
    end

    def wet_weight_process_completions
      process_completions = move_completions.map do |move_completion|
        get_child_completions(move_completion.id, filter: { action_type: 'process' })
      end

      process_completions.flatten.select do |nested_completion|
        nested_completion.options['resource_unit_id'] && wet_weight_resource_unit.id
      end
    end

    def wet_weight_resource_unit
      resource_units = get_resource_units.select do |resource_unit|
        resource_unit.name =~ /Wet Material/
      end

      raise InvalidAttributes, "Ambiguous resource unit for wet weight calculation. Expected 1 resource_unit, found #{resource_units.count}" if resource_units.count > 1
      raise InvalidAttributes, 'Wet weight resource unit not found' if resource_units.count.zero?

      resource_units.first
    end

    def move_completions
      @batch.completions.select { |completion| completion.action_type == 'move' }
    end

    def calculate_average_weight(items)
      (total_wet_weight.to_f / items.size).round(2)
    end

    def complete?
      @attributes.dig(:options, :harvest_type) == 'complete'
    end
  end
end
