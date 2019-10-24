module MetrcService
  class Start < MetrcService::Base
    def call
      @logger.info "[METRC_START] Started: batch ID #{@batch_id}, completion ID #{@completion_id}"
      transaction = get_transaction :start_batch

      if transaction.success
        @logger.error "[METRC_START] Success: transaction previously performed. #{transaction.inspect}"
        return transaction
      end

      begin
        @integration.account.refresh_token_if_needed
        batch = get_batch

        unless batch.crop == MetrcService::CROP
          @logger.error "[METRC_START] Failed: Crop is not #{CROP} but #{batch.crop}. Batch ID #{@batch_id}, completion ID #{@completion_id}"
          return
        end

        payload = build_start_payload(batch)

        @logger.debug "[METRC_START] Metrc API request. URI #{@client.uri}, payload #{payload}"

        @client.create_plant_batches(@integration.vendor_id, [payload])
        transaction.success = true
        @logger.info "[METRC_START] Success: batch ID #{@batch_id}, completion ID #{@completion_id}; #{payload}"
      rescue => exception # rubocop:disable Style/RescueStandardError
        @logger.error "[METRC_START] Failed: batch ID #{@batch_id}, completion ID #{@completion_id}; #{exception.inspect}"
      ensure
        transaction.save
        @logger.debug "[METRC_START] Transaction: #{transaction.inspect}"
      end

      transaction
    end

    private

    def build_start_payload(batch)
      {
        Name: @attributes.dig('options', 'tracking_barcode'),
        Type: batch.zone.attributes.dig('seeding_unit', 'name') || 'Clone',
        Count: batch.attributes['quantity']&.to_i || 1,
        Strain: batch.attributes['crop_variety'],
        Room: batch.attributes['zone_name'] || 'Germination',
        PatientLicenseNumber: nil,
        ActualDate: batch.attributes['seeded_at']
      }
    end
  end
end
