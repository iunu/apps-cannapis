module MetrcService
  class Harvest < MetrcService::Base
    def call
      type            = @attributes.dig(:options, :harvest_type)
      seeding_unit_id = @attributes.dig(:options, :seeding_unit_id)
      items           = get_items(seeding_unit_id)
      next_step       = type == 'complete' ? :harvest_plants : :manicure_plants
      payload         = send "build_#{next_step}_payload", items, batch

      @logger.debug "[HARVEST] Metrc API request. URI #{@client.uri}, payload #{payload}"

      @client.send next_step, @integration.vendor_id, payload
      transaction.success = true

      transaction
    end

    private

    def transaction
      @transaction ||= get_transaction(:harvest_batch)
    end

    def build_manicure_plants_payload(items, batch) # rubocop:disable Lint/UnusedMethodArgument
      average_weight = calculate_average_weight(items)

      items.map do |item|
        {
          DryingRoom: @attributes.dig(:options, :zone_name),
          PatientLicenseNumber: nil,
          ActualDate: @attributes.dig(:start_time),
          Plant: item.relationships.dig('barcode', 'data', 'id'),
          Weight: average_weight,
          UnitOfWeight: item.attributes['secondary_harvest_unit'],
          HarvestName: nil
        }
      end
    end

    def build_harvest_plants_payload(items, batch)
      harvest_name = batch.arbitrary_id
      average_weight = calculate_average_weight(items)

      items.map do |item|
        {
          DryingRoom: @attributes.dig(:options, :zone_name),
          PatientLicenseNumber: nil,
          ActualDate: @attributes.dig(:start_time),
          Plant: item.relationships.dig('barcode', 'data', 'id'),
          Weight: average_weight,
          UnitOfWeight: item.attributes['harvest_unit'],
          HarvestName: harvest_name
        }
      end
    end

    def calculate_average_weight(items)
      items.inject(0.0) { |sum, item| sum + item.attributes['secondary_harvest_quantity'].to_f }.to_f / items.size
    end
  end
end
