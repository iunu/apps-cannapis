module MetrcService
  module Plant
    class Start < Base
      attr_reader :transaction_type

      ORIGIN_PACKAGES = [
        'Source Package Id (Metrc)'
      ].freeze

      def call
        @transaction_type = :start_batch
        @packaged_origin = nil

        if batch.methods.include?(:included)
          @packaged_origin = batch.included&.dig(:custom_fields)&.detect { |obj| ORIGIN_PACKAGES.includes?(obj&.name) }
        end

        if @packaged_origin
          @transaction_type = :start_batch_from_package
          create_plantings_from_package
        else
          create_plant_batch
        end

        success!
      end

      private

      def transaction
        @transaction ||= get_transaction(@transaction_type || :start_batch)
      end

      def create_plant_batch
        call_metrc(:create_plant_batches, build_start_payload)
      end

      def build_start_payload
        seeding_unit = batch.zone.attributes.dig('seeding_unit', 'name').downcase
        type = /seed/.match?(seeding_unit) ? 'Seed' : 'Clone'

        [{
          Name: batch_tag,
          Type: type,
          Count: quantity,
          Strain: batch.crop_variety,
          Location: batch.zone&.name&.gsub(/\s*\[.*?\]/, '')&.strip,
          PatientLicenseNumber: nil,
          ActualDate: batch.seeded_at
        }]
      end

      def create_plantings_from_package
        call_metrc(:create_plantings_package, create_package_plantings_payload)
      end

      def create_plantings_from_package_payload
        label = batch.included&.dig(:custom_data)&.detect { |obj| obj&.custom_field_id.to_i == @packaged_origin.id.to_i }

        raise InvalidOperation, "Failed: No package label was found for #{@packaged_origin&.name}" unless label && label&.value

        [{
          PackageLabel: label.value,
          PackageAdjustmentAmount: 0,
          PackageAdjustmentUnitOfMeasureName: 'Ounces',
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
        @attributes.dig('options', 'quantity')&.to_i
      end
    end
  end
end
