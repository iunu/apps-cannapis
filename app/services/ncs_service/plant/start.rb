module NcsService
  module Plant
    class Start < NcsService::Base
      def call
        payload = build_start_payload(batch)

        call_ncs(:plant_batch, :create, payload)

        success!
      end

      private

      def transaction
        @transaction ||= get_transaction(:start_batch)
      end

      def build_start_payload(batch)
        batch_quantity = batch.attributes['quantity']&.to_i
        quantity = batch_quantity.positive? ? batch_quantity : @attributes.dig('options', 'quantity')&.to_i
        type = %w[clone seed].include?(batch.zone.attributes.dig('seeding_unit', 'name').downcase) ? batch.zone.attributes.dig('seeding_unit', 'name') : 'Clone'

        [{
          Name: batch_tag,
          Type: type,
          Count: quantity,
          StrainName: batch.attributes['crop_variety'],
          RoomName: batch.zone.name,
          PlantedDate: batch.attributes['seeded_at']
        }]
      end
    end
  end
end
