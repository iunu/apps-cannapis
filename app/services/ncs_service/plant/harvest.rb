require_relative '../../common/plant_resource_triggers'

module NcsService
  module Plant
    class Harvest < NcsService::Base
      include Common::PlantResourceTriggers

      def call
        # allow for harvest of nursery crops - generates clones
        return success! if items.empty?

        handle_resources

        success!
      end

      private

      def transaction
        @transaction ||= get_transaction(:harvest_batch)
      end

      def items
        @items ||= get_items(seeding_unit_id)
      end

      def seeding_unit_id
        @seeding_unit_id ||= @attributes.dig(:options, :seeding_unit_id)
      end
    end
  end
end
