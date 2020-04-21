module MetrcService
  module Plant
    class Start < Base
      def call
        payload = build_start_payload(batch)

        call_vendor(:create_plant_batches, payload)

        success!
      end

      private

      def transaction
        @transaction ||= get_transaction(:start_batch)
      end

      def build_start_payload(batch)
        batch_quantity = batch.attributes['quantity']&.to_i
        quantity = batch_quantity.positive? ? batch_quantity : @attributes.dig('options', 'quantity')&.to_i
        seeding_unit = batch.zone.attributes.dig('seeding_unit', 'name').downcase
        type = /seed/.match?(seeding_unit) ? 'Seed' : 'Clone'

        [{
          Name: batch_tag,
          Type: type,
          Count: quantity,
          Strain: batch.attributes['crop_variety'],
          Location: batch.zone.name,
          PatientLicenseNumber: nil,
          ActualDate: batch.attributes['seeded_at']
        }]
      end
    end
  end
end
