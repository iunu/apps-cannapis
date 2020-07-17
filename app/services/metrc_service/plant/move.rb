module MetrcService
  module Plant
    class Move < Base
      extend Memoist

      DEFAULT_MOVE_STEP = :change_growth_phase

      def call
        log("Next step: #{next_step_name}. Batch ID #{@batch_id}, completion ID #{@completion_id}")

        send(next_step_name)

        handle_resources

        success!
      end

      def transaction
        @transaction ||= get_transaction(:move_batch, @attributes.merge(sub_stage: batch&.zone&.sub_stage&.attributes))
      end

      def prior_move
        previous_move = Transaction.where(
          'batch_id = ? AND type = ? AND vendor = ? AND id NOT IN (?)',
          @batch_id,
          :move_batch,
          :metrc,
          transaction.id
        ).limit(1).order('created_at desc').first

        return if previous_move.nil?

        @prior_move = batch.completion(previous_move&.completion_id,
                                       include: 'zone,barcodes,sub_zone,action_result,crop_batch_state.seeding_unit')
      end
      memoize :prior_move

      private

      def next_step_name
        @completion = batch.completion(@completion_id,
                                       include: 'zone,barcodes,sub_zone,action_result,crop_batch_state.seeding_unit')

        next_step(prior_move, @completion)
      end
      memoize :next_step_name

      def next_step(previous_completion = nil, completion = nil) # rubocop:disable Metrics/PerceivedComplexity
        return DEFAULT_MOVE_STEP if previous_completion.nil? || completion.nil?

        @prior_move ||= previous_completion
        new_growth_phase = normalized_growth_phase(completion&.options['zone_name'])

        # Yeah, I don't like this either.
        previous_item_tracking_method_has_barcodes = items_have_barcodes?(previous_completion.included&.dig(:seeding_units)&.first&.item_tracking_method)
        current_item_tracking_method_has_barcodes  = items_have_barcodes?(completion.included&.dig(:seeding_units)&.first&.item_tracking_method)
        has_no_barcodes = !previous_item_tracking_method_has_barcodes && !current_item_tracking_method_has_barcodes
        moved_to_barcodes = !previous_item_tracking_method_has_barcodes && current_item_tracking_method_has_barcodes
        already_had_barcodes = previous_item_tracking_method_has_barcodes && current_item_tracking_method_has_barcodes

        return DEFAULT_MOVE_STEP if previous_growth_phase.nil? || new_growth_phase.nil?

        return :move_plant_batches if has_no_barcodes

        return :change_growth_phase if (previous_growth_phase.include?('Veg') && new_growth_phase.include?('Veg')) && moved_to_barcodes

        return :change_growth_phase if (!previous_growth_phase.include?('Flow') && new_growth_phase.include?('Flow')) && moved_to_barcodes

        return :change_plants_growth_phases if (previous_growth_phase.include?('Flow') && new_growth_phase.include?('Flow')) && already_had_barcodes

        return :move_plants if already_had_barcodes

        DEFAULT_MOVE_STEP
      end
      memoize :next_step

      def move_plants
        payload = items.map do |item|
          {
            Id: nil,
            Label: item&.relationships&.dig('barcode', 'data', 'id'),
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
        payload = {
          Name: batch_tag,
          Count: quantity,
          StartingTag: immature? ? nil : barcode,
          GrowthPhase: normalized_growth_phase(@completion&.options&.dig('zone_name')),
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
            GrowthPhase: normalized_growth_phase(@completion&.options&.dig('zone_name')),
            NewLocation: location_name,
            NewRoom: location_name,
            GrowthDate: start_time
          }
        end

        call_metrc(:change_plant_growth_phase, payload)
      end

      def items
        @items ||= get_items(batch.seeding_unit.id)
      end

      def start_time
        @attributes.dig('start_time')
      end

      def immature?
        normalized_growth_phase != 'Flowering'
      end

      def normalized_growth_phase(input = nil)
        return unless input

        case input
        when /veg/i
          'Vegetative'
        when /flow/i
          'Flowering'
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

      def previous_growth_phase
        normalized_growth_phase(@prior_move.options['zone_name'])
      end
    end
  end
end
