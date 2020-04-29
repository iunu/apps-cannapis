module MetrcService
  module Plant
    class Discard < MetrcService::Base
      NOT_SPECIFIED = 'Not Specified'.freeze
      METHOD_CALL = {
        immature: :destroy_immature_plants,
        mature: :destroy_mature_plants
      }.freeze

      def call
        send(METHOD_CALL[plant_state])
        success!
      end

      private

      def destroy_immature_plants
        call_metrc(:destroy_plant_batches, build_immature_payload(discard, batch))
      end

      def destroy_mature_plants
        call_metrc(:destroy_plants, build_mature_payload(discard, batch))
      end

      def plant_state
        tracking_method = seeding_unit.item_tracking_method
        @plant_state ||= [nil, 'none'].include?(tracking_method) ? :immature : :mature
      end

      def transaction
        @transaction ||= get_transaction(:discard_batch)
      end

      def discard
        @obj ||= batch.discard(@relationships.dig('action_result', 'data', 'id')&.to_s)
      end

      def build_immature_payload(discard, batch)
        quantity = discard.attributes['quantity']&.to_i
        reason   = reason_note(discard)

        [
          {
            PlantBatch: batch.arbitrary_id,
            Count: quantity,
            ReasonNote: reason,
            ActualDate: discard.attributes['discarded_at']
          }
        ]
      end

      def build_mature_payload(discard, batch)
        discard_type = @attributes.dig('options', 'discard_type')
        reason       = reason_note(discard)

        if discard_type == 'partial'
          return [
            {
              Id: nil,
              Label: @attributes.dig('options', 'barcode'),
              ReasonNote: reason,
              ActualDate: discard.attributes['discarded_at']
            }
          ]
        end

        items = get_items(batch.seeding_unit.id)
        items.map do |item|
          {
            Id: nil,
            Label: item.relationships.dig('barcode', 'data', 'id'),
            ReasonNote: reason,
            ActualDate: discard.attributes['discarded_at']
          }
        end
      end

      def reason_note(discard)
        reason_description = discard.attributes['reason_description']
        reason_type = discard.attributes['reason_type']
        reason_note = "#{reason_type.capitalize}: #{reason_description}. #{@attributes.dig('options', 'note_content')}" if reason_type && reason_description

        reason_note || NOT_SPECIFIED
      end
    end
  end
end
