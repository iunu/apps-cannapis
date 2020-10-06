module MetrcService
  module Plant
    class Discard < MetrcService::Base
      NOT_SPECIFIED = 'Not Specified'.freeze

      def call
        if plant_state == :immature
          call_metrc(:destroy_plant_batches, build_immature_payload)
        else
          call_metrc(:destroy_plants, build_mature_payload)
        end

        success!
      end

      private

      def plant_state
        @plant_state ||= [nil, 'none'].include?(item_tracking_method) ? :immature : :mature
      end

      def transaction
        @transaction ||= get_transaction(:discard_batch)
      end

      def discard
        return @discard if @discard

        id = @relationships.dig('action_result', 'data', 'id')&.to_i || @completion_id
        @discard = get_completion(id)
      end

      def build_immature_payload
        reason = reason_note

        [{
          PlantBatch: batch_tag,
          Count: quantity,
          ReasonNote: reason,
          ActualDate: discard.start_time
        }]
      end

      def build_mature_payload
        discard_type = @attributes.dig('options', 'discard_type')
        reason       = reason_note

        if discard_type == 'partial'
          return @attributes.dig('options', 'barcode').map do |barcode|
            {
              Id: nil,
              Label: barcode,
              ReasonNote: reason,
              ActualDate: discard.start_time
            }
          end
        end

        items = get_items(batch.seeding_unit.id)
        items.map do |item|
          {
            Id: nil,
            Label: item.relationships.dig('barcode', 'data', 'id'),
            ReasonNote: reason,
            ActualDate: discard.start_time
          }
        end
      end

      def reason_note # rubocop:disable Metrics/PerceivedComplexity
        reason_description = if discard.options.dig('reason_description') && discard.options.dig('note_content')
                               "#{discard.options.dig('reason_description')} #{discard.options.dig('note_content')}"
                             elsif discard.options.dig('reason_description') && !discard.options.dig('note_content')
                               discard.options.dig('reason_description')
                             elsif !discard.options.dig('reason_description') && discard.options.dig('note_content')
                               discard.options.dig('note_content')
                             end
        reason_type = discard.options.dig('reason_type')
        reason_note = reason_type.capitalize if reason_type
        reason_note += ": #{reason_description}." if reason_type && reason_description

        reason_note || NOT_SPECIFIED
      end

      def quantity
        @attributes.dig('options', 'calculated_quantity')&.to_i || \
          @attributes.dig('options', 'quantity')&.to_i || \
          discard.options.fetch('quantity')
      end
    end
  end
end
