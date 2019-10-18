require 'pp'

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
                          .discard(@relationships.dig('action_result', 'data', 'id'))
        payload = build_discard_payload(discard)
        @logger.debug "[BATCH_DISCARD] Metrc API request. URI #{@client.uri}, payload #{payload}"
        @client.destroy_plant_batches(@integration.vendor_id, [payload])
        transaction.success = true
        @logger.info "[BATCH_DISCARD] Success: batch ID #{@batch_id}, completion ID #{@completion_id}; #{payload}"
      rescue => exception # rubocop:disable Style/RescueStandardError
        pp exception.backtrace
        @logger.error "[BATCH_DISCARD] Failed: batch ID #{@batch_id}, completion ID #{@completion_id}; #{exception.inspect}"
      ensure
        transaction.save
        @logger.debug "[BATCH_DISCARD] Transaction: #{transaction.inspect}"
      end

      transaction
    end

    private

    def build_discard_payload(discard)
      reason_note = 'Does not meet internal QC'
      reason_note = "#{discard.attributes['reason_type'].capitalize}: #{discard.attributes['reason_description']}" if discard.attributes['reason_type'] && discard.attributes['reason_description']

      {
        PlantBatch: discard.id,
        Count: discard.attributes['quantity']&.to_i,
        ReasonNote: reason_note,
        ActualDate: discard.attributes['dumped_at']
      }
    end
  end
end
