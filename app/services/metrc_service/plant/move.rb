module MetrcService
  module Plant
    class Move < Base

      DEFAULT_MOVE_STEP = :change_growth_phase

      def call
        log("Next step: #{next_step_name}. Batch ID #{@batch_id}, completion ID #{@completion_id}")

        send(next_step_name)

        success!
      end

      def transaction
        @transaction ||= get_transaction(:move_batch, @attributes)
      end

      def prior_move
        previous_move = batch.completions.select do |comp|
          comp.action_type == 'move' && comp.id < @completion_id
        end.max_by(&:start_time)

        return if previous_move.nil?

        # calling get_completion here will ensure relationships are side loaded.
        get_completion(previous_move.id)
      end
      memoize :prior_move

      def prior_start
        previous_start = batch.completions.select do |comp|
          comp.action_type == 'start' && comp.id < @completion_id
        end.max_by(&:start_time)
        return if previous_start.nil?

        # calling get_completion here will ensure relationships are side loaded.
        get_completion(previous_start&.id)
      end
      memoize :prior_start

      private

      def within_phases?(zone_name, expected_zones)
        return false unless zone_name && expected_zones

        expected_zones.any? { |phase| zone_name.include?(phase) }
      end

      def current_completion
        get_completion(@completion_id)
      end
      memoize :current_completion

      def next_step_name
        previous_completion = prior_move || prior_start
        step = next_step(previous_completion, current_completion)

        return unless step

        metadata = transaction.metadata
        substage = get_substage
        metadata[:sub_stage] = substage
        metadata[:next_step] = step
        transaction.update(metadata: metadata)

        step
      end
      memoize :next_step_name

      def next_step(previous_completion = nil, current_completion = nil) # rubocop:disable Metrics/PerceivedComplexity
        return DEFAULT_MOVE_STEP if previous_completion.nil? || current_completion.nil?

        new_growth_phase = growth_phase_for_completion(current_completion)
        previous_growth_phase = growth_phase_for_completion(previous_completion)

        # Yeah, I don't like this either.
        previous_completion_had_barcodes = items_have_barcodes?(previous_completion.included&.dig(:seeding_units)&.first&.item_tracking_method)
        current_completion_has_barcodes  = items_have_barcodes?(current_completion.included&.dig(:seeding_units)&.first&.item_tracking_method)
        has_no_barcodes = !previous_completion_had_barcodes && !current_completion_has_barcodes
        moved_to_barcodes = !previous_completion_had_barcodes && current_completion_has_barcodes
        already_had_barcodes = previous_completion_had_barcodes && current_completion_has_barcodes

        return DEFAULT_MOVE_STEP if previous_growth_phase.nil? || new_growth_phase.nil?

        return :move_plants if is_a_split? && already_had_barcodes

        # We need this in order to avoid splits when no barcodes are available
        return if is_a_split? && !already_had_barcodes

        return :move_plant_batches if has_no_barcodes

        return :change_growth_phase if (previous_growth_phase.include?('Veg') && new_growth_phase.include?('Veg')) && moved_to_barcodes

        return :change_growth_phase if (!previous_growth_phase.include?('Flow') && new_growth_phase.include?('Flow')) && moved_to_barcodes

        return :change_plants_growth_phases if (previous_growth_phase.include?('Flow') && new_growth_phase.include?('Flow')) && already_had_barcodes

        return :change_plants_growth_phases if (previous_growth_phase.include?('Veg') && new_growth_phase.include?('Flow')) && already_had_barcodes

        return :move_harvest if previous_growth_phase.include?('Flow') && within_phases?(new_growth_phase, %w[Curing Cure Dry Drying]) && already_had_barcodes

        return :move_plants if already_had_barcodes

        DEFAULT_MOVE_STEP
      end
      memoize :next_step

      def move_plants
        # TODO: extract barcodes into it's own method
        barcodes = if is_a_split?
                     current_completion.options['barcode']
                   else
                     # TODO: Filter items based on completion content
                     items.select { |item| current_completion.options&.dig('item_ids').include?(item.id) }
                          .map { |item| item&.relationships&.dig('barcode', 'data', 'id') }
                   end

        payload = barcodes.map do |barcode|
          {
            Id: nil,
            Label: barcode,
            Location: location_name,
            ActualDate: start_time
          }
        end

        call_metrc(:move_plants, payload)
      end

      def move_plant_batches
        payload = {
          Name: batch_tag,
          Location: location_name,
          MoveDate: start_time
        }

        call_metrc(:move_plant_batches, [payload])
      end

      def change_growth_phase
        phase = current_growth_phase || 'Flowering'
        payload = {
          Name: batch_tag,
          Count: quantity,
          StartingTag: immature?(phase) ? nil : barcode,
          GrowthPhase: phase,
          NewLocation: location_name,
          GrowthDate: start_time,
          PatientLicenseNumber: nil
        }

        call_metrc(:change_growth_phase, [payload])
      end

      def change_plants_growth_phases
        payload = items.map do |item|
          {
            Id: nil,
            Label: item&.relationships&.dig('barcode', 'data', 'id'),
            NewLabel: nil,
            GrowthPhase: current_growth_phase,
            NewLocation: location_name,
            NewRoom: location_name,
            GrowthDate: start_time
          }
        end

        call_metrc(:change_plant_growth_phase, payload)
      end

      # if this is a move harvest a generated completion of 'Wet Weight' should come next
      # This will be reported to metrc via the wet_weight resource service.
      def move_harvest; end

      def items
        @items ||= get_items(batch.seeding_unit.id)
      end

      def start_time
        @attributes['start_time']
      end

      def immature?(phase = nil)
        phase != 'Flowering'
      end

      def normalized_growth_phase(input = nil)
        return unless input

        case input
        when /veg/i
          'Vegetative'
        when /flow/i
          'Flowering'
        when /cur(e|ing)/i
          'Curing'
        when /dry/i
          'Drying'
        else
          'Clone'
        end
      end

      def quantity
        @attributes.dig('options', 'quantity')&.to_i
      end

      def barcode
        ordered_items = items.sort_by(&:id)
        ordered_items&.first&.relationships&.dig('barcode', 'data', 'id')
      end

      def items_have_barcodes?(tracking_method = nil)
        !tracking_method.nil? && tracking_method != 'none'
      end

      def get_substage(comp = nil)
        comp ||= current_completion
        comp&.included&.dig(:sub_stages)&.first&.name
      end

      def growth_phase_for_completion(comp)
        normalized_growth_phase(get_substage(comp))
      end

      def current_growth_phase
        growth_phase_for_completion(current_completion)
      end
      memoize :current_growth_phase

      def location_name
        current_completion&.included&.dig(:zones)&.first&.name || super
      end

      def is_a_split?
        current_completion.action_type == 'split'
      end
    end
  end
end
