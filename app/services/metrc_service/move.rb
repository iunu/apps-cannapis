module MetrcService
  class Move < MetrcService::Base
    GROWTH_CYCLES = {
      clone: %i[clone vegetative],
      vegetative: %i[vegetative flowering],
      flowering: %i[flowering]
    }.freeze
    DEFAULT_MOVE_STEP = :change_growth_phase

    def call
      @logger.info "[MOVE] Started: batch ID #{@batch_id}, completion ID #{@completion_id}"

      begin
        @integration.account.refresh_token_if_needed
        batch       = @batch ? @batch : get_batch
        zone        = batch.zone.attributes
        transaction = get_transaction :move_batch, @attributes.merge(zone: zone)

        if transaction.success
          @logger.error "[MOVE] Success: transaction previously performed. #{transaction.inspect}"
          return
        end

        unless batch.crop == MetrcService::CROP
          @logger.error "[MOVE] Failed: Crop is not #{CROP} but #{batch.crop}. Batch ID #{@batch_id}, completion ID #{@completion_id}"
          return
        end

        zone_name       = normalize_growth_phase(zone['name'])
        seeding_unit_id = @attributes.dig('options', 'seeding_unit_id')
        transactions    = Transaction.where('batch_id = ? AND type = ? AND vendor = ? AND id NOT IN (?)', @batch_id, :move_batch, :metrc, transaction.id)
        next_step_name  = DEFAULT_MOVE_STEP

        if transactions.size.positive?
          previous_zone = normalize_growth_phase(transactions.last.metadata.dig('zone', 'name'))
          # Does last move includes new move?
          is_included = GROWTH_CYCLES[previous_zone.to_sym]&.include?(zone_name.to_sym)
          @logger.info "[MOVE] Transactions: #{transactions.size}, Previous zone: #{previous_zone}, Zone is included: #{is_included}, Batch ID #{@batch_id}, completion ID #{@completion_id}"

          unless is_included
            @logger.error "[MOVE] Failed: Zone #{zone_name} is not a valid next zone for #{previous_zone}. Batch ID #{@batch_id}, completion ID #{@completion_id}"
            return
          end

          next_step_name = next_step(previous_zone, zone_name)
        end

        @logger.info "[MOVE] Next step: #{next_step_name}. Batch ID #{@batch_id}, completion ID #{@completion_id}"
        options = {
          seeding_unit_id: seeding_unit_id,
          batch: batch,
          zone_name: zone['name']
        }

        send next_step_name, options
        transaction.success = true
      rescue => exception # rubocop:disable Style/RescueStandardError
        @logger.error "[MOVE] Failed: batch ID #{@batch_id}, completion ID #{@completion_id}; #{exception}"
      ensure
        transaction.save
        @logger.debug "[MOVE] Transaction: #{transaction.inspect}"
      end

      transaction
    end

    private

    def next_step(previous_zone, new_zone)
      return DEFAULT_MOVE_STEP if previous_zone.nil? || new_zone.nil?

      new_zone.downcase!

      return DEFAULT_MOVE_STEP if previous_zone.include?('clone') && new_zone.include?('veg')

      return :move_plant_batches if previous_zone.include?('clone') && new_zone.include?('clone')

      return :move_plants if previous_zone.include?('veg') && %w[flow veg].any? { |room| new_zone.include? room }

      return :change_growth_phases if previous_zone.include?('veg') && new_zone.include?('flow')

      DEFAULT_MOVE_STEP
    end

    def move_plants(options)
      items   = get_items(options[:seeding_unit_id])
      payload = items.map do |item|
        {
          Id: nil,
          Label: item.relationships.dig('barcode', 'data', 'id'),
          Room: options[:zone_name],
          ActualDate: @attributes.dig('start_time')
        }
      end

      @logger.debug "[MOVE_PLANTS] Metrc API request. URI #{@client.uri}, payload #{payload}"
      @client.move_plants(@integration.vendor_id, [payload])
    end

    def move_plant_batches(options)
      batch = options[:batch]
      payload = {
        Name: batch.arbitrary_id,
        Room: options[:zone_name],
        MoveDate: @attributes.dig('start_time')
      }

      @logger.debug "[MOVE_PLANT_BATCHES] Metrc API request. URI #{@client.uri}, payload #{payload}"
      @client.move_plant_batches(@integration.vendor_id, [payload])
    end

    def change_growth_phase(options)
      batch        = options[:batch]
      seeding_unit = batch.seeding_unit.attributes
      items        = batch.client.objects['items']
      first_tag_id = items.keys.last
      barcode      = items[first_tag_id].relationships.dig('barcode', 'data', 'id')
      payload      = {
        Name: batch.arbitrary_id,
        Count: batch.quantity.to_i,
        StartingTag: barcode,
        GrowthPhase: seeding_unit['name'],
        NewRoom: options[:zone_name],
        GrowthDate: @attributes.dig('start_time'),
        PatientLicenseNumber: nil
      }

      @logger.debug "[CHANGE_GROWTH_PHASE] Metrc API request. URI #{@client.uri}, payload #{payload}"
      @client.change_growth_phase(@integration.vendor_id, [payload])
    end

    def change_growth_phases(options)
      batch        = options[:batch]
      seeding_unit = batch.zone.attributes['seeding_unit']
      items        = get_items(options[:seeding_unit_id])
      payload      = items.map do |item|
        {
          Id: nil,
          Label: item.relationships.dig('barcode', 'data', 'id'),
          NewTag: seeding_unit['name'], # TODO: Fix me
          GrowthPhase: seeding_unit['name'], # TODO: Fix me
          NewRoom: options[:zone_name],
          GrowthDate: @attributes.dig('start_time')
        }
      end

      @logger.debug "[CHANGE_GROWTH_PHASES] Metrc API request. URI #{@client.uri}, payload #{payload}"
      @client.change_growth_phases(@integration.vendor_id, payload)
    end

    def normalize_growth_phase(zone_name)
      return 'clone' if zone_name.nil?

      return 'vegetative' if zone_name.downcase&.include?('veg')

      return 'flowering' if zone_name.downcase&.include?('flow')

      'clone'
    end
  end
end
