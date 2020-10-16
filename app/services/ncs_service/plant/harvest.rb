module NcsService
  module Plant
    class Harvest < NcsService::Base
      WET_WEIGHT = 'Wet Weight'.freeze
      WASTE_WEIGHT = 'Waste'.freeze

      def call
        seeding_unit_id = @attributes.dig(:options, :seeding_unit_id)
        items           = get_items(seeding_unit_id)

        if complete?
          # We need to create a harvest first
          create_harvest(items, batch)

          payload = build_harvest_plants_payload(items, batch)
          call_ncs(:plant, :harvest, payload)
        else
          payload = build_manicure_plants_payload(items, batch)
          call_ncs(:plant, :manicure, payload)
        end

        remove_waste
        success!
      end

      private

      def transaction
        @transaction ||= get_transaction(:harvest_batch)
      end

      # TODO: Fix me
      def remove_waste
        call_ncs(:harvest, :remove_waste, build_remove_waste_payload)
      end

      def create_harvest(items, batch)
        item = items.first
        unit = unit_of_weight(WET_WEIGHT, item)
        payload = [{
          Name: batch.arbitrary_id,
          HarvestType: 'Product',
          DryingRoomName: location_name,
          UnitOfWeightName: unit,
          HarvestStartDate: harvest_date
        }]

        result = call_ncs(:harvest, :create, payload)
        get_transaction(:harvest, payload)

        result
      end

      def build_manicure_plants_payload(items, batch)
        average_weight = calculate_average_weight(items)

        items.map do |item|
          {
            Label: item.relationships.dig('barcode', 'data', 'id'),
            ManicuredWeight: average_weight,
            ManicuredUnitOfWeightName: item.attributes['secondary_harvest_unit'],
            RoomName: location_name,
            HarvestName: nil,
            ManicuredDate: harvest_date
          }
        end
      end

      def build_harvest_plants_payload(items, batch)
        harvest_name = batch.arbitrary_id
        average_weight = calculate_average_weight(items)

        items.map do |item|
          {
            Label: item.relationships.dig('barcode', 'data', 'id'),
            HarvestedWetWeight: average_weight,
            HarvestedUnitOfWeightName: unit_of_weight(WET_WEIGHT, item),
            RoomName: location_name,
            HarvestName: harvest_name,
            ManicuredDate: harvest_date
          }
        end
      end

      def build_remove_waste_payload
        waste_completions = resource_completions_by_unit_type(WASTE_WEIGHT)
        ncs_harvest = lookup_harvest(batch.arbitrary_id)

        waste_completions.map do |completion|
          {
            Id: ncs_harvest['Id'],
            UnitOfWeightName: unit_of_weight(WASTE_WEIGHT),
            TotalWasteWeight: completion.options['generated_quantity'] || completion.options['processed_quantity'],
            FinishedDate: harvest_date
          }
        end
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
        resource_completions_by_unit_type(unit_type).sum do |completion|
          completion.options['generated_quantity'] || completion.options['processed_quantity']
        end
      end

      def calculate_average_weight(items)
        (total_weight(WET_WEIGHT).to_f / items.size).round(2)
      end

      def complete?
        @attributes.dig(:options, :harvest_type) == 'complete'
      end
    end
  end
end
