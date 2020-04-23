require_relative '../../common/resource_handler'

module NcsService
  module Resource
    class WetWeight < Base
      include Common::ResourceHandler

      resource_name 'wet_weight'

      def call
        harvest_plants if resource_present?

        success!
      end

      private

      def harvest_plants
        create_harvest(items, batch)

        payload = build_harvest_plants_payload(items, batch)
        call_vendor(:plant, :harvest, payload)
      end

      def create_harvest(items, batch)
        item = items.first
        unit = unit_of_weight(WET_WEIGHT, item)
        payload = [{
          Name: batch.arbitrary_id,
          HarvestType: 'Product',
          DryingRoomName: batch.zone.name,
          UnitOfWeightName: unit,
          HarvestStartDate: harvest_date
        }]

        result = call_vendor(:harvest, :create, payload)
        get_transaction(:harvest, payload)

        result
      end

      def build_harvest_plants_payload(items, batch)
        harvest_name = batch.arbitrary_id
        average_weight = calculate_average_weight(items)

        items.map do |item|
          {
            Label: item.relationships.dig('barcode', 'data', 'id'),
            HarvestedWetWeight: average_weight,
            HarvestedUnitOfWeightName: unit_of_weight(WET_WEIGHT, item),
            RoomName: batch.zone.name,
            HarvestName: harvest_name,
            ManicuredDate: harvest_date
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
