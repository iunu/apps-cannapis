module MetrcService
  class Harvest < MetrcService::Base
    WET_WEIGHT = 'Wet Material'.freeze
    WASTE_WEIGHT = 'Waste'.freeze

    def call
      seeding_unit_id = @attributes.dig(:options, :seeding_unit_id)
      items           = get_items(seeding_unit_id)
      next_step       = complete? ? :harvest_plants : :manicure_plants
      payload         = send("build_#{next_step}_payload", items, batch)

      call_metrc(next_step, payload)

      finalize_harvest if complete?

      success!
    end

    private

    def transaction
      @transaction ||= get_transaction(:harvest_batch)
    end

    def finalize_harvest
      call_metrc(:remove_waste, build_remove_waste_payload)
      call_metrc(:finish_harvest, build_harvest_complete_payload)
    end

    def build_manicure_plants_payload(items, _batch)
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
          UnitOfWeight: unit_of_weight(WET_WEIGHT, item),
          HarvestName: harvest_name
        }
      end
    end

    def build_harvest_complete_payload
      [{
        Id: batch.arbitrary_id,
        ActualDate: harvest_date
      }]
    end

    def build_remove_waste_payload
      waste_completions = process_completions_by_unit_type(WASTE_WEIGHT)

      waste_completions.map do |completion|
        {
          Id: batch.arbitrary_id,
          WasteType: waste_type(completion),
          UnitOfWeight: unit_of_weight(WASTE_WEIGHT),
          WasteWeight: completion.options['processed_quantity'],
          ActualDate: harvest_date
        }
      end
    end

    def waste_type(completion)
      # TODO: determine waste type from 'process' completion
    end

    def harvest_date
      @attributes.dig(:start_time)
    end

    def unit_of_weight(unit_type, _item = nil)
      # TODO: apply per-item resource lookup when available on Artemis API
      # resource_unit = get_resource_unit(item.resource_unit_id)
      # resource_unit.name

      resource_unit(unit_type).name
    end

    def total_weight(unit_type)
      process_completions_by_unit_type(unit_type).sum do |completion|
        completion.options['processed_quantity']
      end
    end

    def process_completions_by_unit_type(unit_type)
      move_process_completions.select do |nested_completion|
        nested_completion.options['resource_unit_id'] == resource_unit(unit_type).id
      end
    end

    def resource_unit(unit_type)
      resource_units = get_resource_units.select do |resource_unit|
        resource_unit.name =~ /#{unit_type}/
      end

      raise InvalidAttributes, "Ambiguous resource unit for #{unit_type} calculation. Expected 1 resource_unit, found #{resource_units.count}" if resource_units.count > 1
      raise InvalidAttributes, "#{unit_type} resource unit not found" if resource_units.count.zero?

      resource_units.first
    end

    def calculate_average_weight(items)
      (total_weight(WET_WEIGHT).to_f / items.size).round(2)
    end

    def move_process_completions
      get_related_completions(:move).map do |move_completion|
        get_child_completions(move_completion.id, filter: { action_type: 'process' })
      end.flatten
    end

    def complete?
      @attributes.dig(:options, :harvest_type) == 'complete'
    end
  end
end
