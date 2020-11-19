module MetrcService
  module Plant
    class Discard < MetrcService::Base
      NOT_SPECIFIED = 'Not Specified'.freeze

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

      def discard
        get_completion(@completion_id)
      end
      memoize :discard

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
        reason = reason_note

        @attributes.dig('options', 'barcode').map do |barcode|
          {
            Id: nil,
            Label: barcode,
            ReasonNote: reason,
            ActualDate: discard.start_time
          }
        end
      end

      def reason_note # rubocop:disable Metrics/PerceivedComplexity
        reason_description = if discard['reason_description'] && discard['note_content']
                               "#{discard['reason_description']} #{discard['note_content']}"
                             elsif discard['reason_description'] && !discard['note_content']
                               discard['reason_description']
                             elsif !discard['reason_description'] && discard['note_content']
                               discard['note_content']
                             end
        reason_type = discard['reason_type']
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
