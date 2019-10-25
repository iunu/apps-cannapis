module MetrcService
  class Discard < MetrcService::Base
    def call
      @logger.info "[BATCH_DISCARD] Started: batch ID #{@batch_id}, completion ID #{@completion_id}"
      transaction = get_transaction :discard_batch

      if transaction.success
        @logger.error "[BATCH_DISCARD] Success: transaction previously performed. #{transaction.inspect}"
        return
      end

      begin
        @integration.account.refresh_token_if_needed
        batch        = get_batch
        seeding_unit = batch.seeding_unit

        unless batch.crop == MetrcService::CROP
          @logger.warn "[MOVE] Failed: Crop is not #{CROP} but #{batch.crop}. Batch ID #{@batch_id}, completion ID #{@completion_id}"
          return
        end

        unless seeding_unit.item_tracking_method == 'preprinted'
          @logger.warn "[MOVE] Failed: Seeding unit is not valid for Metrc #{seeding_unit.item_tracking_method}. Batch ID #{@batch_id}, completion ID #{@completion_id}"
          return
        end

        discard = @artemis.facility(@facility_id)
                          .batch(batch.id)
                          .discard(@relationships.dig('action_result', 'data', 'id'))
        payload = build_discard_payload(discard, batch.arbitrary_id)

        @logger.debug "[BATCH_DISCARD] Metrc API request. URI #{@client.uri}, payload #{payload}"

        @client.destroy_plant_batches(@integration.vendor_id, [payload])
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

    def build_discard_payload(discard, batch_name)
      quantity      = discard.attributes['quantity']&.to_i
      reason_type   = discard.attributes['reason_type']
      reason_description = discard.attributes['reason_description']
      reason_note = 'Does not meet internal QC'
      reason_note = "#{reason_type.capitalize}: #{reason_description}. #{@attributes.dig('options', 'note_content')}" if type && description

      {
        PlantBatch: batch_name,
        Count: quantity,
        ReasonNote: reason_note,
        ActualDate: discard.attributes['discarded_at']
      }
    end
  end
end
