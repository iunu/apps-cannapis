module MetrcService
  class Discard < MetrcService::Base
    def call
      @logger.info "[BATCH_DISCARD] Started: batch ID #{@batch_id}, completion ID #{@completion_id}"
      transaction = get_transaction :discard_batch

      if transaction.success
        @logger.error "[BATCH_DISCARD] Success: transaction previously performed. #{transaction.inspect}"
        return transaction
      end

      begin
        @integration.account.refresh_token_if_needed
        batch        = @batch || get_batch
        seeding_unit = batch.seeding_unit

        unless batch.crop == MetrcService::CROP
          @logger.warn "[MOVE] Failed: Crop is not #{CROP} but #{batch.crop}. Batch ID #{@batch_id}, completion ID #{@completion_id}"
          return
        end

        unless seeding_unit.item_tracking_method == 'preprinted' || seeding_unit.item_tracking_method.nil?
          @logger.warn "[MOVE] Failed: Seeding unit is not valid for Metrc #{seeding_unit.item_tracking_method}. Batch ID #{@batch_id}, completion ID #{@completion_id}"
          return
        end

        plant_type = seeding_unit.item_tracking_method.nil? ? 'immature' : 'mature'
        discard = @artemis.facility(@facility_id)
                          .batch(batch.id)
                          .discard(@relationships.dig('action_result', 'data', 'id'))

        payload = send "build_#{plant_type}_payload", discard, batch
        @logger.debug "[BATCH_DISCARD] Metrc API request. URI #{@client.uri}, payload #{payload}"

        if plant_type == 'immature'
          @client.destroy_plant_batches(@integration.vendor_id, payload)
        else
          @client.destroy_plants(@integration.vendor_id, payload)
        end

        transaction.success = true
        @logger.info "[BATCH_DISCARD] Success: batch ID #{@batch_id}, completion ID #{@completion_id}; #{payload}"
      rescue => exception # rubocop:disable Style/RescueStandardError
        @logger.error "[BATCH_DISCARD] Failed: batch ID #{@batch_id}, completion ID #{@completion_id}; #{exception.inspect}"
      ensure
        transaction.save
        @logger.debug "[BATCH_DISCARD] Transaction: #{transaction.inspect}"
      end

      transaction
    end

    private

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
