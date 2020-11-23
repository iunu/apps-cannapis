module NcsService
  module Plant
    class Harvest < NcsService::Base
      WET_WEIGHT = 'Wet Weight'.freeze
      WASTE_WEIGHT = 'Waste'.freeze

      def call
        if complete?
          # We need to create a harvest first
          create_harvest(batch)

          payload = build_harvest_plants_payload(barcodes, batch)
          call_ncs(:plant, :harvest, payload)
        else
          payload = build_manicure_plants_payload(barcodes)
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

      def create_harvest(batch)
        payload = [{
          Name: batch.arbitrary_id,
          HarvestType: 'Product',
          DryingRoomName: location_name,
          UnitOfWeightName: unit_of_weight(WET_WEIGHT),
          HarvestStartDate: harvest_date
        }]

        result = call_ncs(:harvest, :create, payload)
        get_transaction(:harvest, payload)

        result
      end

      def build_manicure_plants_payload(barcodes)
        average_weight = calculate_average_weight(barcodes)

        barcodes.map do |barcode|
          {
            Label: barcode,
            ManicuredWeight: average_weight,
            ManicuredUnitOfWeightName: unit_of_weight(WET_WEIGHT),
            RoomName: location_name,
            HarvestName: nil,
            ManicuredDate: harvest_date
          }
        end
      end

      def build_harvest_plants_payload(barcodes, batch)
        harvest_name = batch.arbitrary_id
        average_weight = calculate_average_weight(barcodes)

        barcodes.map do |barcode|
          {
            Label: barcode,
            HarvestedWetWeight: average_weight,
            HarvestedUnitOfWeightName: unit_of_weight(WET_WEIGHT),
            RoomName: location_name,
            HarvestName: harvest_name,
            ManicuredDate: harvest_date
          }
        end
      end

      def build_remove_waste_payload
        waste_completions = resource_completions_by_unit_id(WASTE_WEIGHT)
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
        @attributes['start_time']
      end

      def unit_of_weight(unit_type, _item = nil)
        # TODO: apply per-item resource lookup when available on Artemis API
        # resource_unit = get_resource_unit(item.resource_unit_id)
        # resource_unit.unit

        resource_unit(unit_type).unit
      end

      def total_weight(unit_type)
        resource_completions_by_unit_id(unit_type).sum do |completion|
          completion.options['generated_quantity'] || completion.options['processed_quantity']
        end
      end

      def calculate_average_weight(barcodes)
        (total_weight(WET_WEIGHT).to_f / barcodes.size).round(2)
      end

      def complete?
        @attributes.dig(:options, :harvest_type) == 'complete'
      end
    end
  end
end
