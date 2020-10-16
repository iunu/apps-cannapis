require_relative '../../common/resource_handling'

module MetrcService
  module Resource
    class WetWeight < Base
      include Common::ResourceHandling

      resource_name 'wet_weight'

      def call
        return if harvest_disabled?

        harvest_plants if resource_present? || @ctx['attributes']['action_type'] == 'generate'

        success!
      end

      private

      def harvest_plants
        call_metrc(:harvest_plants, build_harvest_plants_payload(items, batch))
      end

      def build_harvest_plants_payload(items, batch)
        harvest_name = batch.arbitrary_id
        average_weight = calculate_average_weight(items)
        resource_unit = get_resource_unit(@ctx.dig('attributes', 'options', 'resource_unit_id'))

        items.map do |item|
          {
            DryingLocation: location_name,
            PatientLicenseNumber: nil,
            ActualDate: harvest_date,
            Plant: item.relationships.dig('barcode', 'data', 'id'),
            Weight: average_weight,
            UnitOfWeight: resource_unit.unit,
            HarvestName: harvest_name
          }
        end
      end

      def harvest_date
        @attributes.dig(:start_time)
      end

      def items
        @items ||= get_items(seeding_unit_id)
      end

      def seeding_unit_id
        @seeding_unit_id ||= @attributes.dig(:options, :seeding_unit_id)
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
        (total_weight(resource_name).to_f / items.size).round(2)
      end
    end
  end
end
