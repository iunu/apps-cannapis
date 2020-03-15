module MetrcService
  module Plant
    class Start < MetrcService::Base
      def call
        payload = build_start_payload(batch)

        call_metrc(:create_plant_batches, payload)

        success!
      end

      private

      def transaction
        @transaction ||= get_transaction(:start_batch)
      end

      def build_start_payload(batch)
        barcode = batch.relationships.dig('barcodes', 'data', 0, 'id')
        tracking_code = @attributes.dig('options', 'tracking_barcode')
        batch_quantity = batch.attributes['quantity']&.to_i
        quantity = batch_quantity.positive? ? batch_quantity : @attributes.dig('options', 'quantity')&.to_i
        type = %w[clone seed].include?(batch.zone.attributes.dig('seeding_unit', 'name').downcase) ? batch.zone.attributes.dig('seeding_unit', 'name') : 'Clone'

        [{
          Name: tracking_code || barcode,
          Type: type,
          Count: quantity,
          Strain: batch.attributes['crop_variety'],
          Location: @attributes.dig('options', 'zone_name') || 'Mothers',
          PatientLicenseNumber: nil,
          ActualDate: batch.attributes['seeded_at']
        }]
      end
    end
  end
end
