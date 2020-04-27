module MetrcService
  module Plant
    class Start < Base
      def call
        payload = build_start_payload(batch)

        call_metrc(:create_plant_batches, payload)

        # If batch has custom field package_id
        # then create_plantings_from_package
        # if not create_plant_batches

        success!
      end

      private

      def transaction
        @transaction ||= get_transaction(:start_batch)
      end

      def build_start_payload(batch)
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

      def create_plantings_from_package
        call_metrc(:create_plantings_package, create_package_plantings_payload)
      end

      def create_plantings_from_package_payload
        seeding_unit = batch.zone.attributes.dig('seeding_unit', 'name').downcase
        type = /seed/.match?(seeding_unit) ? 'Seed' : 'Clone'

        [{
          PackageLabel: tag, # from custom field
          PackageAdjustmentAmount: nil,
          PackageAdjustmentUnitOfMeasureName: unit_of_weight,
          PlantBatchName: batch_tag,
          PlantBatchType: 'Clone',
          PlantCount: quantity,
          LocationName: batch.zone.name,
          RoomName: batch.zone.name,
          StrainName: batch.crop_variety,
          PatientLicenseNumber: nil,
          PlantedDate: batch.seeded_at,
          UnpackagedDate: batch.seeded_at
        }]
      end

      def quantity
        batch_quantity = batch.attributes['quantity']&.to_i
        batch_quantity.positive? ? batch_quantity : @attributes.dig('options', 'quantity')&.to_i
      end
    end
  end
end
