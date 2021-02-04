module MetrcService
  module Plant
    class Discard < MetrcService::Base
      NOT_SPECIFIED = 'Not Specified'.freeze

      # TODO: use `GET plants/v1/waste/reasons` to fetch appropriate reason names per facilitiy rather then hard code them here.
      # Current key => UI translation values (what the user sees in artemis) in portal as of 02/03/2021
      #
      # cannabis_growth_growth_stage:
      #   reason_options:  disease: ''
      #     pests: ''
      #     surplus: Pruning
      #     underperformed: Failure to Thrive
      #     mandated: Mandated Destruction
      #     undesirable: Male Plants
      #     contamination: Contamination
      #     damage: Damage
      #     pesticides: Pesticides
      #     other: Other
      #     undefined: Not specified
      MA_WASTE_REASON_MAP = {
        surplus: 'Trimming',
        underperformed: 'Waste',
        mandated: 'Waste',
        undesirable: 'Waste',
        contamination: 'Spoilage',
        damage: 'Spoilage',
        pesticides: 'Spoilage',
        other: 'Waste',
        undefined: 'Waste'
      }.freeze

      MO_WASTE_REASON_MAP = {
        surplus: 'Trimming/Prunning',
        underperformed: 'Damaged',
        mandated: 'Mandated State Destruction',
        undesirable: 'Contamination',
        contamination: 'Contamination',
        damage: 'Damaged',
        pesticides: 'Contamination',
        other: 'Spoilage',
        undefined: 'Spoilage'
      }.freeze

      CA_WASTE_REASON_MAP = {
        surplus: 'Pruning',
        underperformed: 'Failure to Thrive',
        mandated: 'Mandated Destruction',
        undesirable: 'Male Plants',
        contamination: 'Contamination',
        damage: 'Damage',
        pesticides: 'Pesticides',
        other: 'Damage',
        undefined: 'Damage'
      }.freeze

      STATE_WASTE_REASON_MAP = {
        ma: MA_WASTE_REASON_MAP,
        mo: MO_WASTE_REASON_MAP,
        ca: CA_WASTE_REASON_MAP
      }.freeze

      # TODO: implement waste method in portal, for now we default to undefined value.
      # - use `GET /plants/v1/waste/methods` to fetch appropriate values per state rather then hard code them here.
      #   methods up-to-date as of 02/02/21
      MA_WASTE_METHOD_MAP = {
        compost: 'Compost',
        self_hauler: 'Made Unrecognizable & Unusable',
        waste_hauler: 'Made Unrecognizable & Unusable',
        undefined: 'Made Unrecognizable & Unusable'
      }.freeze

      MO_WASTE_METHOD_MAP = {
        compost: 'Compost',
        self_hauler: 'Made Unusable & Recognizable',
        waste_hauler: 'Made Unusable & Recognizable',
        undefined: 'Made Unusable & Recognizable'
      }.freeze

      CA_WASTE_METHOD_MAP = {
        compost: 'Compost',
        self_hauler: 'Self-Hauler',
        waste_hauler: 'Waste-Hauler',
        undefined: 'Waste-Hauler'
      }.freeze

      STATE_WASTE_METHOD_MAP = {
        ma: MA_WASTE_METHOD_MAP,
        mo: MO_WASTE_METHOD_MAP,
        ca: CA_WASTE_METHOD_MAP
      }.freeze

      def call
        if barcodes?
          call_metrc(:destroy_plants, build_mature_payload)
        else
          call_metrc(:destroy_plant_batches, build_immature_payload)
        end

        success!
      end

      private

      def transaction
        @transaction ||= get_transaction(:discard_batch)
      end

      def build_immature_payload
        [{
          PlantBatch: batch_tag,
          Count: discard_quantity,
          ReasonNote: note,
          ActualDate: discard_completion.start_time
        }]
      end

      def build_mature_payload
        weight_per_plant = calculate_average_weight(discarded_barcodes)

        discarded_barcodes.map do |barcode|
          {
            Id: nil,
            Label: barcode,
            WasteMethodName: waste_method_name,
            WasteMaterialMixed: 'None', # TODO: retrieve from the options hash once implemented in portal
            WasteWeight: weight_per_plant,
            WasteUnitOfMeasureName: unit_of_weight,
            WasteReasonName: waste_reason_name,
            ReasonNote: note,
            ActualDate: discard_completion.start_time
          }
        end
      end

      def barcodes?
        @attributes.dig('options', 'barcode').present?
      end

      def discard_completion
        get_completion(@completion_id)
      end
      memoize :discard_completion

      def discarded_barcodes
        @attributes.dig('options', 'barcode')
      end

      # 'process' or 'generate' completions that are children of the discard completion.
      def related_resource_completions
        resource_completions_by_parent_id(discard_completion.id)
      end
      memoize :related_resource_completions

      # related_resource_completions that have waste in their name.
      def waste_completions
        related_resource_completions.select do |completion|
          resource_unit = get_resource_unit(completion.options&.dig('resource_unit_id'))
          resource_unit&.name.downcase.include?('waste')
        end
      end
      memoize :waste_completions

      def note # rubocop:disable Metrics/PerceivedComplexity
        options = discard_completion.options
        return NOT_SPECIFIED unless options

        note_content = options['note_content']
        reason_description = options['reason_description']

        reason_str_end = if reason_description && note_content
                           "#{reason_description} #{note_content}"
                         elsif reason_description && !note_content
                           reason_description
                         elsif !reason_description && note_content
                           note_content
                         end

        reason_note = waste_reason_name
        reason_note += ": #{reason_str_end}." if waste_reason_name && reason_str_end

        reason_note || NOT_SPECIFIED
      end

      def discard_quantity
        @attributes.dig('options', 'calculated_quantity')&.to_i ||
          @attributes.dig('options', 'quantity')&.to_i ||
          discard_completion.options&.dig('quantity')
      end

      def unit_of_weight
        return '' if waste_completions.blank?

        get_resource_unit(waste_completions.first.options&.dig('resource_unit_id')).unit
      end

      def total_weight
        waste_completions.sum do |completion|
          completion.options&.dig('generated_quantity') || completion.options&.dig('processed_quantity')
        end
      end

      def calculate_average_weight(barcodes)
        (total_weight.to_f / barcodes.size).round(2)
      end

      # map the options' method to a defined metrc value per state.
      def waste_method_name
        method = @attributes.dig('options', 'method')&.downcase || 'undefined'
        STATE_WASTE_METHOD_MAP[@integration.state.to_sym][method.to_sym]
      end

      # map the options' reason_type to a defined metrc value per state.
      def waste_reason_name
        reason_type = @attributes.dig('options', 'reason_type')&.downcase || 'undefined'
        STATE_WASTE_REASON_MAP[@integration.state.to_sym][reason_type.to_sym]
      end
    end
  end
end
