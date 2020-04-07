module MetrcService
  module Plant
    class Harvest < MetrcService::Base
      WET_WEIGHT = 'wet_weight'.freeze
      WASTE_WEIGHT = 'wet_waste'.freeze

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
        waste_completions = resource_completions_by_unit_type(WASTE_WEIGHT)
        metrc_harvest = lookup_metrc_harvest(batch.arbitrary_id)

        waste_completions.map do |completion|
          {
            Id: metrc_harvest['Id'],
            WasteType: waste_type(completion),
            UnitOfWeight: unit_of_weight(WASTE_WEIGHT),
            WasteWeight: completion.options['generated_quantity'] || completion.options['processed_quantity'],
            ActualDate: harvest_date
          }
        end
      end

      # If the waste type (the resource unit's +product_modifier+) is found in the list of available waste types
      # from Metrc (GET [metrc]/harvests/v1/waste/types), # then we will use that.
      #
      # If not, then we use the first available valid waste type from Metrc
      def waste_type(completion)
        waste_resource_unit = get_resource_unit(completion.attributes.dig('options', 'resource_unit_id'))
        metrc_waste_types = JSON.parse(@client.get('harvests', 'waste/types').body)
        valid_waste_types = metrc_waste_types.map { |obj| obj['Name'] }

        if valid_waste_types.include?(waste_resource_unit.label)
          completion.product_modifier
        else
          log("Waste type not found on Metrc, defaulting to #{valid_waste_types.first}", :warn)
          valid_waste_types.first
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
