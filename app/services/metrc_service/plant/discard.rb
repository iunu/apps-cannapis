module MetrcService
  module Plant
    class Discard < MetrcService::Base
      NOT_SPECIFIED = 'Not Specified'.freeze

      # TODO: use `GET plants/v1/waste/reasons` to fetch appropriate reason names per facilitiy rather then hard code them here.
      MA_WASTE_REASON_NAME_MAP = {
        'pruning' => 'Trimming',
        'failure to thrive' => 'Waste',
        'mandated destruction' => 'Waste',
        'male plants' => 'Waste',
        'contamination' => 'Spoilage',
        'damage' => 'Spoilage',
        'pesticides' => 'Spoilage',
        'other' => 'Waste',
        'not specified' => 'Waste'
      }.freeze

      MO_WASTE_REASON_NAME_MAP = {
        'pruning' => 'Trimming/Prunning',
        'failure to thrive' => 'Damaged',
        'mandated destruction' => 'Mandated State Destruction',
        'male plants' => 'Contamination',
        'contamination' => 'Contamination',
        'damage' => 'Damaged',
        'pesticides' => 'Contamination',
        'other' => 'Spoilage',
        'not specified' => 'Spoilage'
      }.freeze

      CA_WASTE_REASON_NAME_MAP = {
        'pruning' => 'Pruning',
        'failure to thrive' => 'Failure to Thrive',
        'mandated destruction' => 'Mandated Destruction',
        'male plants' => 'Male Plants',
        'contamination' => 'Contamination',
        'damage' => 'Damage',
        'pesticides' => 'Pesticides',
        'other' => 'Damage',
        'not specified' => 'Damage'
      }.freeze

      STATE_WASTE_REASON_NAME_MAP = {
        ma: MA_WASTE_REASON_NAME_MAP,
        mo: MO_WASTE_REASON_NAME_MAP,
        ca: CA_WASTE_REASON_NAME_MAP
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
            WasteMethodName: 'Compost', # TODO: retrieve from the options hash once implemented in portal
            WasteMaterialMixed: 'Soil', # TODO: retrieve from the options hash once implemented in portal
            WasteWeight: weight_per_plant,
            WasteUnitOfMeasureName: unit_of_weight,
            WasteReasonName: reason_name,
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
        reason_type = options['reason_type']&.capitalize

        reason_str_end = if reason_description && note_content
                           "#{reason_description} #{note_content}"
                         elsif reason_description && !note_content
                           reason_description
                         elsif !reason_description && note_content
                           note_content
                         end

        reason_note = reason_type
        reason_note += ": #{reason_str_end}." if reason_type && reason_str_end

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

      # map the options reason_type to a defined metrc value per state.
      def reason_name
        reason_type = @attributes.dig('options', 'reason_type')&.downcase || 'not specified'
        STATE_WASTE_REASON_NAME_MAP[@integration.state.to_sym][reason_type]
      end
    end
  end
end
