module MetrcService
  module Plant
    class Harvest < Base
      WET_WEIGHT = 'wet_weight'.freeze

      def call
        # allow for harvest of nursery crops - generates clones
        return success! if items.empty?

        if complete?
          harvest_plants
        else
          manicure_plants
        end

        handle_resources

        success!
      end

      private

      def transaction
        @transaction ||= get_transaction(:harvest_batch)
      end

      def manicure_plants
        call_metrc(:manicure_plants, build_manicure_plants_payload(items, batch))
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

      def harvest_plants
        call_metrc(:harvest_plants, build_harvest_plants_payload(items, batch))
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

      def items
        @items ||= get_items(seeding_unit_id)
      end

      def seeding_unit_id
        @seeding_unit_id ||= @attributes.dig(:options, :seeding_unit_id)
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
