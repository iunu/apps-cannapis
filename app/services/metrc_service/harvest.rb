require 'pp'

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
        batch = get_batch

        unless batch.crop == MetrcService::CROP
          @logger.error "[HARVEST] Failed: Crop is not #{CROP} but #{batch.crop}. Batch ID #{@batch_id}, completion ID #{@completion_id}"
          return
        end

        type            = @attributes.dig(:options, :harvest_type)
        seeding_unit_id = @attributes.dig(:options, :seeding_unit_id)
        items           = get_items(seeding_unit_id)
        next_step       = type == 'complete' ? 'harvest_plants' : 'manicure_plants'

        @logger.info "[HARVEST] Next step: #{next_step}. Batch ID #{@batch_id}, completion ID #{@completion_id}"
        send next_step, items, batch
        # transaction.success = true
      rescue => exception # rubocop:disable Style/RescueStandardError
        @logger.error "[HARVEST] Failed: batch ID #{@batch_id}, completion ID #{@completion_id}; #{exception.inspect}"
      ensure
        transaction.save
        @logger.debug "[HARVEST] Transaction: #{transaction.inspect}"
      end

      transaction
    end

    private

    def manicure_plants(items)
      date           = @attributes.dig(:start_time)
      room_name      = @attributes.dig(:options, :zone_name)
      average_weight = items.map { |item| item.attributes['secondary_harvest_quantity'].to_f }.reduce(&:+) / items.size
      payload = items.map do |item|
        {
          Plant: item.relationships.dig('barcode', 'data', 'id'),
          Weight: average_weight,
          UnitOfWeight: item.attributes['secondary_harvest_unit'],
          DryingRoom: room_name,
          HarvestName: nil,
          PatientLicenseNumber: nil,
          ActualDate: date
        }
      end

      @logger.debug "[MANICURE_PLANTS] Metrc API request. URI #{@client.uri}, payload #{payload}"
      @client.manicure_plants(@integration.vendor_id, payload)
    end

    def harvest_plants(items, batch)
      date           = @attributes.dig(:start_time)
      room_name      = @attributes.dig(:options, :zone_name)
      average_weight = items.map { |item| item.attributes['secondary_harvest_quantity'].to_f }.reduce(&:+) / items.size

      payload = items.map do |item|
        {
          Plant: item.relationships.dig('barcode', 'data', 'id'),
          Weight: average_weight,
          UnitOfWeight: item.attributes['harvest_unit'],
          DryingRoom: room_name,
          HarvestName: batch.attributes['arbitrary_id'],
          PatientLicenseNumber: nil,
          ActualDate: date
        }
      end

      @logger.debug "[HARVEST_PLANTS] Metrc API request. URI #{@client.uri}, payload #{payload}"
      @client.harvest_plants(@integration.vendor_id, payload)
    end
  end
end
