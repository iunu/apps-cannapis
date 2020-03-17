module MetrcService
  module Plant
    class Move < MetrcService::Base
      GROWTH_CYCLES = {
        clone: %i[clone vegetative],
        vegetative: %i[vegetative flowering],
        flowering: %i[flowering]
      }.freeze
      DEFAULT_MOVE_STEP = :change_growth_phase

      def call
        zone_name = normalize_growth_phase(zone['name'])
        next_step_name = determine_next_step_name(zone_name)

        log("Next step: #{next_step_name}. Batch ID #{@batch_id}, completion ID #{@completion_id}")

        options = {
          seeding_unit_id: @attributes.dig('options', 'seeding_unit_id'),
          batch: batch,
          zone_name: zone['name']
        }

        send(next_step_name, options)

        success!
      end

      def transaction
        @transaction ||= get_transaction(:move_batch, @attributes.merge(zone: zone))
      end

      def prior_move_transactions
        Transaction.where(
          'batch_id = ? AND type = ? AND vendor = ? AND id NOT IN (?)',
          @batch_id,
          :move_batch,
          :metrc,
          transaction.id
        )
      end

      def zone
        @zone ||= batch&.zone&.attributes
      end

      private

      def determine_next_step_name(zone_name)
        transactions = prior_move_transactions
        return DEFAULT_MOVE_STEP if transactions.count.zero?

        previous_zone = normalize_growth_phase(transactions.last.metadata.dig('zone', 'name'))

        # Does last move includes new move?
        is_included = is_included?(previous_zone, zone_name)
        log("Transactions: #{transactions.size}, Previous zone: #{previous_zone}, Zone is included: #{is_included}, Batch ID #{@batch_id}, completion ID #{@completion_id}")

        raise InvalidOperation, "Failed: Zone #{zone_name} is not a valid next zone for #{previous_zone}. Batch ID #{@batch_id}, completion ID #{@completion_id}" \
          unless is_included

        next_step(previous_zone, zone_name)
      end

      def is_included?(previous_zone, zone_name) # rubocop:disable Naming/PredicateName
        GROWTH_CYCLES[previous_zone.to_sym]&.include?(zone_name.to_sym)
      end

      def next_step(previous_zone = nil, new_zone = nil) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
        return DEFAULT_MOVE_STEP if previous_zone.nil? || new_zone.nil?

        new_zone.downcase!

        return DEFAULT_MOVE_STEP if previous_zone.include?('clone') && new_zone.include?('veg')

        return :move_plant_batches if previous_zone.include?('clone') && new_zone.include?('clone')

        return :move_plants if previous_zone.include?('veg') && new_zone.include?('veg')

        return :move_plants if previous_zone.include?('flow') && new_zone.include?('flow')

        return :change_growth_phases if previous_zone.include?('veg') && new_zone.include?('flow')

        DEFAULT_MOVE_STEP
      end

      def move_plants(options)
        items   = get_items(options[:seeding_unit_id])
        payload = items.map do |item|
          {
            Id: nil,
            Label: item.relationships.dig('barcode', 'data', 'id'),
            Location: options[:zone_name],
            ActualDate: @attributes.dig('start_time')
          }
        end

        call_metrc(:move_plants, [payload])
      end

      def move_plant_batches(options)
        batch = options[:batch]
        payload = {
          Name: batch.arbitrary_id,
          Location: options[:zone_name],
          MoveDate: @attributes.dig('start_time')
        }

        call_metrc(:move_plant_batches, [payload])
      end

      def change_growth_phase(options)
        batch        = options[:batch]
        seeding_unit = batch.seeding_unit.attributes
        items        = get_items(options[:seeding_unit_id])
        first_tag_id = items.first.id
        barcode      = items.find { |item| item.id == first_tag_id }.relationships.dig('barcode', 'data', 'id')
        payload      = {
          Name: batch.arbitrary_id,
          Count: batch.quantity.to_i,
          StartingTag: barcode,
          GrowthPhase: seeding_unit['name'],
          NewLocation: options[:zone_name],
          GrowthDate: @attributes.dig('start_time'),
          PatientLicenseNumber: nil
        }

        call_metrc(:change_growth_phase, [payload])
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
            NewLocation: options[:zone_name],
            GrowthDate: @attributes.dig('start_time')
          }
        end

        call_metrc(:change_growth_phases, payload)
      end

      def normalize_growth_phase(zone_name = nil)
        case zone_name
        when /veg/i
          'vegetative'
        when /flow/i
          'flowering'
        else
          'clone'
        end
      end
    end
  end
end
