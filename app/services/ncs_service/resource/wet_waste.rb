require_relative '../../common/resource_handler'

module NcsService
  module Resource
    class WetWaste < NcsService::Base
      include Common::ResourceHandler

      resource_name 'wet_waste'

      def call
        remove_waste if resource_present?

        success!
      end

      private

      def remove_waste
        call_vendor(:harvest, :remove_waste, build_remove_waste_payload)
      end

      def build_remove_waste_payload
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

      def unit_of_weight(unit_type, _item = nil)
        # TODO: apply per-item resource lookup when available on Artemis API
        # resource_unit = get_resource_unit(item.resource_unit_id)
        # resource_unit.unit

        resource_unit(unit_type).unit
      end

      def harvest_date
        @attributes.dig(:start_time)
      end
    end
  end
end
