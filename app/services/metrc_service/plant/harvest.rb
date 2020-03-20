module MetrcService
  module Plant
    class Harvest < MetrcService::Base
      WET_WEIGHT = 'Wet Material'.freeze
      WASTE_WEIGHT = 'Waste'.freeze

      def call
        seeding_unit_id = @attributes.dig(:options, :seeding_unit_id)
        items           = get_items(seeding_unit_id)
        next_step       = complete? ? :harvest_plants : :manicure_plants
        payload         = send("build_#{next_step}_payload", items, batch)

        call_metrc(next_step, payload)
        remove_waste

        success!
      end

      private

      def transaction
        @transaction ||= get_transaction(:harvest_batch)
      end

      def remove_waste
        call_metrc(:remove_waste, build_remove_waste_payload)
      end

      def build_manicure_plants_payload(items, _batch)
        average_weight = calculate_average_weight(items)

        items.map do |item|
          {
            DryingLocation: batch.zone.name,
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
            DryingLocation: batch.zone.name,
            PatientLicenseNumber: nil,
            ActualDate: harvest_date,
            Plant: item.relationships.dig('barcode', 'data', 'id'),
            Weight: average_weight,
            UnitOfWeight: unit_of_weight(WET_WEIGHT, item),
            HarvestName: harvest_name
          }
        end
      end

      def build_remove_waste_payload
        waste_completions = process_completions_by_unit_type(WASTE_WEIGHT)

        waste_completions.map do |completion|
          {
            Id: batch_tag,
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
        # resource_unit.unit

        resource_unit(unit_type).unit
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
end
