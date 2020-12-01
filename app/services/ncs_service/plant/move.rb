module NcsService
  module Plant
    class Move < NcsService::Base
      GROWTH_CYCLES = {
        clone: %i[clone vegetative],
        vegetative: %i[vegetative flowering],
        flowering: %i[flowering]
      }.freeze

      DEFAULT_MOVE_STEP = :change_growth_phase

      def call
        log("Next step: #{next_step_name}. Batch ID #{@batch_id}, completion ID #{@completion_id}")

        send(next_step_name)

        success!
      end

      def transaction
        @transaction ||= get_transaction(:move_batch, @attributes.merge(zone: zone))
      end

      def zone
        @zone ||= batch&.zone&.attributes
      end

      def prior_move
        previous_move = batch_completions.select { |c| c.action_type == 'move' && c.id < @completion_id }
                                         .max_by { |comp| [comp.start_time, comp.id] }

        return if previous_move.nil?

        # calling get_completion here will ensure relationships are side loaded.
        get_completion(previous_move&.id)
      end
      memoize :prior_move

      def start_completion
        start = batch_completions.find { |comp| comp.action_type == 'start' || comp.action_type == 'split_start' }
        return if start.nil?

        # calling get_completion here will ensure relationships are side loaded.
        get_completion(start&.id)
      end
      memoize :start_completion

      private

      def next_step_name
        previous_completion = prior_move || start_completion
        return DEFAULT_MOVE_STEP if previous_completion.blank?

        previous_growth_phase = normalized_growth_phase(previous_completion.included&.dig(:sub_stages)&.first&.name)

        # Does last move includes new move?
        is_included = is_included?(previous_growth_phase, normalized_growth_phase)
        log("Previous completion: #{[previous_completion.id, previous_completion.action_type]}, Previous growth phase: #{previous_growth_phase}, Growth phase is included: #{is_included}, Batch ID #{@batch_id}, completion ID #{@completion_id}")

        raise InvalidOperation, "Failed: Substage #{normalized_growth_phase} is not a valid next phase for #{previous_growth_phase}. Batch ID #{@batch_id}, completion ID #{@completion_id}" \
          unless is_included

        next_step(previous_growth_phase, normalized_growth_phase)
      end

      def is_included?(previous_growth_phase, growth_phase) # rubocop:disable Naming/PredicateName
        GROWTH_CYCLES[previous_growth_phase.downcase.to_sym]&.include?(growth_phase.downcase.to_sym)
      end

      def next_step(previous_growth_phase = nil, new_growth_phase = nil) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
        return DEFAULT_MOVE_STEP if previous_growth_phase.nil? || new_growth_phase.nil?

        new_growth_phase.downcase!

        return :move_plants if previous_growth_phase.include?('clone') && new_growth_phase.include?('clone')

        return :move_plants if previous_growth_phase.include?('veg') && new_growth_phase.include?('veg')

        return :move_plants if previous_growth_phase.include?('flow') && new_growth_phase.include?('flow')

        DEFAULT_MOVE_STEP
      end

      def move_plants
        payload = barcodes.map do |barcode|
          {
            Id: nil,
            Label: barcode,
            RoomName: location_name
          }
        end

        call_ncs(:plant, :move, payload)
      end

      def change_growth_phase
        payload = {
          Label: batch_tag,
          NewTag: immature? ? nil : first_barcode,
          GrowthPhase: normalized_growth_phase,
          NewRoom: location_name,
          GrowthDate: start_time
        }

        call_ncs(:plant, :change_growth_phases, payload)
      end

      def start_time
        @attributes['start_time']
      end

      def immature?
        normalized_growth_phase != 'Flowering'
      end

      def normalized_growth_phase(input = nil)
        input ||= batch.zone.sub_stage.name

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

      def first_barcode
        return nil if items.blank?

        ordered_items = items.sort_by { |item| item['id'] }
        ordered_items.first['barcode']
      end
    end
  end
end
