module MetrcService
  module Plant
    class Discard < MetrcService::Base
      def call
        payload = send("build_#{plant_state}_payload", discard, batch)
        action = plant_state == 'immature' ? :destroy_plant_batches : :destroy_plants

        call_metrc(action, payload)

        success!
      end

      private

      def plant_state
        @plant_state ||= seeding_unit.item_tracking_method.nil? ? 'immature' : 'mature'
      end

      def transaction
        @transaction ||= get_transaction(:discard_batch)
      end

      def discard
        @artemis.facility(@facility_id)
                .batch(batch.id)
                .discard(@relationships.dig('action_result', 'data', 'id'))
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

        reason_note || ''
      end
    end
  end
end
