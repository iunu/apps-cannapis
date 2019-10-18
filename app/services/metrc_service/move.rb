require 'pp'

module MetrcService
  class Move < MetrcService::Base
    GROWTH_CYCLES = {
      clone: %w[clone vegetation],
      vegetation: %w[vegetation flowering],
      flowering: %w[flowering]
    }.freeze

    def call
      @logger.info "[MOVE] Started: batch ID #{@batch_id}, completion ID #{@completion_id}"
      transaction = get_transaction :move_batch

      if transaction.success
        @logger.error "[MOVE] Success: transaction previously performed. #{transaction.inspect}"
        return
      end

      begin
        @integration.account.refresh_token_if_needed
        batch = get_batch

        unless batch.crop == MetrcService::CROP
          @logger.error "[MOVE] Failed: Crop is not #{CROP} but #{batch.crop}. Batch ID #{@batch_id}, completion ID #{@completion_id}"
          return
        end

        zone            = batch.client.objects['zones'][@attributes.dig(:options, :zone_id).to_i]
        zone_name       = normalize_growth_phase(zone.attributes['name'])
        seeding_unit_id = @attributes.dig(:options, :seeding_unit_id)
        transactions    = Transaction.where('batch_id = ? AND type = ? AND vendor = ? AND id NOT IN (?)', @batch_id, :move_batch, :metrc, transaction.id)
        next_step_name  = 'change_growth_phase'

        if transactions.size.positive?
          previous_zone = normalize_growth_phase(transactions.last.metadata[:zone_name])
          # Does last move includes new move?
          is_included = GROWTH_CYCLES[previous_zone.to_sym]&.include?(zone_name.to_sym)
          @logger.info "[MOVE] Transactions: #{transactions.size}, Previous zone: #{previous_zone}, Zone is included: #{is_included}, Batch ID #{@batch_id}, completion ID #{@completion_id}"

          unless is_included
            @logger.error "[MOVE] Failed: Zone #{zone_name} is not a valid next zone for #{previous_zone}. Batch ID #{@batch_id}, completion ID #{@completion_id}"
            return
          end

          next_step_name = case true
                           when previous_zone&.include?('clone') && zone_name&.downcase.include?('veg') then 'change_growth_phase'
                           when previous_zone&.include?('clone') && zone_name&.downcase.include?('clone') then 'move_plant_batches'
                           when previous_zone&.include?('veg') && (zone_name&.downcase.include?('flower') || zone_name&.downcase.include?('veg')) then 'move_plants'
                           when previous_zone&.include?('veg') && zone_name&.downcase.include?('flower') then 'change_growth_phases'
                           else 'change_growth_phase'
                           end
        end

        @logger.info "[MOVE] Next step: #{next_step_name}. Batch ID #{@batch_id}, completion ID #{@completion_id}"
        send next_step_name, seeding_unit_id: seeding_unit_id, batch: batch, zone_name: zone_name
        transaction.success = true
      rescue => exception # rubocop:disable Style/RescueStandardError
        @logger.error "[MOVE] Failed: batch ID #{@batch_id}, completion ID #{@completion_id}; #{exception}"
        exception.backtrace.each { |line| @logger.error line }
      ensure
        transaction.save
      end

      transaction
    end

    private

    def move_plants(seeding_unit_id: nil, zone_name: nil)
      date    = @attributes.dig(:start_time)
      items   = get_items(seeding_unit_id)
      payload = items.map do |item|
        {
          Id: nil,
          Label: item.dig('relationships', 'barcode', 'data', 'id'),
          Room: zone_name,
          ActualDate: date
        }
      end

      @logger.debug "[MOVE_PLANTS] Metrc API request. URI #{@client.uri}, payload #{payload}"
      @client.move_plants(@integration.vendor_id, payload)
    end

    def move_plant_batches(batch: {}, zone_name: nil)
      payload = {
        Name: batch.dig('attributes', 'arbitrary_id'),
        Room: zone_name,
        MoveDate: @attributes.dig(:start_time)
      }

      @logger.debug "[MOVE_PLANT_BATCHES] Metrc API request. URI #{@client.uri}, payload #{payload}"
      @client.move_plant_batches(@integration.vendor_id, payload)
    end

    def change_growth_phase(batch: {}, zone_name: nil, seeding_unit_id: nil)
      date         = @attributes.dig(:start_time)
      seeding_unit = batch.seeding_unit.name
      items        = batch.client.objects['items']
      first_tag_id = items.keys.last
      barcode      = items[first_tag_id].relationships.dig('barcode', 'data', 'id')
      payload      = {
        Name: batch.arbitrary_id,
        Count: batch.quantity.to_i,
        StartingTag: barcode,
        GrowthPhase: seeding_unit['name'],
        NewRoom: zone_name,
        GrowthDate: date,
        PatientLicenseNumber: nil
      }

      @logger.debug "[CHANGE_GROWTH_PHASE] Metrc API request. URI #{@client.uri}, payload #{payload}"
      @client.change_growth_phase(@integration.vendor_id, [payload])
    end

    def change_growth_phases(seeding_unit_id: nil, zone_name: nil, batch: {})
      date         = @attributes.dig(:start_time)
      seeding_unit = batch.included.select { |relationship| relationship['id'] == seeding_unit_id && relationship['type'] == 'seeding_units' }.first['attributes']
      items        = get_items(seeding_unit_id)
      payload      = items.map do |item|
        {
          Id: nil,
          Label: item.dig('relationships', 'barcode', 'data', 'id'),
          NewTag: seeding_unit['name'], # TODO: Fix me
          GrowthPhase: seeding_unit['name'], # TODO: Fix me
          NewRoom: zone_name,
          GrowthDate: date
        }
      end

      @logger.debug "[CHANGE_GROWTH_PHASES] Metrc API request. URI #{@client.uri}, payload #{payload}"
      @client.change_growth_phases(@integration.vendor_id, payload)
    end

    def normalize_growth_phase(zone_name)
      return 'vegetative' if zone_name&.downcase.include?('veg')

      return 'flowering' if zone_name&.downcase.include?('flow')

      'clone'
    end
  end
end
