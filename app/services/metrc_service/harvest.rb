module MetrcService
  class Harvest < MetrcService::Base
    def call
      @logger.info "[HARVEST] Started: batch ID #{@batch_id}, completion ID #{@completion_id}"
      transaction = get_transaction :harvest_batch

      if transaction.success
        @logger.error "[HARVEST] Success: transaction previously performed. #{transaction.inspect}"
        return
      end

      begin
        @integration.account.refresh_token_if_needed
        batch = @batch ? @batch : get_batch

        unless batch.crop == MetrcService::CROP
          @logger.error "[HARVEST] Failed: Crop is not #{CROP} but #{batch.crop}. Batch ID #{@batch_id}, completion ID #{@completion_id}"
          return
        end

        type            = @attributes.dig(:options, :harvest_type)
        seeding_unit_id = @attributes.dig(:options, :seeding_unit_id)
        items           = get_items(seeding_unit_id)
        next_step       = type == 'complete' ? :harvest_plants : :manicure_plants
        payload         = send "build_#{next_step}_payload", items, batch

        @logger.debug "[HARVEST] Metrc API request. URI #{@client.uri}, payload #{payload}"

        @client.send next_step, @integration.vendor_id, payload
        transaction.success = true
        @logger.info "[HARVEST] Success: batch ID #{@batch_id}, completion ID #{@completion_id}; #{payload}"
      rescue => exception # rubocop:disable Style/RescueStandardError
        @logger.error "[HARVEST] Failed: batch ID #{@batch_id}, completion ID #{@completion_id}; #{exception.inspect}"
      ensure
        transaction.save
        @logger.debug "[HARVEST] Transaction: #{transaction.inspect}"
      end

      transaction
    end

    private

    def build_manicure_plants_payload(items, batch) # rubocop:disable Lint/UnusedMethodArgument
      average_weight = calculate_average_weight(items)
      payload = items.map do |item|
        base.merge(Plant: item.relationships.dig('barcode', 'data', 'id'),
                   Weight: average_weight,
                   UnitOfWeight: item.attributes['secondary_harvest_unit'],
                   DryingRoom: room_name)
      end

      payload
    end

    def build_harvest_plants_payload(items, batch)
      average_weight = calculate_average_weight(items)
      harvest_name   = batch.arbitrary_id
      payload = items.map do |item|
        base.merge(Plant: item.relationships.dig('barcode', 'data', 'id'),
                   Weight: average_weight,
                   UnitOfWeight: item.attributes['harvest_unit'],
                   DryingRoom: room_name,
                   HarvestName: harvest_name)
      end

      payload
    end

    def build_base_payload
      {
        DryingRoom: @attributes.dig(:options, :zone_name),
        PatientLicenseNumber: nil,
        ActualDate: @attributes.dig(:start_time)
      }
    end

    def calculate_average_weight(items)
      items.inject { |sum, item| sum + item.attributes['secondary_harvest_quantity'].to_f }.to_f / items.size
    end
  end
end
