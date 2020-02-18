module MetrcService
  class Discard < MetrcService::Base
    delegate :seeding_unit, to: :batch

    def before
      super

      validate_seeding_unit!
    end

    def call
      plant_type = seeding_unit.item_tracking_method.nil? ? 'immature' : 'mature'

      payload = send("build_#{plant_type}_payload", discard, batch)
      log("Metrc API request. URI #{@client.uri}, payload #{payload}", :debug)

      if plant_type == 'immature'
        @client.destroy_plant_batches(@integration.vendor_id, payload)
      else
        @client.destroy_plants(@integration.vendor_id, payload)
      end

      transaction.success = true

      transaction
    end

    private

    def validate_seeding_unit!
      return unless ['preprinted', nil].include?(seeding_unit.item_tracking_method)

      raise InvalidBatch, "Failed: Seeding unit is not valid for Metrc #{seeding_unit.item_tracking_method}. " \
        "Batch ID #{@batch_id}, completion ID #{@completion_id}"
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
      reason_note = 'Does not meet internal QC'
      reason_note = "#{reason_type.capitalize}: #{reason_description}. #{@attributes.dig('options', 'note_content')}" if reason_type && reason_description

      reason_note
    end
  end
end
